#!/usr/bin/env bash
set -euo pipefail

# Tail the local-only SMS outbox populated by public.send_sms_hook.
# Usage: pnpm db:watch-otp

CONTAINER="${SUPABASE_DB_CONTAINER:-supabase_db_safeshift}"

if ! docker inspect -f '{{.State.Running}}' "$CONTAINER" >/dev/null 2>&1; then
  echo "error: $CONTAINER is not running." >&2
  echo "Start it with: pnpm db:start" >&2
  exit 1
fi

query() {
  docker exec -i "$CONTAINER" psql -U postgres -d postgres -A -t -F $'\t' -c "$1"
}

if [[ "$(query "select to_regclass('public.local_sms_outbox') is not null")" != "t" ]]; then
  echo "error: public.local_sms_outbox does not exist." >&2
  echo "Recreate the local database with: pnpm db:reset" >&2
  exit 1
fi

latest="$(query "select id, phone, otp, to_char(created_at, 'HH24:MI:SS') from public.local_sms_outbox order by id desc limit 1")"
if [[ -n "$latest" ]]; then
  IFS=$'\t' read -r last latest_phone latest_otp latest_sent_at <<< "$latest"
  echo "Most recent: [$latest_sent_at] $latest_phone -> $latest_otp"
else
  last=0
fi

echo "Watching local SMS OTPs (Ctrl+C to stop)..."
echo "Request an OTP from the app; codes appear below."
echo

while true; do
  rows="$(query "select id, phone, otp, to_char(created_at, 'HH24:MI:SS') from public.local_sms_outbox where id > ${last} order by id")"

  if [[ -n "$rows" ]]; then
    while IFS=$'\t' read -r id phone otp sent_at; do
      [[ -z "$id" ]] && continue
      printf '[%s] %s -> %s\n' "$sent_at" "$phone" "$otp"
      last="$id"
    done <<< "$rows"
  fi

  sleep 1
done
