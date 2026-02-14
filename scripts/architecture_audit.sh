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

check_no_matches "No compatibility RPC mentions" "server\\.hs_start|server\\.hs_requestTag|server\\.hs_useAbility|server\\.hs_triggerSuperjump|server\\.hs_ability|server\\.hs_timeSync|server\\.hs_updateLoadout|server\\._teamsJoinTeam" "hs"
check_no_matches "No legacy/compat wording in runtime code" "legacy|compat" "hs"

check_required_match "Canonical server command endpoint present" "function server\\.hs_command" "hs/infra/adapters/net/server_handlers.lua"
SERVER_ENDPOINTS="$(rg -n '^function server\\.hs_' hs -S || true)"
if [[ -n "$SERVER_ENDPOINTS" ]]; then
  while IFS= read -r line; do
    file="${line%%:*}"
    if [[ "$file" != "hs/infra/adapters/net/server_handlers.lua" ]]; then
      echo "[FAIL] Unexpected server.hs_* endpoint: $line" >&2
      exit 1
    fi
    if [[ "$line" != *"function server.hs_command"* ]]; then
      echo "[FAIL] Unexpected server.hs_* endpoint: $line" >&2
      exit 1
    fi
  done <<< "$SERVER_ENDPOINTS"
fi
pass "Only server.hs_command endpoint is defined"

check_required_match "Client event ingress present" "function client\\.hs_event" "hs/infra/adapters/net/client_handlers.lua"
check_required_match "Infra event emitter validates envelopes" "validate\\.eventEnvelope" "hs/infra/events.lua"
check_required_match "Snapshot writer exists" "HS\\.infra\\.snapshot" "hs/infra/snapshot_writer.lua"
check_required_match "Snapshot sync owner wrapper exists" "function HS\\.srv\\.syncShared" "hs/server/round.lua"
check_required_match "Start match readiness gate present" "hs\\.toast\\.needPlayersPerTeam" "hs/domain/reducers/command.lua"
check_required_match "Seeker grace is enforced" "seekerGraceEndsAt" "hs/domain/reducers/tick.lua"

check_required_match "Snapshot meta field written" "meta\s*=\s*\{" "hs/infra/snapshot_writer.lua"
check_required_match "Snapshot match field written" "match\s*=\s*\{" "hs/infra/snapshot_writer.lua"
check_required_match "Snapshot players field written" "players\s*=\s*\{" "hs/infra/snapshot_writer.lua"
check_required_match "Snapshot abilities field written" "abilities\s*=\s*\{" "hs/infra/snapshot_writer.lua"
check_required_match "Snapshot settings field written" "settings\s*=\s*" "hs/infra/snapshot_writer.lua"
check_required_match "Snapshot uiHints field written" "uiHints\s*=\s*\{" "hs/infra/snapshot_writer.lua"

SERVER_CALL_LINES="$(rg -n 'ServerCall\(' hs -S || true)"
if [[ -n "$SERVER_CALL_LINES" ]]; then
  while IFS= read -r line; do
    file="${line%%:*}"
    if [[ "$file" != "hs/core/engine.lua" ]]; then
      echo "[FAIL] Direct ServerCall usage outside hs/core/engine.lua: $line" >&2
      exit 1
    fi
  done <<< "$SERVER_CALL_LINES"
fi
pass "Direct ServerCall usage confined to hs/core/engine.lua"

# Allow only expected files to touch shared.hs directly.
SHARED_WRITES="$(rg -n 'shared\\.hs\s*=' hs -S || true)"
if [[ -n "$SHARED_WRITES" ]]; then
  while IFS= read -r line; do
    file="${line%%:*}"
    if [[ "$file" != "hs/infra/snapshot_writer.lua" ]]; then
      echo "[FAIL] shared.hs write outside snapshot writer: $line" >&2
      exit 1
    fi
  done <<< "$SHARED_WRITES"
fi
pass "shared.hs writes confined to hs/infra/snapshot_writer.lua"

# Domain purity: no engine globals in domain layer.
check_no_matches "No Teardown API calls in domain layer" "GetPlayer|SetPlayer|RespawnPlayer|DisablePlayer|ClientCall|ServerCall|QueryRaycast|GetEvent|GetTime\(" "hs/domain"

# App layer should orchestrate but not render.
check_no_matches "No render globals in app layer" "Ui[A-Z]|Particle|SpawnParticle" "hs/app"

echo "Architecture audit completed successfully."
