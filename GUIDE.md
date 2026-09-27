# Working with the Go service autonomous development framework

This repo is a reusable template: Claude Code builds a Go service phase by phase while you only
review and commit. Starting a new service means editing **PLAN.md** — everything else (scripts,
hooks, skills, agents, Makefile) reads its configuration from PLAN.md's `## Project` block instead
of hardcoding a service name. This page explains the moving parts and the few commands you need.
It assumes Windows with Go 1.26 and Docker Desktop installed; GNU make is not required.

## 0. Starting a new service from this template

1. Copy this repo (or use it as a template repo) into a new folder for the new service.
2. Edit PLAN.md:
   - Fill in the `## Project` block (service_name, module_path, http_port, db_name, spec_file,
     and the stack choices: router, db_driver, auth, observability — see CLAUDE.md's "Tech
     Stack" section for what each supported value means).
   - Fill in `## Environment facts` and `## Key design decisions` for this machine and service.
   - Replace the placeholder `## Phase 1` (and add as many phases as needed) with the real,
     numbered phases for this service. Keep `## Phase 0` — it's the one-time bootstrap.
3. Write the spec file named by `spec_file` (default `SPEC.md`) — what "done" means. It follows
   the same placeholder shape already in the repo; fill it in, don't restructure it.
4. Run the one-time bootstrap:
   ```
   powershell -NoProfile -ExecutionPolicy Bypass -File scripts/make.ps1 init
   ```
   This applies `module_path` to `go.mod`, `tools/go.mod`, and `.golangci.yml`'s
   `local-prefixes`. Run `scripts/make.ps1 tidy` afterwards if the dependency set changed.
5. Open Claude Code in the folder and drive the loop below. Nothing past this point needs
   editing outside of PLAN.md and the code the agent writes.

Only touch CLAUDE.md, the skills, the agents, or the scripts if you want to change the *framework
itself* (see section 9) — not to point it at a new service. That's what PLAN.md is for.

## 1. The idea in one minute

| File / folder | Role |
|---|---|
| `PLAN.md` | The single source of truth: a `## Project` block (service identity + stack choices) plus the spec cut into numbered phases with checkboxes. The agent ticks boxes, writes Notes and appends a Progress log line. |
| The spec file (named by PLAN.md's `spec_file`, default `SPEC.md`) | The specification. What "done" means. Never edited by the agent. |
| `CLAUDE.md` | The rules the agent must follow (architecture, conventions, commands, workflow). Loaded every session. |
| `.claude/skills/` | Slash commands: `/status`, `/phase`, `/verify`, `/review`, `/smoke`, `/endpoint`. |
| `.claude/agents/` | Reviewer subagents: `go-reviewer`, `security-auditor`, `spec-checker`, `test-writer`. |
| `.claude/hooks/` + `.claude/settings.json` | Guardrails that run automatically (see section 5). |
| `scripts/make.ps1` + `Makefile` | The build pipeline. Same targets on Windows (PowerShell) and elsewhere (make). Both read service identity from PLAN.md via `scripts/lib/PlanConfig.ps1` / `scripts/plan-config.sh`. |
| `tools/go.mod` | Pins golangci-lint, mockery and swag as Go `tool` directives so nothing is installed globally. |

The loop you drive:

```
/status  ->  /phase  ->  (agent runs /verify and /review itself)  ->  you review the diff  ->  you commit
```

## 2. One-time setup

1. Follow section 0 if this is a new service (edit PLAN.md, run `scripts/make.ps1 init`).
2. Install Docker Desktop and start it (only needed for integration tests, `/smoke`, and any
   compose stack the spec calls for).
3. Warm the pinned tools once (compiles golangci-lint, takes a few minutes the first time):
   ```
   powershell -NoProfile -ExecutionPolicy Bypass -File scripts/make.ps1 tools
   ```
4. Optional: create a `.env` from `.env.example` once Phase 1 adds one. The agent is denied
   access to `.env`; `scripts/make.ps1 run` loads it for you.
5. Open Claude Code in this folder. The SessionStart hook prints the phase table, so the first
   thing you see is where the project stands.

## 3. The daily loop

**See where things are**
```
/status
```
Prints the resolved Project block (service name, module path, stack), the phase table
(done/total per phase), the next phase, git status, and whether the tree passes `verify`.
Read-only.

**Build the next phase**
```
/phase          # next unfinished phase
/phase 3        # a specific phase
```
The agent reads the phase in PLAN.md and the matching sections of the spec file, writes code and
tests, runs `verify`, launches the reviewer agents through `/review`, fixes their findings, ticks
the boxes, and writes a Progress log line. It refuses to skip ahead if an earlier phase has open
boxes.

**Review and commit (you)**
```
git diff
git status
git add -A && git commit -m "Phase N: ..."
```
The agent cannot commit, push, rebase, reset --hard or clean; a hook blocks those commands.
If you want changes, just tell the agent what to change and it re-runs verify and review.

**Repeat** until `/status` says all phases are ticked, then run the end-to-end block at the
bottom of PLAN.md and `/smoke`.

## 4. Commands cheat sheet

Slash commands inside Claude Code:

| Command | What it does |
|---|---|
| `/status` | Project block, phase table, next phase, verify state. Read-only. |
| `/phase [N]` | Implement phase N (or the next one) end to end. |
| `/verify` | fmt-check, vet, lint, unit tests with `-race`, build. Fix until green. |
| `/review [N \| paths]` | Run go-reviewer, security-auditor and spec-checker in parallel, fix findings, re-verify. |
| `/smoke` | Build and run the service, hit the configured health endpoint, run project-specific checks if present, tear down. |
| `/endpoint <description>` | Add a new REST endpoint through all layers with tests, mocks and swagger (default stack profile). |

Same pipeline from a terminal (PowerShell or Git Bash):

```
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/make.ps1 <target>
```

| Target | What it does |
|---|---|
| `init` | One-time: apply PLAN.md's Project block to go.mod, tools/go.mod, .golangci.yml |
| `verify` | fmt-check + vet + lint + test + build, stops at first failure, ends with `VERIFY OK` |
| `test` / `test-integration` | Unit tests with `-race -cover` / integration tests (Docker) |
| `lint` / `fmt` / `fmt-check` / `vet` | Individual checks |
| `build` / `run` | Build `bin/<service_name>.exe` with version ldflags / run with `.env` loaded |
| `mocks` / `swagger` / `generate` | Regenerate mockery mocks / OpenAPI docs / `go generate` |
| `migrate-up` / `migrate-down` | Apply / roll back migrations with `cmd/migrate` |
| `up` / `down` / `logs` | docker compose stack |
| `smoke` | `scripts/smoke.ps1` end-to-end check with a PASS/FAIL table |
| `status` | `scripts/plan-status.ps1` Project block + phase table |
| `tools` / `tidy` / `clean` | Warm the pinned tools / `go mod tidy` both modules / remove `bin/` |

On Linux or macOS with make installed, `make <target>` is identical.

## 5. The guardrails and what they do

All of these run automatically; you do not call them. None of them are service-specific.

| Guardrail | When | Effect |
|---|---|---|
| `session-start.ps1` | Every session start, resume, clear or compact | Injects the phase table and the environment facts into the agent's context. |
| `guard-git.ps1` | Before every Bash command | Blocks `git commit`, `push`, `reset --hard`, `clean`, `rebase`, `stash drop`, and discarding the whole tree. Committing is yours. |
| `gofmt.ps1` | After every Write/Edit of a `.go` file | Formats the file in place. |
| `stop-check.ps1` | When the agent tries to end its turn | If Go files exist and the tree is uncommitted, runs `gofmt -l`, `go build ./...`, `go vet ./...`. On failure the agent is told to keep working and fix it. A loop guard lets it stop on the second attempt so it can report a real blocker. |
| Permission allowlist | Always | Go, gofmt, docker compose, curl.exe, the scripts, and read-only git commands run without prompts. |
| Permission denylist | Always | Reading or writing `.env`, and the git commands above, are refused at the permission layer as well. |

## 6. The reviewers

`/phase` and `/review` launch these subagents. You can also ask for one directly
("run the security-auditor on internal/auth"). None of them hardcode a service name; they read
CLAUDE.md, PLAN.md's Project block, and the spec file.

| Agent | Checks |
|---|---|
| `go-reviewer` | CLAUDE.md violations: layering, `%w` wrapping, `errors.Is`, tests for every exported service method, secrets in logs, parameterised SQL, context-first, magic strings, respond helper usage. Also runs fmt-check, vet and lint. |
| `security-auditor` | Auth hygiene appropriate to PLAN.md's `auth` choice (JWT algorithm pinning / session hygiene / N-A for `none`), password hashing, request size limits and strict decoding, route protection boundaries against the spec, information leakage, `.env` hygiene. |
| `spec-checker` | Walks every bullet of the spec file and the PLAN.md phase and reports DONE / PARTIAL / MISSING / DIVERGES with file:line evidence. |
| `test-writer` | Writes table-driven testify tests for a package that has untested exported functions. |

## 7. After the plan is finished

- New endpoint: `/endpoint POST /api/v1/widgets/{id}/activate that ...`. It walks DTO → service →
  repository → mocks → handler → tests → swagger → verify → review (default stack profile;
  adapt if PLAN.md chose a different router/db_driver).
- Any other change: describe it, then ask for `/verify` and `/review`. The Stop hook still
  guarantees the tree builds when the agent hands back.
- Full stack locally: `scripts/make.ps1 up`, then whatever ports/paths the spec defines.

## 8. Troubleshooting

| Symptom | Fix |
|---|---|
| `verify` says `lint: no Go files yet, skipping` | Expected before Phase 1 has code. |
| `go tool -modfile=tools/go.mod ...` says missing go.sum entry | `scripts/make.ps1 tidy`, then `scripts/make.ps1 tools`. |
| The agent says it is "blocked by stop-check" and keeps going | Correct behaviour: the build is broken. Let it fix it, or tell it what to do. |
| The agent says a git command was blocked | Correct behaviour. Run the git command yourself. |
| `go.mod`'s module line doesn't match PLAN.md's `module_path` | Run `scripts/make.ps1 init`. |
| `/smoke` fails at the health check | Confirm PLAN.md's `health_path`/`http_port` match what the service actually serves; check the server log paths the script prints. |
| `/smoke` needs project-specific assertions | Add them to `scripts/smoke.project.ps1` (an optional file this service commits; dot-sourced automatically if present) instead of editing `scripts/smoke.ps1`. |
| Integration tests skip | Docker is not running; unit tests still ran. Start Docker and run `scripts/make.ps1 test-integration`. |
| `-race` fails to build | gcc must be on PATH (MSYS2 ucrt64 works). |
| The agent wants a new dependency | It must ask first (CLAUDE.md). Answer yes or no; it then runs `go get` and `tidy`. |

## 9. Changing the framework itself

Do this only when you want to change behaviour for every future service built from this
template — not to point it at a new service (that's PLAN.md, see section 0).

- Rules: edit `CLAUDE.md`. Keep it short; it is loaded every session.
- Plan shape: edit the placeholder structure in `PLAN.md` (the parts outside `## Phase N`
  sections). Phases must stay `## Phase N: title` headers with `- [ ]` boxes; `scripts/plan-status.ps1`
  and the Makefile only understand that shape, plus the `## Project` block's `- key: value` lines.
- New Project-block key: add it to the defaults in `scripts/lib/PlanConfig.ps1` and read it the
  same way in `scripts/plan-config.sh` (POSIX awk) so both platforms agree.
- New slash command: add `.claude/skills/<name>/SKILL.md` with `name` and `description` frontmatter.
- New reviewer: add `.claude/agents/<name>.md` with `name`, `description`, `tools` frontmatter.
- New guardrail: add a PowerShell script under `.claude/hooks/` and wire it in
  `.claude/settings.json` (`PreToolUse`, `PostToolUse`, `Stop`, `SessionStart`). Hooks read a JSON
  payload on stdin; exit 2 with a message on stderr blocks a tool call, and a Stop hook blocks by
  printing `{"decision":"block","reason":"..."}`.
- New build step: add the target to both `Makefile` and `scripts/make.ps1`, and to the allowlist
  in `.claude/settings.json` if it is a new script.
