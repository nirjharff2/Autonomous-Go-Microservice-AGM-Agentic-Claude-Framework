---
name: status
description: Show where the project stands - PLAN.md phase progress, the next phase, uncommitted changes, and whether the tree currently verifies. Read-only.
---

Report the state of the project without changing any file.

1. Run `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/make.ps1 status`
   (phase table from PLAN.md checkboxes, the next phase, Go file and uncommitted-file counts).
2. Run `git status --short` and summarise what is uncommitted in one line.
3. If any Go files exist, run `scripts/make.ps1 verify` and keep only the final line
   (`VERIFY OK` or the first failure).
4. Scan the Notes lines in PLAN.md for open questions or deferred items.

Answer in at most ten lines: the phase table, the next phase, verify state, open Notes items,
and the single recommended next command (usually `/phase`).
