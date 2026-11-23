# auth-sms-hook

Supabase Auth **Send SMS hook**. Every phone OTP is delivered through Meseji
(https://meseji.co.tz), the only SMS provider.

- **Auth:** Standard Webhooks signature (`webhook-id`, `webhook-timestamp`,
  `webhook-signature`) signed with `SEND_SMS_HOOK_SECRET`. Requests older than
  five minutes are rejected.
- **Method:** `POST`, payload `{ user: { phone }, sms: { otp } }` from Supabase Auth.
- **Response:** `{}` on success, or `{ error: { http_code, message } }`, which Auth
  shows to the app.
- **Secrets:** `SEND_SMS_HOOK_SECRET`, `MESEJI_API_KEY`; optional `MESEJI_SENDER_ID`
  and `MESEJI_BASE_URL`.

## Hosted setup

1. `supabase secrets set MESEJI_API_KEY=... MESEJI_SENDER_ID=...`
2. `supabase functions deploy auth-sms-hook --no-verify-jwt`
3. Dashboard → Authentication → Hooks → **Send SMS hook** → HTTPS,
   URL `https://<ref>.supabase.co/functions/v1/auth-sms-hook`. Generate the
   secret there and set it: `supabase secrets set SEND_SMS_HOOK_SECRET='v1,whsec_...'`.
4. Authentication → Sign In / Providers: keep **Phone** and **Google** on
   (Google setup: `docs/google-oauth-login-setup.md`);
   turn **Email** sign-ups off. URL Configuration must list
   `safeshift://login-callback` as a redirect URL.

The phone number and code are never logged.
