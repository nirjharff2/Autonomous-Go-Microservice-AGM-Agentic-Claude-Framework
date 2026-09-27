# Stop hook: the agent may not end its turn while the Go tree is unformatted or does not compile.
# Runs only when Go files exist AND the working tree has uncommitted changes (the owner commits
# after review, so uncommitted == the agent's work in progress). If a check fails, the hook
# returns {"decision":"block","reason":...} so the agent keeps going and fixes it.
# stop_hook_active is true when the agent is already continuing because of this hook; in that
# case we let it stop, which prevents an infinite loop on a problem it cannot fix.
$raw = [Console]::In.ReadToEnd()
$payload = $null
if ($raw) { try { $payload = $raw | ConvertFrom-Json } catch { $payload = $null } }
if ($payload -and $payload.stop_hook_active) { exit 0 }

$root = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
Set-Location $root

$goDirs = @(@('cmd', 'internal') | Where-Object { Test-Path $_ })
if ($goDirs.Count -eq 0) { exit 0 }
$goFiles = @(Get-ChildItem -Path $goDirs -Recurse -Filter '*.go' -ErrorAction SilentlyContinue)
if ($goFiles.Count -eq 0) { exit 0 }
$dirty = @(& git status --porcelain 2>$null)
if ($dirty.Count -eq 0) { exit 0 }

function Block([string] $Reason) {
    $obj = @{ decision = 'block'; reason = $Reason }
    Write-Output ($obj | ConvertTo-Json -Compress)
    exit 0
}

function Trim-Output([string[]] $Lines, [int] $Max = 40) {
    $take = @($Lines | Select-Object -First $Max)
    $text = ($take -join "`n")
    if ($Lines.Count -gt $Max) { $text += "`n... ($($Lines.Count - $Max) more lines)" }
    return $text
}

$unformatted = @(& gofmt -l @goDirs 2>&1)
if ($unformatted.Count -gt 0) {
    Block ("Stop blocked by .claude/hooks/stop-check.ps1: these Go files are not gofmt-clean. Run 'powershell -NoProfile -ExecutionPolicy Bypass -File scripts/make.ps1 fmt' and finish the task:`n" + (Trim-Output $unformatted))
}

$buildOut = @(& go build ./... 2>&1)
if ($LASTEXITCODE -ne 0) {
    Block ("Stop blocked by .claude/hooks/stop-check.ps1: 'go build ./...' fails. Fix the build before finishing:`n" + (Trim-Output $buildOut))
}

$vetOut = @(& go vet ./... 2>&1)
if ($LASTEXITCODE -ne 0) {
    Block ("Stop blocked by .claude/hooks/stop-check.ps1: 'go vet ./...' reports problems. Fix them before finishing:`n" + (Trim-Output $vetOut))
}

exit 0
