<#
.SYNOPSIS
    Windows mirror of the Makefile (GNU make is not installed on the owner's machine).

.USAGE
    powershell -NoProfile -ExecutionPolicy Bypass -File scripts/make.ps1 <target>

    Targets mirror the Makefile one-to-one. Run with no target (or "help") to list them.
    Dev tools (golangci-lint, mockery, swag) are NOT installed globally; they are pinned as
    `tool` directives in tools/go.mod and run through `go tool -modfile=tools/go.mod <name>`.

    Service identity and stack choices come from PLAN.md's `## Project` block (see GUIDE.md
    section 0), not from this script. Edit PLAN.md, then run `scripts/make.ps1 init` once.
#>
[CmdletBinding()]
param(
    [Parameter(Position = 0)] [string] $Target = 'help',
    [Parameter(Position = 1, ValueFromRemainingArguments = $true)] [string[]] $Rest = @()
)

$ErrorActionPreference = 'Continue'
$Root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
Set-Location $Root
. (Join-Path $PSScriptRoot 'lib\PlanConfig.ps1')

# ---------------------------------------------------------------------------------------------
# Shared settings, resolved from PLAN.md's `## Project` block (keep logic in sync with Makefile)
# ---------------------------------------------------------------------------------------------
$Cfg       = Get-PlanConfig
$AppName   = $Cfg['service_name']
$Module    = $Cfg['module_path']
$MainPkg   = $Cfg['main_pkg']
$AuthMode  = $Cfg['auth']
$HttpPort  = $Cfg['http_port']
$ToolMod   = 'tools/go.mod'
$BinDir    = 'bin'
$Version   = (& git describe --tags --always --dirty 2>$null); if (-not $Version) { $Version = 'dev' }
$Commit    = (& git rev-parse --short HEAD 2>$null);          if (-not $Commit)  { $Commit  = 'none' }
$BuildTime = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
$LdFlags   = "-s -w -X main.version=$Version -X main.commit=$Commit -X main.buildTime=$BuildTime"
$GoDirs    = @(@('cmd', 'internal') | Where-Object { Test-Path $_ })

# ---------------------------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------------------------
function Write-Step([string] $Text) { Write-Host "==> $Text" -ForegroundColor Cyan }

function Invoke-Step([string] $Name, [scriptblock] $Body) {
    Write-Step $Name
    $global:LASTEXITCODE = 0
    & $Body
    if ($LASTEXITCODE -ne 0) {
        Write-Host "FAILED: $Name (exit $LASTEXITCODE)" -ForegroundColor Red
        exit $LASTEXITCODE
    }
}

function Test-HasGoFiles {
    if ($GoDirs.Count -eq 0) { return $false }
    $files = Get-ChildItem -Path $GoDirs -Recurse -Filter '*.go' -ErrorAction SilentlyContinue
    return (@($files).Count -gt 0)
}

function Import-DotEnv {
    # Loads KEY=VALUE pairs from .env into the current process (values are never printed).
    # Variables that are already set win, so ad-hoc overrides on the command line still work.
    if (-not (Test-Path '.env')) { return }
    Get-Content '.env' | ForEach-Object {
        $line = $_.Trim()
        if ($line -eq '' -or $line.StartsWith('#')) { return }
        $idx = $line.IndexOf('=')
        if ($idx -lt 1) { return }
        $key = $line.Substring(0, $idx).Trim()
        $val = $line.Substring($idx + 1).Trim().Trim('"')
        if (-not (Test-Path "Env:$key")) { Set-Item -Path "Env:$key" -Value $val }
    }
}

function Invoke-GoTool([string] $Name, [string[]] $ToolArgs) {
    & go tool "-modfile=$ToolMod" $Name @ToolArgs
}

# ---------------------------------------------------------------------------------------------
# Targets
# ---------------------------------------------------------------------------------------------
$Targets = [ordered]@{
    'help'             = 'List targets'
    'init'             = "Apply PLAN.md's Project block to go.mod, tools/go.mod and .golangci.yml (one-time)"
    'tools'            = 'Build/warm the pinned dev tools (golangci-lint, mockery, swag) once'
    'tidy'             = 'go mod tidy for the main module and tools/'
    'fmt'              = 'gofmt -w every Go file'
    'fmt-check'        = 'Fail if any Go file is not gofmt-clean'
    'vet'              = 'go vet ./...'
    'lint'             = 'golangci-lint run ./... (via tools/go.mod)'
    'test'             = 'Unit tests: go test ./... -count=1 -race -cover'
    'test-integration' = 'Integration tests (needs Docker): go test -tags integration ./...'
    'build'            = "Build $BinDir/$AppName.exe with version ldflags"
    'verify'           = 'fmt-check + vet + lint + test + build, stop at first failure'
    'run'              = "go run $MainPkg (loads .env if present)"
    'mocks'            = 'Regenerate mockery mocks from .mockery.yaml'
    'generate'         = 'go generate ./...'
    'swagger'          = 'Regenerate docs/ OpenAPI spec with swag'
    'migrate-up'       = 'Apply migrations with cmd/migrate'
    'migrate-down'     = 'Roll back one migration with cmd/migrate'
    'docker-build'     = "docker build -t ${AppName}:$Version ."
    'up'               = 'docker compose up -d --build'
    'down'             = 'docker compose down'
    'logs'             = "docker compose logs -f $AppName"
    'smoke'            = 'End-to-end smoke test against a locally running stack (scripts/smoke.ps1)'
    'status'           = 'Show PLAN.md progress (scripts/plan-status.ps1)'
    'clean'            = "Remove $BinDir/"
}

function Target-Help {
    Write-Host "Usage: powershell -NoProfile -ExecutionPolicy Bypass -File scripts/make.ps1 <target>`n"
    foreach ($k in $Targets.Keys) { Write-Host ("  {0,-17} {1}" -f $k, $Targets[$k]) }
}

function Target-Init {
    Invoke-Step "go mod edit -module $Module" { & go mod edit -module $Module }
    Invoke-Step "tools/go.mod edit -module $Module/tools" {
        Push-Location tools
        & go mod edit -module "$Module/tools"
        $code = $LASTEXITCODE
        Pop-Location
        $global:LASTEXITCODE = $code
    }
    if (Test-Path '.golangci.yml') {
        Write-Step 'patching .golangci.yml local-prefixes'
        $lines = Get-Content '.golangci.yml'
        $out = New-Object System.Collections.Generic.List[string]
        $expectValue = $false
        foreach ($line in $lines) {
            if ($expectValue -and ($line -match '^\s*-\s')) {
                $indent = ($line -replace '^(\s*)-.*', '$1')
                $out.Add("$indent- $Module")
                $expectValue = $false
                continue
            }
            $expectValue = $false
            $out.Add($line)
            if ($line -match 'local-prefixes:') { $expectValue = $true }
        }
        Set-Content -Path '.golangci.yml' -Value $out
    }
    Write-Host "module set to $Module; service name $AppName; main package $MainPkg" -ForegroundColor Green
    Write-Host "run 'scripts/make.ps1 tidy' if this changed which dependencies are actually used"
}

function Target-Tools {
    Invoke-Step 'golangci-lint version' { Invoke-GoTool 'golangci-lint' @('version') }
    Invoke-Step 'mockery version'       { Invoke-GoTool 'mockery' @('--version') }
    Invoke-Step 'swag version'          { Invoke-GoTool 'swag' @('--version') }
}

function Target-Tidy {
    Invoke-Step 'go mod tidy (main)'  { & go mod tidy }
    Invoke-Step 'go mod tidy (tools)' {
        Push-Location tools
        & go mod tidy
        $code = $LASTEXITCODE
        Pop-Location
        $global:LASTEXITCODE = $code
    }
}

function Target-Fmt {
    if (-not (Test-HasGoFiles)) { Write-Step 'fmt: no Go files yet, skipping'; return }
    Invoke-Step 'gofmt -w' { & gofmt -l -w @GoDirs }
}

function Target-FmtCheck {
    if (-not (Test-HasGoFiles)) { Write-Step 'fmt-check: no Go files yet, skipping'; return }
    Write-Step 'gofmt -l'
    $dirty = & gofmt -l @GoDirs
    if ($dirty) {
        Write-Host 'FAILED: these files are not gofmt-clean (run scripts/make.ps1 fmt):' -ForegroundColor Red
        $dirty | ForEach-Object { Write-Host "  $_" }
        exit 1
    }
}

function Target-Vet {
    if (-not (Test-HasGoFiles)) { Write-Step 'vet: no Go files yet, skipping'; return }
    Invoke-Step 'go vet ./...' { & go vet ./... }
}

function Target-Lint {
    if (-not (Test-HasGoFiles)) { Write-Step 'lint: no Go files yet, skipping'; return }
    Invoke-Step 'golangci-lint run ./...' { Invoke-GoTool 'golangci-lint' @('run', './...') }
}

function Target-Test {
    if (-not (Test-HasGoFiles)) { Write-Step 'test: no Go files yet, skipping'; return }
    Invoke-Step 'go test ./... -count=1 -race -cover' { & go test ./... -count=1 -race -cover @Rest }
}

function Target-TestIntegration {
    if (-not (Test-HasGoFiles)) { Write-Step 'test-integration: no Go files yet, skipping'; return }
    Invoke-Step 'go test -tags integration ./... -count=1 -race' { & go test -tags integration ./... -count=1 -race @Rest }
}

function Target-Build {
    if (-not (Test-Path $MainPkg)) {
        Write-Step "build: $MainPkg does not exist yet, running go build ./... instead"
        Invoke-Step 'go build ./...' { & go build ./... }
        return
    }
    New-Item -ItemType Directory -Force -Path $BinDir | Out-Null
    Invoke-Step "go build -o $BinDir/$AppName.exe" { & go build -ldflags $LdFlags -o "$BinDir/$AppName.exe" $MainPkg }
}

function Target-Verify {
    Target-FmtCheck
    Target-Vet
    Target-Lint
    Target-Test
    Target-Build
    Write-Host "`nVERIFY OK (fmt-check, vet, lint, test -race, build)" -ForegroundColor Green
}

function Target-Run {
    Import-DotEnv
    if ($AuthMode -eq 'jwt' -and -not $env:JWT_SECRET) {
        $env:JWT_SECRET = 'dev-secret-change-me'
        Write-Step 'JWT_SECRET not set; using the dev placeholder'
    }
    if (-not $env:HTTP_PORT) { $env:HTTP_PORT = $HttpPort }
    Invoke-Step "go run $MainPkg" { & go run -ldflags $LdFlags $MainPkg @Rest }
}

function Target-Mocks    { Invoke-Step 'mockery' { Invoke-GoTool 'mockery' @() } }
function Target-Generate { Invoke-Step 'go generate ./...' { & go generate ./... } }

function Target-Swagger {
    Invoke-Step 'swag init' {
        Invoke-GoTool 'swag' @('init', '-g', "$MainPkg/main.go", '-o', 'docs', '--parseDependency', '--parseInternal')
    }
}

function Target-MigrateUp   { Import-DotEnv; Invoke-Step 'migrate up'   { & go run ./cmd/migrate up } }
function Target-MigrateDown { Import-DotEnv; Invoke-Step 'migrate down' { & go run ./cmd/migrate down } }

function Target-DockerBuild {
    Invoke-Step "docker build ${AppName}:$Version" {
        & docker build -t "${AppName}:$Version" -t "${AppName}:latest" `
            --build-arg "VERSION=$Version" --build-arg "COMMIT=$Commit" --build-arg "BUILD_TIME=$BuildTime" .
    }
}

function Target-Up   { Invoke-Step 'docker compose up -d --build' { & docker compose up -d --build } }
function Target-Down { Invoke-Step 'docker compose down'          { & docker compose down } }
function Target-Logs { & docker compose logs -f $AppName }

function Target-Smoke {
    & powershell -NoProfile -ExecutionPolicy Bypass -File scripts/smoke.ps1 @Rest
    exit $LASTEXITCODE
}

function Target-Status {
    & powershell -NoProfile -ExecutionPolicy Bypass -File scripts/plan-status.ps1 @Rest
    exit $LASTEXITCODE
}

function Target-Clean {
    if (Test-Path $BinDir) { Remove-Item -Recurse -Force $BinDir }
    Write-Step "removed $BinDir/"
}

switch ($Target) {
    'help'             { Target-Help }
    'init'             { Target-Init }
    'tools'            { Target-Tools }
    'tidy'             { Target-Tidy }
    'fmt'              { Target-Fmt }
    'fmt-check'        { Target-FmtCheck }
    'vet'              { Target-Vet }
    'lint'             { Target-Lint }
    'test'             { Target-Test }
    'test-integration' { Target-TestIntegration }
    'build'            { Target-Build }
    'verify'           { Target-Verify }
    'run'              { Target-Run }
    'mocks'            { Target-Mocks }
    'generate'         { Target-Generate }
    'swagger'          { Target-Swagger }
    'migrate-up'       { Target-MigrateUp }
    'migrate-down'     { Target-MigrateDown }
    'docker-build'     { Target-DockerBuild }
    'up'               { Target-Up }
    'down'             { Target-Down }
    'logs'             { Target-Logs }
    'smoke'            { Target-Smoke }
    'status'           { Target-Status }
    'clean'            { Target-Clean }
    default {
        Write-Host "Unknown target '$Target'" -ForegroundColor Red
        Target-Help
        exit 2
    }
}
