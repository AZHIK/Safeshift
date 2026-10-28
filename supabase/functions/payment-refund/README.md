# payment-refund

Issues a full or partial refund through the original payment provider.

- **Auth:** `process_refunds` permission.
- **Method:** `POST`.
- **Headers:** `X-Idempotency-Key` is required.
- **Body:** `{ payment_id, amount, reason, refund_type? }`.
- **Response:** `201` with `{ refund_id, refund_payment_id, status, provider_reference }`.

The handler verifies that the original charge succeeded and that the provider supports refunds, then
calls the Phase 5 `payment_refund` RPC with the user's JWT so permission and wallet semantics remain
database-enforced. The provider call happens after the refund row exists. Provider failure marks the
refund record failed and returns `502 provider_error`; the Phase 5 refund payment and ledger rows
are not silently deleted.
