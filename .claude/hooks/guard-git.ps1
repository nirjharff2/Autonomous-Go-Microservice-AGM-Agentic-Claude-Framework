# PreToolUse hook (Bash): block git operations that CLAUDE.md reserves for the owner or that
# destroy uncommitted work: commit, push, reset --hard, clean, rebase, stash drop/clear,
# branch -D, and force checkout/restore of the whole tree.
# "git" must be the first token of a command segment (start of line, or after ; & | &&),
# optionally followed by global flags such as -C <dir> or --no-pager, so prose inside heredocs
# that merely mentions committing is not blocked.
$raw = [Console]::In.ReadToEnd()
if (-not $raw) { exit 0 }
try { $payload = $raw | ConvertFrom-Json } catch { exit 0 }
$cmd = [string]$payload.tool_input.command
if (-not $cmd) { exit 0 }

$gitPrefix = '(^|[;&|]\s*)git(\s+-[^\s]+(\s+[^\s-][^\s]*)?)*\s+'
$blocked = @(
    'commit\b',
    'push\b',
    'reset\s+--hard\b',
    'clean\s+-[a-zA-Z]*[fd]',
    'rebase\b',
    'stash\s+(drop|clear)\b',
    'branch\s+(-D|--delete\s+--force)\b',
    'checkout\s+(--\s+\.|\.)(\s|$)',
    'restore\s+(--\s+\.|\.)(\s|$)'
)
foreach ($b in $blocked) {
    if ($cmd -match ($gitPrefix + $b)) {
        [Console]::Error.WriteLine("Blocked by .claude/hooks/guard-git.ps1: '$($Matches[0].Trim())' is reserved for the owner (CLAUDE.md: never commit/push; never discard uncommitted work). Leave the working tree for review instead.")
        exit 2
    }
}
exit 0
