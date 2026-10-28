# scheduled-retention

Runs retention, idempotency, and expired-export cleanup.

- **Auth:** `X-Cron-Secret` matching `CRON_SECRET`.
- **Method:** `POST`.
- **Response:**
  `{ policies_applied, rows_deleted_by_table, total_rows_deleted, idempotency_keys_deleted, expired_exports_deleted, expired_export_records_cleared, webhook_events_deleted, completed_at }`.

Calls `apply_retention_policies` and `cleanup_idempotency_keys`, then lists the `data-exports`
Storage bucket through the Storage API and removes objects older than 30 days. It finally calls
`cleanup_expired_data_exports`, which clears the matching `delivered_file_path` pointers, and
`cleanup_payment_webhook_events`, which removes dedupe rows older than 24 months. Direct deletes
from `storage.objects` are intentionally avoided because Supabase blocks them and they would leave
orphaned objects.

The Phase 6 retention policies remain the source of truth for row-level deletion; this function only
orchestrates them. `expired_exports_deleted` counts removed Storage objects and
`expired_export_records_cleared` counts cleared data-subject-request pointers;
`webhook_events_deleted` counts expired webhook dedupe rows.
