# scheduled-demand-capture

Captures the current demand snapshot for pricing and analytics.

- **Auth:** `X-Cron-Secret` matching `CRON_SECRET`.
- **Method:** `POST`.
- **Response:** `{ snapshots_captured, captured_at }`.

Calls the Phase 4 `capture_demand_snapshot` RPC. The RPC is safe to retry; it writes the current
window's snapshot rather than appending duplicate rows.
