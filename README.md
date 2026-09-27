# Autonomous-Go-Microservice-AGM-Agentic-Claude-Framework
# Go Service Autonomous Development Framework

A template for building Go services phase-by-phase using Claude Code. The framework handles code generation, testing, linting, and agent reviews while you control final reviews and commits.

Configurations live in `PLAN.md`. You do not need to edit core scripts, hooks, or agents to start a new service.

---

## Prerequisites

- **OS:** Windows (PowerShell) or Linux/macOS
- **Go:** 1.26+
- **Docker Desktop:** Required for integration tests, databases, and `/smoke` checks

---

## Quick Start

1. **Copy Repo:** Duplicate this repository into a new directory.
2. **Configure `PLAN.md`:**
   - Fill in `## Project` (`service_name`, `module_path`, `http_port`, `db_name`, `spec_file`, and tech stack options).
   - Update `## Environment facts` and `## Key design decisions`.
   - Define your target phases (`## Phase 1`, `## Phase 2`, etc.), keeping `## Phase 0`.
3. **Write Spec:** Fill out `SPEC.md` (or your chosen `spec_file`) to define project completion criteria.
4. **Initialize & Warm Tools:**
   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -File scripts/make.ps1 init
   powershell -NoProfile -ExecutionPolicy Bypass -File scripts/make.ps1 tools
