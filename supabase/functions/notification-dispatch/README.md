# notification-dispatch

Fans a template notification out across push, SMS, and email.

- **Auth:** `send_notification` permission.
- **Method:** `POST`.
- **Body:**
  `{ profile_id, template_code, channels: ['push'|'sms'|'email'], variables?, reference_type?, reference_id? }`.
- **Response:** `{ notification_ids, channels_used, failures }`.

Each channel first calls the Phase 6 `send_notification` RPC. The RPC applies the recipient's
preferences, quiet hours, and template rendering. A `null` result means the channel was
intentionally skipped; it is not a failure. The handler then delivers the created `notification_log`
row through the shared SMS, email, or FCM code path. If every requested channel fails, the response
is `502 provider_error`.
