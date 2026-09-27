## Tech Stack
- Go 1.26 (latest stable), Go modules
- Service identity and stack choices live in PLAN.md's `## Project` block (service_name,
  module_path, router, db_driver, auth, observability) — read it every session; this file
  describes what each choice means, not the values themselves
- Default profile (used unless the Project block overrides a component):
  - Router: chi v5 · DB: PostgreSQL via pgx v5 (pgxpool), golang-migrate for plain-SQL migrations
  - Auth: JWT (golang-jwt/jwt/v5) · Observability: log/slog + Prometheus client
  - Validation: go-playground/validator v10
- Supported overrides and what changes:
  - `router`: chi (default) | gin | echo | net/http — routing/middleware idioms change; the
    layering rule below (handler -> service -> repository) does not
  - `db_driver`: pgx (default) | database/sql | gorm — the repository layer's Querier/WithTx shape
    changes; parameterised queries and the layering rule do not
  - `auth`: jwt (default) | session | none — internal/auth's contents change; if `none`, drop the
    JWT-specific rules below and skip the JWT checks in the security-auditor agent
  - `observability`: prometheus (default) | otel | none — internal/metrics's contents change
  - Anything the Project block asks for that isn't listed here: follow the spec file named by
    `spec_file` and record the decision under PLAN.md's "Key design decisions"

## Architecture Rules
- Layered architecture: Handler → Service → Repository
- Handlers must never access repositories directly
- All business logic lives in the service layer
- Dependencies are passed in via constructor functions (NewXService(repo, ...)); no globals, no init() wiring, no service locators
- Repositories and external clients are Go interfaces defined next to the code that consumes them, so they can be mocked in tests
- context.Context is always the first parameter of every service, repository and client method
- Every exported service method must be covered by a unit test

## Coding Conventions
- Use UUID (github.com/google/uuid) for all primary keys
- All timestamps are time.Time stored and compared in UTC
- All REST endpoints must be versioned under /api/v1/ (skip if the Project block's router/spec calls for something other than REST, e.g. gRPC or a CLI)
- DTOs are plain structs with json and validate struct tags; never expose model structs directly over HTTP
- Handlers write responses through a single shared helper (respond.JSON / respond.Error), never ad-hoc w.Write
- Wrap errors with fmt.Errorf("...: %w", err); compare with errors.Is / errors.As, never by string
- Tests use testify (assert/require) and are table-driven where there are multiple cases
- Code must be gofmt-clean and pass golangci-lint with the repo's .golangci.yml

## Error Handling
- Define sentinel/domain errors in an internal apperror package (ErrNotFound, ErrForbidden, ErrVersionConflict, plus whatever domain errors the spec needs)
- Never return (nil, nil) from a service method — return a value or an error
- Error → HTTP status mapping happens in exactly one place (the respond.Error helper), never inside individual handlers
- Never panic in the request path; a recovery middleware converts any panic into a 500

## Things to Avoid
- No fmt.Println / log.Println — use slog with structured key/value fields
- No package-level mutable state
- No magic strings — use constants or typed enums
- No business logic in handlers or models (state machines on domain models are the one exception)
- Never log or return password hashes, raw passwords, tokens or secrets
- No SQL string concatenation with user input — always use parameterised queries

## Commands (Windows: GNU make is NOT installed, use the PowerShell mirror)
- `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/make.ps1 <target>` mirrors every Makefile target; `make <target>` works on machines with make
- Targets: init (one-time, applies PLAN.md's Project block to go.mod/tools/go.mod/.golangci.yml), verify (fmt-check+vet+lint+test+build), test, test-integration, lint, fmt, build, run, mocks, swagger, migrate-up, migrate-down, up, down, logs, smoke, status, tools, tidy
- Dev tools (golangci-lint, mockery, swag) are pinned in tools/go.mod and run as `go tool -modfile=tools/go.mod <name>`; never install them globally or change their versions to dodge a finding
- Integration tests are behind the `integration` build tag and need Docker Desktop

## Workflow
- The spec file is named in PLAN.md's Project block (`spec_file`, default SPEC.md); the phased plan with checkboxes is PLAN.md; GUIDE.md explains the framework
- Loop: `/status` → `/phase` (next unfinished phase) → `/verify` → `/review` → tick PLAN.md boxes and add a Progress log line
- Run `scripts/make.ps1 verify` (lint + tests + build) before saying a task is done
- Never commit or push; I will commit myself after reviewing (a hook blocks git commit/push/reset --hard/clean/rebase)
- A Stop hook blocks ending a turn while Go files are unformatted or `go build` / `go vet` fail: fix, do not work around it
- When adding a new package, add a unit test file in the same package
- Ask before adding a new third-party dependency
- Never read or write .env (permission-denied); .env.example is the documented template
