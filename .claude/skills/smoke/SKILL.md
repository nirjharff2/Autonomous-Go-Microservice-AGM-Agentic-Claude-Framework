---
name: smoke
description: End-to-end smoke test - builds and runs the service, hits the configured health endpoint, runs any project-specific checks, then tears down. Starts docker compose first if a docker-compose.yml exists.
---

Run the deterministic smoke script instead of orchestrating a background server by hand:

```
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/make.ps1 smoke
```

Options (passed through to scripts/smoke.ps1): `-Port <n>` (defaults to PLAN.md's `http_port`),
`-KeepStack` (leave docker compose up), `-NoDocker` (backing services already reachable).

The script always checks: build succeeds, the service starts, and PLAN.md's `health_path`
(default `/health/ready`) returns 200. If `docker-compose.yml` exists it is brought up first. If
`scripts/smoke.project.ps1` exists it runs next with `$Base`, `$Port`, `Step` and `Invoke-Api` in
scope — that's where business-specific checks (register/login, CRUD flows, whatever this
service's endpoints are) belong; add them there instead of editing the template script. Exit code
0 means everything passed.

If a step fails: open the server log paths the script prints (stdout and stderr logs under
%TEMP%), diagnose, fix the code, run /verify, and run the smoke script again. Report the final
table. If Docker Desktop is not running and a compose file exists, say so and stop; do not fake
the result.
