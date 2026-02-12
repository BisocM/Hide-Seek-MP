#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

fail() {
  echo "[FAIL] $1" >&2
  exit 1
}

pass() {
  echo "[PASS] $1"
}

check_no_matches() {
  local label="$1"
  local pattern="$2"
  local target="${3:-hs}"
  if rg -n "$pattern" "$target" -S >/tmp/hs_audit_matches.txt 2>/dev/null; then
    echo "[FAIL] ${label}" >&2
    cat /tmp/hs_audit_matches.txt >&2
    exit 1
  fi
  pass "$label"
}

check_required_match() {
  local label="$1"
  local pattern="$2"
  local target="${3:-hs}"
  if ! rg -n "$pattern" "$target" -S >/tmp/hs_audit_required.txt 2>/dev/null; then
    fail "$label"
  fi
  pass "$label"
}

echo "Running Hide & Seek architecture audit..."

check_no_matches "No banned legacy namespace/patterns" "HS\\.legacy|srv\\.app\\.internal|\\.legacy|gameplay_"
check_no_matches "No direct Teardown calls in domain layer" "GetPlayer|SetPlayer|RespawnPlayer|DisablePlayer|ClientCall|ServerCall|QueryRaycast|GetEvent" "hs/domain"
check_no_matches "No direct ServerCall usage (use HS.engine.serverCall)" "ServerCall\\(" "hs"

# Server RPC entrypoints should only exist in main hooks and net ingress handlers.
SERVER_FN_LINES="$(rg -n '^function server\\.' hs -S || true)"
if [[ -n "$SERVER_FN_LINES" ]]; then
  while IFS= read -r line; do
    file="${line%%:*}"
    if [[ "$file" != "hs/main.lua" && "$file" != "hs/net/server_handlers.lua" ]]; then
      echo "[FAIL] Server entrypoint defined outside net/main: $line" >&2
      exit 1
    fi
  done <<< "$SERVER_FN_LINES"
fi
pass "Server entrypoints confined to hs/main.lua and hs/net/server_handlers.lua"

check_required_match "Canonical installer exists" "HS\\.arch\\.app\\.install" "hs/app/init.lua"
check_required_match "Server stage command-ingress present" 'name = "command-ingress"' "hs/systems/server/stages/command_ingress.lua"
check_required_match "Server stage snapshot-publish present" 'name = "snapshot-publish"' "hs/systems/server/stages/snapshot_publish.lua"
check_required_match "Client tick stage tag-input present" 'name = "tag-input"' "hs/systems/client/tick/tag_input_tick.lua"
check_required_match "Client draw stage admin-draw present" 'name = "admin-draw"' "hs/systems/client/draw/admin_draw.lua"

check_required_match "Snapshot version field written" "sh\\.version" "hs/state/snapshot.lua"
check_required_match "Snapshot schema field written" "sh\\.schema" "hs/state/snapshot.lua"
check_required_match "Snapshot revision field written" "sh\\.revision" "hs/state/snapshot.lua"

echo "Architecture audit completed successfully."
