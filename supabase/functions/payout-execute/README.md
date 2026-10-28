# payout-execute

Executes a driver payout through Selcom or Flutterwave.

- **Auth:** `process_payouts` permission.
- **Method:** `POST`.
- **Headers:** `X-Idempotency-Key` is required.
- **Body:** `{ payout_id, provider_code? }`.
- **Response:** `{ payout_id, status, provider_reference }`.

The handler moves an approved payout to `processing`, looks up the driver's payout phone, initiates
the provider transfer, then calls the Phase 5 `execute_payout` RPC with the user's JWT to complete
the payout and debit the wallet. Already-completed payouts are returned idempotently. Provider
rejection marks the payout failed and records a dead letter.
