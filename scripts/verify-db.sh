#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONTAINER="${SUPABASE_DB_CONTAINER:-supabase_db_safeshift}"

if ! docker inspect -f '{{.State.Running}}' "$CONTAINER" >/dev/null 2>&1; then
  echo "error: $CONTAINER is not running." >&2
  echo "Start it with: pnpm db:start" >&2
  exit 1
fi

for phase in 1 2 3 4 5 6; do
  gateway="$ROOT/supabase/scripts/verify-phase-${phase}-schema.sql"
  output="$(mktemp)"

  echo "==> Phase ${phase} schema verification"
  if ! docker exec -i "$CONTAINER" psql -U postgres -d postgres -v ON_ERROR_STOP=1 < "$gateway" > "$output" 2>&1; then
    cat "$output"
    rm -f "$output"
    exit 1
  fi

  if ! grep -Eq "PHASE ${phase} SCHEMA VERIFICATION: [0-9]+ PASS, 0 FAIL" "$output"; then
    cat "$output"
    rm -f "$output"
    exit 1
  fi

  grep -E "PHASE ${phase} SCHEMA VERIFICATION" "$output" | tail -1
  rm -f "$output"
done

echo "All database gates passed."
