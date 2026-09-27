# SessionStart hook: whatever this prints is added to the agent's context at the start of every
# session (startup, resume, clear, compact). Keep it short: plan progress + environment facts.
$root = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
Set-Location $root

Write-Output '## Session bootstrap (from .claude/hooks/session-start.ps1)'
& powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $root 'scripts\plan-status.ps1') 2>&1
Write-Output ''
Write-Output 'Environment: Windows, PowerShell 5.1, GNU make NOT installed. Use'
Write-Output '  powershell -NoProfile -ExecutionPolicy Bypass -File scripts/make.ps1 <target>   (verify | test | lint | build | run | smoke | status)'
Write-Output 'Workflow: /status -> /phase (next unfinished phase) -> /verify -> /review. Never commit; the owner commits. See GUIDE.md.'
exit 0
