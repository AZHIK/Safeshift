# email-send

Sends transactional email through Brevo (https://www.brevo.com), the only email provider.

- **Auth:** `send_email` permission, or a valid `X-Internal-Secret`.
- **Method:** `POST`.
- **Body:** either `template_code` + `profile_id` or `to` + `subject` + `html` or `text`. Optional
  `variables`, `reference_type`, and `reference_id`.
- **Secrets:** `BREVO_API_KEY`; `BREVO_SENDER` ("SafeShift <noreply@your-domain>", a sender verified
  in Brevo).
- **Idempotency:** template sends reuse `public.send_notification`; direct sends create a
  `notification_log` row before provider delivery.

The handler validates that direct sends include a recipient, subject, and at least one body format.
Provider failures follow the shared retry and dead-letter policy. Email addresses and message bodies
are never logged.
