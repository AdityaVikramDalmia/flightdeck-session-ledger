#!/usr/bin/env bash
# Deprecated reference example for new Claude Code integrations (2026-09-22).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
STORE="$(mktemp -d "${TMPDIR:-/tmp}/ledger-example.XXXXXXXX")"
trap 'rm -rf "$STORE"' EXIT
export SESSION_LEDGER_DIR="$STORE/state"
"$ROOT/bin/session-ledger" append launched worker-1 --by supervisor project=example
"$ROOT/bin/session-ledger" append needs_input worker-1 'note=Waiting for review'
"$ROOT/bin/session-ledger" live
"$ROOT/bin/session-ledger" append finished worker-1 result=passed
"$ROOT/bin/session-ledger" history worker-1
"$ROOT/bin/session-ledger" validate
