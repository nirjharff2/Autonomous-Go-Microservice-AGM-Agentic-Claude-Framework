---
name: review
description: Run the reviewer agents (go-reviewer, security-auditor, spec-checker) on the current changes in parallel, consolidate their findings, fix them, and re-verify. Usage: /review [phase number | package paths].
---

Review the current working tree with the project's reviewer agents and fix what they find.

1. Scope. Use **$ARGUMENTS** if given (a PLAN.md phase number, or package paths). Otherwise take
   the packages that changed according to `git status --short`.
2. Launch the agents **in parallel** (one message, several Agent tool calls):
   - `go-reviewer` on the scoped packages (always).
   - `security-auditor` when the scope touches internal/auth, internal/middleware,
     internal/handler, internal/service, internal/repository or cmd/.
   - `spec-checker` for the phase(s) in scope (always when a phase number was given).
3. Merge the findings into one list, de-duplicate, order by severity (High, Medium, Low, style).
4. Fix every High and Medium finding and every CLAUDE.md violation. Fix Low findings when the fix
   is local and obvious; otherwise record them under the phase's Notes in PLAN.md as deferred.
5. Run the /verify skill until `VERIFY OK`.
6. Report: findings per severity, what was fixed (file:line), what was deferred and why.

Do not commit. Do not silence findings with `//nolint` unless the line carries a reason comment.
