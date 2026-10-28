# sms-send

Sends an SMS through Beem with Africa's Talking as fallback.

- **Auth:** `send_sms` permission, or a valid `X-Internal-Secret` for trusted sibling functions.
- **Method:** `POST`.
- **Body:** either `template_code` + `profile_id` (preferred) or `to` + `body`. Optional
  `variables`, `reference_type`, and `reference_id`.
- **Secrets:** `BEEM_API_KEY`, `BEEM_SECRET_KEY`, `AFRICASTALKING_USERNAME`,
  `AFRICASTALKING_API_KEY`, and `AFRICASTALKING_SENDER_ID`.
- **Idempotency:** template sends reuse `public.send_notification`; direct sends create a
  `notification_log` row before provider delivery.

Provider retries use the shared 1s/4s/16s policy. Exhausted calls are recorded in
`dead_letter_queue`. Recipient phone numbers are redacted from logs.
