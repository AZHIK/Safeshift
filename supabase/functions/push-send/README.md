# push-send

Sends a Firebase Cloud Messaging notification to a profile's active devices or to one explicit
device token.

- **Auth:** `send_push` permission, or a valid `X-Internal-Secret`.
- **Method:** `POST`.
- **Body:** `{ profile_id? , device_token?, title, body, data?, deep_link? }`. At least one of
  `profile_id` or `device_token` is required.
- **Secrets:** `FCM_PROJECT_ID` and `FCM_SERVICE_ACCOUNT_JSON`.
- **Response:** `{ sent, failed, invalid_tokens, notification_id }`.

Invalid FCM tokens are marked inactive. If every token fails, the function returns
`502 provider_error` and records the failure in `dead_letter_queue`. The service-account private key
is only used in memory for OAuth signing.
