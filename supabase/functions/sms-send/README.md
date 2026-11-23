# sms-send

Sends an SMS through Meseji (https://meseji.co.tz), the only SMS provider.

- **Auth:** `send_sms` permission, or a valid `X-Internal-Secret` for trusted sibling functions.
- **Method:** `POST`.
- **Body:** either `template_code` + `profile_id` (preferred) or `to` + `body`. Optional
  `variables`, `reference_type`, and `reference_id`.
- **Secrets:** `MESEJI_API_KEY`; optional `MESEJI_SENDER_ID` (default `SAFESHIFT`) and
  `MESEJI_BASE_URL` (default `https://meseji.co.tz/api/v1`).
- **Idempotency:** template sends reuse `public.send_notification`; direct sends create a
  `notification_log` row before provider delivery.

Provider retries use the shared 1s/4s/16s policy. Exhausted calls are recorded in
`dead_letter_queue`. Recipient phone numbers are redacted from logs.
