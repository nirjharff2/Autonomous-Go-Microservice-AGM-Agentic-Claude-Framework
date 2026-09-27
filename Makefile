# Go service template Makefile. On Windows without GNU make use the mirror:
#   powershell -NoProfile -ExecutionPolicy Bypass -File scripts/make.ps1 <target>
# Keep the target list in sync with scripts/make.ps1.
#
# Service identity and stack choices come from PLAN.md's `## Project` block (see GUIDE.md
# section 0), read here via scripts/plan-config.sh. Edit PLAN.md, not this file, to change them,
# then run `make init` once to apply module_path to go.mod/tools/go.mod/.golangci.yml.

PLAN_CFG   := scripts/plan-config.sh

APP        := $(shell $(PLAN_CFG) service_name service)
MODULE     := $(shell $(PLAN_CFG) module_path github.com/CHANGEME/service-name)
MAIN_PKG   := $(shell $(PLAN_CFG) main_pkg)
AUTH       := $(shell $(PLAN_CFG) auth jwt)
HTTP_PORT  := $(shell $(PLAN_CFG) http_port 8080)
BIN_DIR    := bin
TOOL_MOD   := tools/go.mod
GOTOOL     := go tool -modfile=$(TOOL_MOD)

VERSION    ?= $(shell git describe --tags --always --dirty 2>/dev/null || echo dev)
COMMIT     ?= $(shell git rev-parse --short HEAD 2>/dev/null || echo none)
BUILD_TIME ?= $(shell date -u +%Y-%m-%dT%H:%M:%SZ)
LDFLAGS    := -s -w -X main.version=$(VERSION) -X main.commit=$(COMMIT) -X main.buildTime=$(BUILD_TIME)

GO_DIRS    := $(wildcard cmd internal)
GO_FILES   := $(shell find $(GO_DIRS) -name '*.go' 2>/dev/null)

.PHONY: help init tools tidy fmt fmt-check vet lint test test-integration build verify run mocks generate \
        swagger migrate-up migrate-down docker-build up down logs smoke status clean

help: ## List targets
	@grep -E '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  %-17s %s\n", $$1, $$2}'

init: ## One-time: apply PLAN.md's Project block to go.mod, tools/go.mod and .golangci.yml
	go mod edit -module $(MODULE)
	cd tools && go mod edit -module $(MODULE)/tools
	@if [ -f .golangci.yml ]; then \
		tmp=$$(mktemp); \
		awk -v m="$(MODULE)" '/local-prefixes:/ { print; f=1; next } f==1 && /^[[:space:]]*-[[:space:]]/ { sub(/-[[:space:]].*/, "- " m); print; f=0; next } { print }' .golangci.yml > $$tmp && mv $$tmp .golangci.yml; \
	fi
	@echo "module set to $(MODULE); service name $(APP); main package $(MAIN_PKG)"
	@echo "run 'make tidy' if this changed which dependencies are actually used"

tools: ## Build/warm the pinned dev tools once
	$(GOTOOL) golangci-lint version
	$(GOTOOL) mockery --version
	$(GOTOOL) swag --version

tidy: ## go mod tidy for the main module and tools/
	go mod tidy
	cd tools && go mod tidy

fmt: ## gofmt -w every Go file
	@if [ -n "$(GO_FILES)" ]; then gofmt -l -w $(GO_DIRS); else echo "fmt: no Go files yet, skipping"; fi

fmt-check: ## Fail if any Go file is not gofmt-clean
	@if [ -n "$(GO_FILES)" ]; then \
		out=$$(gofmt -l $(GO_DIRS)); \
		if [ -n "$$out" ]; then echo "not gofmt-clean:"; echo "$$out"; exit 1; fi; \
	else echo "fmt-check: no Go files yet, skipping"; fi

vet: ## go vet ./...
	@if [ -n "$(GO_FILES)" ]; then go vet ./...; else echo "vet: no Go files yet, skipping"; fi

lint: ## golangci-lint run ./... (via tools/go.mod)
	@if [ -n "$(GO_FILES)" ]; then $(GOTOOL) golangci-lint run ./...; else echo "lint: no Go files yet, skipping"; fi

test: ## Unit tests with race detector and coverage
	@if [ -n "$(GO_FILES)" ]; then go test ./... -count=1 -race -cover; else echo "test: no Go files yet, skipping"; fi

test-integration: ## Integration tests (needs Docker)
	go test -tags integration ./... -count=1 -race

build: ## Build $(BIN_DIR)/$(APP) with version ldflags
	@mkdir -p $(BIN_DIR)
	@if [ -d $(MAIN_PKG) ]; then go build -ldflags '$(LDFLAGS)' -o $(BIN_DIR)/$(APP) $(MAIN_PKG); else go build ./...; fi

verify: fmt-check vet lint test build ## fmt-check + vet + lint + test + build
	@echo "VERIFY OK"

run: ## go run $(MAIN_PKG) (loads .env if present)
	@set -a; [ -f .env ] && . ./.env; set +a; \
	if [ "$(AUTH)" = "jwt" ]; then export JWT_SECRET=$${JWT_SECRET:-dev-secret-change-me}; fi; \
	export HTTP_PORT=$${HTTP_PORT:-$(HTTP_PORT)}; \
	go run -ldflags '$(LDFLAGS)' $(MAIN_PKG)

mocks: ## Regenerate mockery mocks from .mockery.yaml
	$(GOTOOL) mockery

generate: ## go generate ./...
	go generate ./...

swagger: ## Regenerate docs/ OpenAPI spec
	$(GOTOOL) swag init -g $(MAIN_PKG)/main.go -o docs --parseDependency --parseInternal

migrate-up: ## Apply migrations
	go run ./cmd/migrate up

migrate-down: ## Roll back one migration
	go run ./cmd/migrate down

docker-build: ## Build the container image
	docker build -t $(APP):$(VERSION) -t $(APP):latest \
		--build-arg VERSION=$(VERSION) --build-arg COMMIT=$(COMMIT) --build-arg BUILD_TIME=$(BUILD_TIME) .

up: ## docker compose up -d --build
	docker compose up -d --build

down: ## docker compose down
	docker compose down

logs: ## Tail the service logs
	docker compose logs -f $(APP)

smoke: ## End-to-end smoke test (Windows script)
	powershell -NoProfile -ExecutionPolicy Bypass -File scripts/smoke.ps1

status: ## Show PLAN.md progress
	powershell -NoProfile -ExecutionPolicy Bypass -File scripts/plan-status.ps1

clean: ## Remove build output
	rm -rf $(BIN_DIR)
