# scheduled-daily-metrics

Computes the previous UTC day's daily, zone, driver, and customer metrics.

- **Auth:** `X-Cron-Secret` matching `CRON_SECRET`.
- **Method:** `POST` (GET is also accepted by the shared handler).
- **Response:**
  `{ target_date, daily_metrics_rows, zone_metrics_rows, driver_metrics_rows, customer_metrics_rows, completed_at }`.

Calls the Phase 6 `compute_daily_metrics`, `compute_zone_metrics`, `compute_driver_metrics`, and
`compute_customer_metrics` RPCs. The function is idempotent because each RPC upserts by target date.
It is intended to be called by an external scheduler or a `pg_cron`/`pg_net` job.
