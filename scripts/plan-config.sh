#!/usr/bin/env sh
# Prints one value from PLAN.md's `## Project` block (mirrors scripts/lib/PlanConfig.ps1, which
# Windows uses instead). Usage: plan-config.sh <key> [default]
set -eu

key="$1"
default="${2:-}"
plan="${PLAN_MD:-PLAN.md}"

get() {
    awk -v k="$1" '
        /^## Project[ \t]*$/ { inblock=1; next }
        /^## / { inblock=0 }
        inblock && $0 ~ "^[ \t]*-[ \t]*" k "[ \t]*:" {
            sub("^[ \t]*-[ \t]*" k "[ \t]*:[ \t]*", "")
            print
            exit
        }
    ' "$plan" 2>/dev/null
}

val=""
if [ -f "$plan" ]; then val=$(get "$key"); fi

if [ -z "$val" ] && [ "$key" = "main_pkg" ]; then
    svc=""
    if [ -f "$plan" ]; then svc=$(get "service_name"); fi
    [ -z "$svc" ] && svc="service"
    val="./cmd/$svc"
fi

if [ -z "$val" ]; then
    printf '%s\n' "$default"
else
    printf '%s\n' "$val"
fi
