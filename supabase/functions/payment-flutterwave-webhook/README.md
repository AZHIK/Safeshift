# payment-flutterwave-webhook

Receives Flutterwave charge, refund, and transfer callbacks.

- **Auth:** `verif-hash` header compared to the configured webhook secret. Invalid or missing
  signatures return `401 unauthorized`.
- **Method:** `POST`.
- **Secrets:** `FLUTTERWAVE_WEBHOOK_SECRET`, or the provider row's `webhook_secret_reference` Vault
  name.
- **Idempotency:** unique `(provider_id, event_id)` in `payment_webhook_events`; the atomic
  `record_payment_webhook` RPC appends the matching `payment_webhooks` row.

Charge events call `job_pay_complete`; refund events update the refund record; transfer events
update the payout to completed or failed. Unknown references and non-terminal events are recorded as
ignored. All outcomes are persisted in `payment_webhooks`.
