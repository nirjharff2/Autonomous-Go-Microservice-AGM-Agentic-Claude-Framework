# PostToolUse hook (Write|Edit): gofmt any Go file that was just written or edited.
# Reads the hook payload from stdin, extracts tool_input.file_path, and runs gofmt -w on it.
# Exit 2 + stderr feeds the problem back to the agent; anything else is silent.
$raw = [Console]::In.ReadToEnd()
if (-not $raw) { exit 0 }
try { $payload = $raw | ConvertFrom-Json } catch { exit 0 }
$path = $payload.tool_input.file_path
if (-not $path) { exit 0 }
if ($path -notmatch '\.go$') { exit 0 }
if (-not (Test-Path $path)) { exit 0 }
$out = & gofmt -l -w $path 2>&1
if ($LASTEXITCODE -ne 0) {
    [Console]::Error.WriteLine("gofmt failed for ${path}: $out")
    exit 2
}
exit 0
