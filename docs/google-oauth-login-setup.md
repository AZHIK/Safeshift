# Google Sign-In Setup (Customer and Driver apps)

Both apps sign in with **phone OTP** or **Google**. Google uses the **native
account picker**, so no browser opens:

- **Android:** Credential Manager bottom sheet listing the Google accounts on
  the device.
- **iOS:** Google's sign-in sheet over the app.

The app gets a Google **ID token** and exchanges it with Supabase
(`signInWithIdToken`). A random nonce is generated once per app run; its
SHA-256 goes into the Google request and the raw value goes to Supabase, which
checks that they match.

If the client IDs are **not** configured for a build, the app falls back to
Supabase OAuth in an **in-app browser tab** (Custom Tab / Safari sheet) that
returns through `safeshift://login-callback`. Builds keep working while you
set this up.

Code: `apps/*/lib/features/auth/data/auth_service.dart` (`signInWithGoogle`),
button: `packages/shared-flutter/lib/src/auth/google_sign_in_button.dart`.

---

## 1. Google Cloud Console

Use one Google Cloud project. Configure the **OAuth consent screen** first
(app name SafeShift, support email, logo, privacy policy URL; scopes `openid`,
`email`, `profile`; publish to production when ready).

Create these OAuth client IDs under **APIs & Services → Credentials**:

| Client type | Used for | Values |
| --- | --- | --- |
| **Web application** | Supabase verifies tokens against it; Android/iOS request tokens for it | Authorized redirect URI: `https://<project-ref>.supabase.co/auth/v1/callback` |
| **Android** (customer) | Credential Manager on Android | Package `com.safeshift.safeshift_customer` + SHA-1 |
| **Android** (driver) | Credential Manager on Android | Package `com.safeshift.safeshift_driver` + SHA-1 |
| **iOS** (customer) | Google sheet on iOS | Bundle ID of the customer app |
| **iOS** (driver) | Google sheet on iOS | Bundle ID of the driver app |

Android needs a client **for every signing key**: your debug keystore, your
upload key, and the **Google Play app signing key** (Play Console → Setup →
App signing). Get a local SHA-1 with:

```bash
cd apps/customer-mobile/android && ./gradlew signingReport
```

A missing or wrong SHA-1 is the most common cause of a
`clientConfigurationError` / "Developer console is not set up correctly".

## 2. Supabase dashboard

**Authentication → Sign In / Providers → Google**

- Enable Google.
- **Client ID:** the **Web** client ID first, then the Android and iOS client
  IDs, comma-separated. Supabase only accepts ID tokens whose audience is in
  this list.
- **Client Secret:** the Web client's secret (used by the browser fallback).
- Leave **Skip nonce checks** off. The app sends a nonce.

**Authentication → URL Configuration**

- Add `safeshift://login-callback` to the redirect URLs (browser fallback).

## 3. App configuration

Add the client IDs to the client-safe section of
`supabase/functions/.env.local`, then run `scripts/sync-dart-defines.sh`:

```bash
GOOGLE_WEB_CLIENT_ID=1234-web.apps.googleusercontent.com
GOOGLE_IOS_CLIENT_ID=1234-ios-customer.apps.googleusercontent.com
```

These are public identifiers, not secrets. They reach the apps as
`--dart-define`s. The customer and driver apps have **different iOS client
IDs**; when building the driver app for iOS, pass its own
`--dart-define=GOOGLE_IOS_CLIENT_ID=...`.

**iOS only:** copy `ios/Flutter/Secrets.xcconfig.example` to
`ios/Flutter/Secrets.xcconfig` in each app (git-ignored) and set the
**reversed** iOS client ID, which is registered as a URL scheme in
`Info.plist`:

```
GOOGLE_REVERSED_CLIENT_ID = com.googleusercontent.apps.1234-ios-customer
```

Android needs no manifest changes.

## 4. Behaviour

| Situation | Result |
| --- | --- |
| User picks an account | Signed in; profile is created on first sign-in. |
| User closes the picker | Nothing happens; no error is shown. |
| No Google account / UI unavailable | Message suggesting phone sign-in. |
| Client IDs not configured | In-app browser OAuth fallback. |
| Sign out | Also signs out of Google so the picker shows next time. |

## 5. Test checklist

- [ ] Android debug build: picker shows device accounts, sign-in succeeds.
- [ ] Android release build from Play (internal testing): sign-in succeeds
      (verifies the Play signing SHA-1).
- [ ] iOS: Google sheet appears and returns to the app.
- [ ] Closing the picker leaves the login screen idle.
- [ ] New Google user gets a `profiles` row with the right role.
- [ ] Sign out, then Google again: the account picker appears.
