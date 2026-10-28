# payment-selcom-initiate

Starts a Selcom mobile-money charge for a delivered/completed job.

- **Auth:** bearer JWT; only the job customer may initiate.
- **Method:** `POST`.
- **Headers:** `X-Idempotency-Key` is required.
- **Body:** `{ job_id, phone, payment_method_id?, amount? }`.
- **Secrets:** `SELCOM_API_KEY`, `SELCOM_API_SECRET`, `SELCOM_VENDOR_ID`.
- **Response:** `201` with `{ payment_id, provider_reference, status, redirect_url }`.

The function creates a pending payment through `job_payment_initiate`, then calls Selcom. A
successful provider reference is attached while the payment is still pending. Provider failure marks
the payment failed and returns `502 provider_error`. The idempotency cache is keyed by the caller
header and scoped to this function.
