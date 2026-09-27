# <Service name> — specification

<!-- This is what "done" means for this service. PLAN.md's phases implement this; the agent never
     edits this file. Replace every placeholder below (and delete this comment) before Phase 1. -->

## Overview

One paragraph: what this service does, who calls it, and why it exists.

## Package layout

List the packages/directories this service will have (cmd/<service_name>, internal/handler,
internal/service, internal/repository, internal/model, internal/dto, ...). Adapt to whatever
router/db_driver PLAN.md's Project block chose.

## Dependencies

Third-party packages this service needs beyond the default profile (see CLAUDE.md), one per line,
with why. New dependencies still need sign-off per CLAUDE.md's workflow rule.

## API / interface

Endpoints (or RPC methods, CLI commands, message topics — whatever this service exposes), request
and response shapes, auth requirements.

## Data model

Entities, their fields, relationships, and any state machines.

## Non-functional requirements

Performance, security, observability, and operational requirements (health checks, metrics,
graceful shutdown, etc.).
