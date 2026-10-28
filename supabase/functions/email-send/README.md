# email-send

Sends transactional email through Resend.

- **Auth:** `send_email` permission, or a valid `X-Internal-Secret`.
- **Method:** `POST`.
- **Body:** either `template_code` + `profile_id` or `to` + `subject` + `html` or `text`. Optional
  `variables`, `reference_type`, and `reference_id`.
- **Secrets:** `RESEND_API_KEY` and `RESEND_FROM_EMAIL`.
- **Idempotency:** template sends reuse `public.send_notification`; direct sends create a
  `notification_log` row before provider delivery.

The handler validates that direct sends include a recipient, subject, and at least one body format.
Provider failures follow the shared retry and dead-letter policy. Email addresses and message bodies
are never logged.
