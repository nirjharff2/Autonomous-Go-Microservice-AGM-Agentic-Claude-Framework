<#
.SYNOPSIS
    Generic end-to-end smoke test. Builds and runs the service (starting docker compose first if
    a docker-compose.yml exists), waits for the configured health endpoint, then tears down.

.USAGE
    powershell -NoProfile -ExecutionPolicy Bypass -File scripts/smoke.ps1 [-Port 8080] [-KeepStack] [-NoDocker]

    -KeepStack   leave docker compose running afterwards
    -NoDocker    skip `docker compose up`; assume any backing services are already reachable

    Exit code 0 when every step passes, 1 otherwise. A step table is printed at the end.

.NOTES
    This script only knows generic checks: build, start, hit the health path from PLAN.md's
    Project block (`health_path`, default /health/ready). Business-specific checks (register,
    login, CRUD flows, ...) belong in scripts/smoke.project.ps1 — if that file exists, it is
    dot-sourced after the health check with $Base, $Port and the Step/Invoke-Api helpers in
    scope, so it can add its own PASS/FAIL rows without touching this template file.
#>
[CmdletBinding()]
param(
    [int]    $Port,
    [switch] $KeepStack,
    [switch] $NoDocker
)

$ErrorActionPreference = 'Continue'
$Root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
Set-Location $Root
. (Join-Path $PSScriptRoot 'lib\PlanConfig.ps1')

$Cfg        = Get-PlanConfig
$AppName    = $Cfg['service_name']
$MainPkg    = $Cfg['main_pkg']
$HealthPath = $Cfg['health_path']
if (-not $Port) { $Port = [int]$Cfg['http_port'] }

Add-Type -AssemblyName System.Net.Http
$Base    = "http://localhost:$Port"
$Results = New-Object System.Collections.ArrayList
$Server  = $null
$LogFile = Join-Path $env:TEMP "$AppName-smoke.log"
$ErrFile = Join-Path $env:TEMP "$AppName-smoke.err.log"

function Step([string] $Name, [bool] $Ok, [string] $Detail = '') {
    [void]$Results.Add([pscustomobject]@{ Step = $Name; Result = $(if ($Ok) { 'PASS' } else { 'FAIL' }); Detail = $Detail })
    $color = if ($Ok) { 'Green' } else { 'Red' }
    Write-Host ("[{0}] {1} {2}" -f $(if ($Ok) { 'PASS' } else { 'FAIL' }), $Name, $Detail) -ForegroundColor $color
}

function Invoke-Api {
    param([string] $Method, [string] $Path, $Body = $null, [string] $Token = '')
    $client = New-Object System.Net.Http.HttpClient
    $client.Timeout = [TimeSpan]::FromSeconds(10)
    try {
        $req = New-Object System.Net.Http.HttpRequestMessage ([System.Net.Http.HttpMethod]::new($Method), "$Base$Path")
        if ($null -ne $Body) {
            $json = $Body | ConvertTo-Json -Depth 6 -Compress
            $req.Content = New-Object System.Net.Http.StringContent ($json, [System.Text.Encoding]::UTF8, 'application/json')
        }
        if ($Token) { $req.Headers.Authorization = New-Object System.Net.Http.Headers.AuthenticationHeaderValue ('Bearer', $Token) }
        $resp = $client.SendAsync($req).Result
        $text = $resp.Content.ReadAsStringAsync().Result
        $parsed = $null
        try { if ($text) { $parsed = $text | ConvertFrom-Json } } catch { $parsed = $null }
        $loc = ''
        if ($resp.Headers.Location) { $loc = $resp.Headers.Location.ToString() }
        return [pscustomobject]@{ Status = [int]$resp.StatusCode; Body = $parsed; Raw = $text; Location = $loc }
    } catch {
        return [pscustomobject]@{ Status = 0; Body = $null; Raw = $_.Exception.Message; Location = '' }
    } finally { $client.Dispose() }
}

function Wait-Until([string] $What, [scriptblock] $Probe, [int] $Seconds = 60) {
    $deadline = (Get-Date).AddSeconds($Seconds)
    while ((Get-Date) -lt $deadline) {
        if (& $Probe) { return $true }
        Start-Sleep -Milliseconds 500
    }
    Write-Host "timed out after ${Seconds}s waiting for $What" -ForegroundColor Red
    return $false
}

function Stop-Server {
    if ($null -ne $Server -and -not $Server.HasExited) {
        Stop-Process -Id $Server.Id -Force -ErrorAction SilentlyContinue
        $Server.WaitForExit(5000) | Out-Null
    }
}

function Finish {
    Stop-Server
    if (-not $NoDocker -and -not $KeepStack -and (Test-Path 'docker-compose.yml')) { & docker compose down 2>&1 | Out-Null }
    Write-Host "`nSmoke test summary" -ForegroundColor Cyan
    $Results | Format-Table -AutoSize | Out-String | Write-Host
    $failed = @($Results | Where-Object { $_.Result -eq 'FAIL' }).Count
    if ($failed -gt 0) {
        Write-Host "$failed step(s) failed. Server log: $LogFile / $ErrFile" -ForegroundColor Red
        if (Test-Path $ErrFile) { Get-Content $ErrFile -Tail 40 }
        exit 1
    }
    Write-Host 'SMOKE OK' -ForegroundColor Green
    exit 0
}

# ---------------------------------------------------------------------------------------------
# 0. Preconditions
# ---------------------------------------------------------------------------------------------
if (-not (Test-Path $MainPkg)) {
    Step "$MainPkg exists" $false 'the main package does not exist yet'
    Finish
}

if (-not $NoDocker -and (Test-Path 'docker-compose.yml')) {
    & docker info 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) { Step 'Docker Desktop running' $false 'docker info failed; start Docker Desktop or pass -NoDocker'; Finish }
    Step 'Docker Desktop running' $true

    & docker compose up -d 2>&1 | Out-Null
    Step 'docker compose up' ($LASTEXITCODE -eq 0)
    if ($LASTEXITCODE -ne 0) { Finish }
}

# ---------------------------------------------------------------------------------------------
# 1. Build and start the service
# ---------------------------------------------------------------------------------------------
& powershell -NoProfile -ExecutionPolicy Bypass -File scripts/make.ps1 build | Out-Null
if ($LASTEXITCODE -ne 0) { Step 'build' $false 'scripts/make.ps1 build failed'; Finish }
Step 'build' $true

$env:APP_ENV = if ($env:APP_ENV) { $env:APP_ENV } else { 'dev' }
$env:HTTP_PORT = "$Port"
if ($Cfg['auth'] -eq 'jwt' -and -not $env:JWT_SECRET) { $env:JWT_SECRET = 'dev-secret-change-me' }

$Server = Start-Process -FilePath (Join-Path $Root "bin/$AppName.exe") -PassThru -NoNewWindow `
    -RedirectStandardOutput $LogFile -RedirectStandardError $ErrFile
$up = Wait-Until "GET $HealthPath == 200" { (Invoke-Api GET $HealthPath).Status -eq 200 } 60
Step "GET $HealthPath -> 200" $up
if (-not $up) { Finish }

# ---------------------------------------------------------------------------------------------
# 2. Project-specific checks (optional extension point — see the header comment)
# ---------------------------------------------------------------------------------------------
$projectSmoke = Join-Path $Root 'scripts/smoke.project.ps1'
if (Test-Path $projectSmoke) {
    Write-Host "==> running scripts/smoke.project.ps1" -ForegroundColor Cyan
    . $projectSmoke
}

Finish
