---
name: verify
description: Run the full verification pipeline (fmt-check, vet, lint, unit tests with -race, build) and fix until it is clean.
---

Run the verification pipeline. GNU make is not installed on the owner's Windows machine, so use
the PowerShell wrapper that mirrors the Makefile (on a machine with make, `make verify` is identical):

```
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/make.ps1 verify
```

verify = fmt-check → vet → lint (golangci-lint via tools/go.mod) → test (-race -cover) → build,
stopping at the first failure and ending with `VERIFY OK` when everything passes.

Rules while fixing:
- Show the exact error, explain the cause in one sentence, fix it, and re-run the whole pipeline
  from the start. Repeat until `VERIFY OK`.
- Never make it green by deleting a test, weakening an assertion, skipping a package, or adding
  `//nolint` without a `// reason` comment.
- Never change tool versions in tools/go.mod or relax .golangci.yml to silence a finding.
- If a fix needs a new third-party dependency, stop and ask (CLAUDE.md).

Integration tests need Docker Desktop running:
```
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/make.ps1 test-integration
```
If Docker is unavailable the packages skip themselves; say so explicitly in the report.

Report in a few lines: the final `VERIFY OK` / `FAILED` line, whether `-race` was clean, whether
integration tests ran or were skipped, and anything you changed to get there.
