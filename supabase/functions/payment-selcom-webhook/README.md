# payment-selcom-webhook

Receives Selcom payment and refund callbacks.

- **Auth:** provider signature. Invalid or missing signatures return `401 unauthorized`.
- **Method:** `POST`.
- **Secrets:** `SELCOM_WEBHOOK_SECRET`, or the provider row's `webhook_secret_reference` Vault name.
- **Idempotency:** `payment_webhook_events` has a unique `(provider_id, event_id)` key;
  `record_payment_webhook` atomically appends to `payment_webhooks`. Duplicates return
  `{ duplicate: true }` without reprocessing.

For charge events the handler finds the pending payment by provider reference and calls
`job_pay_complete` only for terminal statuses. Refund events update the refund record status.
Non-terminal and unknown references are recorded as ignored. Every outcome is written to
`payment_webhooks.processing_status`.
