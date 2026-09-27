---
name: phase
description: Implement one phase of PLAN.md end to end (code, tests, verify, review, checklist update). Usage: /phase <number> or /phase (next unfinished phase).
---

Implement phase **$ARGUMENTS** of PLAN.md. If no number was given (or the argument is `next`),
run `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/make.ps1 status` and take the
phase it reports as **Next**.

0. Preflight. Run `scripts/make.ps1 status`. Every earlier phase must be fully ticked; if one is
   not, stop and report which boxes are open instead of skipping ahead. Read the phase's Notes.
1. Read the phase section of PLAN.md and the matching parts of the spec file (named by PLAN.md's
   Project block, `spec_file`, default SPEC.md). List the files the phase asks for before writing
   anything.
2. Write the code and its tests. Follow CLAUDE.md strictly (layering, error wrapping, respond
   helper, no magic strings, context first). Every new package gets a `_test.go` in the same
   package. Stay inside the phase's scope: if a later phase's type is needed to compile, add the
   smallest possible interface or stub and note it under the phase's Notes.
3. Run the phase's own Verify commands from PLAN.md, then the /verify skill. Fix until green.
4. Run the /review skill for this phase (it launches go-reviewer, security-auditor when relevant,
   and spec-checker, then fixes the findings and re-verifies).
5. Tick the phase's checkboxes in PLAN.md. Add a one-line Notes entry under the phase for
   anything that diverged from the plan and why. Append one line to the **Progress log** at the
   bottom of PLAN.md: `- YYYY-MM-DD Phase N: done|partial — <one sentence>`.
6. Report: files created, test results, reviewer findings fixed, anything left open.

If you are blocked on a decision only the owner can make, write the question under the phase's
Notes, finish everything that does not depend on it, and say so in the report.
Never commit; the owner commits after reviewing the diff.
