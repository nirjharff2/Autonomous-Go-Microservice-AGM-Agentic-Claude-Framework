<#
.SYNOPSIS
    Prints the progress of PLAN.md: the resolved Project block, one line per phase with
    done/total checkboxes, the next phase to work on, and the number of uncommitted files. Used
    by the SessionStart hook, the /status skill and `scripts/make.ps1 status`.

.PARAMETER Json
    Emit a single JSON object instead of text (for tooling).
#>
[CmdletBinding()]
param([switch] $Json)

$ErrorActionPreference = 'Continue'
$Root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
Set-Location $Root
. (Join-Path $PSScriptRoot 'lib\PlanConfig.ps1')

$planPath = Join-Path $Root 'PLAN.md'
if (-not (Test-Path $planPath)) { Write-Host 'PLAN.md not found'; exit 1 }

$cfg = Get-PlanConfig -PlanPath $planPath

$phases = @()
$current = $null
foreach ($line in Get-Content $planPath) {
    if ($line -match '^## Phase (\d+):\s*(.+)$') {
        $current = [pscustomobject]@{ Number = [int]$Matches[1]; Title = $Matches[2].Trim(); Done = 0; Total = 0 }
        $phases += $current
        continue
    }
    if ($line -match '^## ') { $current = $null; continue }
    if ($null -eq $current) { continue }
    if ($line -match '^\s*- \[( |x|X)\]') {
        $current.Total++
        if ($Matches[1] -ne ' ') { $current.Done++ }
    }
}

$next = $phases | Where-Object { $_.Done -lt $_.Total } | Select-Object -First 1
$dirty = @(& git status --porcelain 2>$null)
$goFiles = @(Get-ChildItem -Path @(@('cmd', 'internal') | Where-Object { Test-Path $_ }) -Recurse -Filter '*.go' -ErrorAction SilentlyContinue)

if ($Json) {
    [pscustomobject]@{
        project     = $cfg
        phases      = $phases
        nextPhase   = if ($next) { $next.Number } else { $null }
        uncommitted = $dirty.Count
        goFiles     = $goFiles.Count
    } | ConvertTo-Json -Depth 4
    exit 0
}

Write-Host ("Service: {0}  ({1})" -f $cfg['service_name'], $cfg['module_path'])
Write-Host ("Stack: router={0} db_driver={1} auth={2} observability={3}" -f $cfg['router'], $cfg['db_driver'], $cfg['auth'], $cfg['observability'])
Write-Host 'PLAN.md progress'
foreach ($p in $phases) {
    $state = if ($p.Total -eq 0) { '   -  ' } elseif ($p.Done -eq $p.Total) { ' DONE ' } elseif ($p.Done -eq 0) { ' todo ' } else { ' WIP  ' }
    Write-Host ("  [{0}] Phase {1}: {2,-58} {3,2}/{4,-2}" -f $state, $p.Number, $p.Title, $p.Done, $p.Total)
}
if ($next) { Write-Host ("Next: Phase {0} ({1})" -f $next.Number, $next.Title) }
else       { Write-Host 'Next: all phases ticked; run the end-to-end verification in PLAN.md' }
Write-Host ("Go files: {0}   Uncommitted files (git status): {1}" -f $goFiles.Count, $dirty.Count)
exit 0
