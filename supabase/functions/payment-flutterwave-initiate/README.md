# payment-flutterwave-initiate

Starts a Flutterwave card or mobile-money charge for a job.

- **Auth:** bearer JWT; only the job customer may initiate.
- **Method:** `POST`.
- **Headers:** `X-Idempotency-Key` is required.
- **Body:** `{ job_id, phone? or card_token?, payment_method_id?, amount? }`.
- **Secrets:** `FLUTTERWAVE_SECRET_KEY`.
- **Response:** `201` with `{ payment_id, provider_reference, status, redirect_url }`.

The pending payment is created with `job_payment_initiate` before the provider call. The provider
reference is attached only while the payment is pending. Provider failures mark the payment failed
and return `502 provider_error`.
