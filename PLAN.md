# <SERVICE NAME> implementation plan

<!--
  HOW TO REUSE THIS TEMPLATE FOR A NEW SERVICE
  =============================================
  This file is the only thing you edit to point the whole framework (Makefile, scripts, hooks,
  skills, agents) at a new service. See GUIDE.md section 0 for the full walkthrough. Short version:

  1. Fill in the `## Project` block below (service name, module path, port, stack choices).
  2. Write the spec file named by `spec_file` below (what "done" means for this service).
  3. Fill in `## Environment facts` and `## Key design decisions` for this machine and this service.
  4. Replace the placeholder phases below with your own `## Phase N: <title>` sections, each with
     `- [ ]` checkboxes, a `Verify:` line, and a `Notes:` line. Keep Phase 0 (bootstrap) — it
     applies the Project block to go.mod/.golangci.yml and only needs to run once.
  5. Run `scripts/make.ps1 init` (or `make init`) once to apply module_path to go.mod, tools/go.mod
     and .golangci.yml.
  6. Drive the loop: /status -> /phase -> (agent runs /verify and /review) -> you review -> commit.

  scripts/plan-status.ps1, the Makefile and scripts/make.ps1 all parse this file mechanically, so
  keep the shape: `## Project` is a flat `- key: value` list; phases are `## Phase N: title`
  headers with `- [ ]` boxes; nothing else here is parsed by tooling.
-->

## Project

- service_name: service
- module_path: github.com/CHANGEME/service-name
- main_pkg: ./cmd/service
- http_port: 8080
- db_name: servicedb
- spec_file: SPEC.md
- router: chi
- db_driver: pgx
- auth: jwt
- observability: prometheus
- health_path: /health/ready

<!-- Supported values today: router: chi | gin | echo | net/http · db_driver: pgx | database/sql |
     gorm · auth: jwt | session | none · observability: prometheus | otel | none. CLAUDE.md's
     "Tech Stack" section describes the default (chi/pgx/jwt/prometheus) and what changes for each
     override. If a service needs something not listed, say so under "Key design decisions" below
     and the agent follows the spec instead of the default. -->

## Context

The file named by `spec_file` above (default `SPEC.md`) is the specification — what "done" means
for this service. The agent never edits it. This file is the phased build plan: cut the spec into
phases that each compile, pass their own tests, and can be verified independently.

## Environment facts that shape the plan

- Go version, OS/shell, Docker availability, and anything NOT installed globally (this determines
  whether dev tools go in tools/go.mod, whether integration tests can run locally, etc.) — fill in
  before Phase 0.

## Key design decisions (apply throughout)

- Record cross-cutting choices here once so every phase agrees: transaction pattern, event/outbox
  pattern, auth flow, enum storage, migration strategy, and anything that deviates from CLAUDE.md's
  default stack profile.

---

## Phase 0: Framework bootstrap (run once per new service)

- [ ] `## Project` block above filled in for this service
- [ ] `scripts/make.ps1 init` (or `make init`) run once: applies module_path to go.mod,
      tools/go.mod and .golangci.yml's local-prefixes
- [ ] Spec file (see `spec_file` above) written
- [ ] `## Environment facts` and `## Key design decisions` above filled in
- [ ] Phase 1+ below replaced with this service's real phases (delete this line once done)

Verify: `scripts/make.ps1 status` shows the Project block resolved and `go.mod`'s module line
matches `module_path`.

Notes:

---

## Phase 1: <first vertical slice — rename this>

- [ ] <files/packages this phase creates, one per line>

Verify: `<the exact command that proves this phase works>`

Notes:

---

## Progress log

One line per `/phase` run, newest last: `- YYYY-MM-DD Phase N: done|partial — one sentence`.
