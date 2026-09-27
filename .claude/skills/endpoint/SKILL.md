---
name: endpoint
description: Add a new REST endpoint following the project's handler → service → repository pattern, with tests, mocks and swagger regenerated.
---

Assumes the default stack profile (chi, pgx, mockery). If PLAN.md's `## Project` block chose a
different router/db_driver, adapt the steps below to that stack's equivalents.

The user will describe an endpoint. Create or update, in this order:
1. DTO structs in internal/dto (json + validate tags; custom validator tags go in validate.go).
2. Service interface method in internal/service/interfaces.go and its implementation
   (business rules, self-or-admin check via authorizeSelfOrAdmin when the route is per-user,
   events appended inside the transaction and flushed after commit).
3. Repository interface method in internal/repository/interfaces.go plus the postgres
   implementation (parameterised SQL, errors passed through translate()).
4. Regenerate mocks: `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/make.ps1 mocks`.
5. Handler method with swag annotations (@Summary @Tags @Param @Success @Failure @Router
   @Security) using decodeJSON / respond.JSON / respond.Error, and a chi route in router.go under
   the correct protection group (public / authenticated / admin).
6. Unit tests for the service method (table-driven, mocks), a handler test for decode and status
   codes, and an integration test in internal/integration if it touches the database.
7. Regenerate swagger: `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/make.ps1 swagger`.
8. Run the /verify skill, then the /review skill on the changed packages.

Never commit. If the endpoint needs a new third-party dependency, ask first (CLAUDE.md).
