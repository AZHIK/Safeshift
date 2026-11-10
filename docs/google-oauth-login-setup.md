# Google Login (OAuth) Setup for SafeShift Mobile Apps

This guide explains how to set up **“Sign in with Google”** for the SafeShift **Flutter mobile apps** using **Google Cloud OAuth** + **Supabase Auth** (hosted on **Supabase.com**).

> **Scope:** `safeshift/apps/customer-mobile` and `safeshift/apps/driver-mobile` (Flutter, `supabase_flutter ^2.18.3`, `app_links`). The Next.js web apps are out of scope for this doc.

## Current state in this repo (important)

- **`customer-mobile`** already has a placeholder Google OAuth call in `lib/features/auth/data/auth_service.dart`:
  - `signInWithOAuth(OAuthProvider.google)` is called, then it throws `AuthFailure('Google sign-in initiated...')` and relies on auth state changes.
  - It does **not** pass a mobile `redirectTo` deep link.
  - The login UI (`lib/features/auth/presentation/screens/login_screen.dart`) currently offers phone/email OTP only — no Google button.
- **`driver-mobile`** has phone OTP auth only (`lib/features/auth/data/auth_service.dart`, login screen) — no Google OAuth method/UI yet.
- **Both apps** initialize Supabase with `detectSessionInUri: false` in `lib/core/network/supabase_init.dart` and note: *“OTP-only auth. Deep links are owned by DeepLinkHandler, not the SDK.”*
- **Both apps** use the `safeshift://` custom scheme (Android `AndroidManifest.xml`, iOS `Info.plist` `CFBundleURLSchemes`) and have a `DeepLinkService` (`lib/core/deep_links/deep_link_service.dart`) that routes only `tracking/jobs/history` links. **OAuth callback links are not handled yet.**
- **Backend (hosted Supabase.com):** Auth/RLS/profile logic applies (`profiles`, `ensure_my_profile`, driver registration/verification checks in `driver-mobile`).

Because `detectSessionInUri` is disabled, you must **handle the OAuth redirect deep link yourself** and pass the URI to Supabase (typically `getSessionFromUrl`) so the session is stored.

---

## 1) Google Cloud Console — OAuth setup

Supabase’s Google provider uses a **Web application** OAuth client (Supabase handles the browser/OAuth exchange; your mobile app receives the final redirect).

1. Go to [Google Cloud Console](https://console.cloud.google.com/) → create/select a project.
2. **APIs & Services → OAuth consent screen**
   - User type: **External** (or **Internal** for Workspace-only).
   - Configure app name, support email, developer contact.
   - Scopes: `openid`, `.../auth/userinfo.email`, `.../auth/userinfo.profile` (usually default).
   - While in **Testing**, add test Google accounts.
3. **APIs & Services → Credentials → Create Credentials → OAuth client ID**
   - Application type: **Web application**.
   - **Authorized redirect URIs** — add your **Supabase Auth callback** (required):
     - `https://<PROJECT_REF>.supabase.co/auth/v1/callback`
     - Find `<PROJECT_REF>` in your Supabase project URL/settings.
   - Save and copy the **Client ID** and **Client Secret**.

> Notes:
> - Do **not** put your app’s `safeshift://...` deep link as the *Google* redirect URI. Google redirects to **Supabase**; Supabase redirects to your app’s `redirectTo`.
> - Android/iOS OAuth client IDs are only needed if you implement *native* Google Sign-In SDK flows. This guide uses Supabase’s OAuth browser flow (`signInWithOAuth` + deep link return), which works well with the hosted Supabase.com provider.

---

## 2) Supabase.com Dashboard configuration (hosted)

1. Open [Supabase Dashboard](https://supabase.com/dashboard) → your project.
2. **Authentication → Providers → Google**
   - Enable Google.
   - Paste **Client ID** and **Client Secret**.
   - Save.
3. **Authentication → URL Configuration**
   - **Site URL**: set to a valid app/site URL for your project (used as a fallback; mobile flows rely on explicit `redirectTo` allowlisting).
   - **Redirect URLs** (allowlist): add the **exact** mobile deep link(s) your app will use as `redirectTo`, for example:
     - `safeshift://login-callback` (recommended — see Section 4)
   - If you test multiple environments/schemes, add each one explicitly.
   - Save.

If the redirect URL is not allowlisted, Supabase will block the redirect after Google sign-in.

---

## 3) Mobile app environment variables

Both apps load config via `--dart-define` (see `.env.example` / `EnvConfig` usage). Use your hosted Supabase.com values:

```env
SUPABASE_URL=https://<PROJECT_REF>.supabase.co
SUPABASE_ANON_KEY=<your-project-anon-key>
```

Example run (adjust to your app/scripts):

```bash
flutter run \
  --dart-define=SUPABASE_URL=https://<PROJECT_REF>.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=<your-anon-key>
```

> Never commit real keys/secrets. Keep local values in uncommitted env tooling if your workflow uses it.

---

## 4) Choose and register a mobile auth callback deep link

This repo already registers the `safeshift://` scheme:
- **Customer Android:** `apps/customer-mobile/android/app/src/main/AndroidManifest.xml` (`<data android:scheme="safeshift"/>`)
- **Customer iOS:** `apps/customer-mobile/ios/Runner/Info.plist` (`CFBundleURLSchemes` includes `safeshift`)
- **Driver Android:** `apps/driver-mobile/android/app/src/main/AndroidManifest.xml` (same scheme)

**Recommended `redirectTo`:** `safeshift://login-callback`

Why:
- Fits the existing custom scheme.
- Easy to detect in `DeepLinkService` without conflicting with `tracking/jobs/history`.

You must:
1. Add `safeshift://login-callback` to **Supabase Dashboard → Authentication → URL Configuration → Redirect URLs**.
2. Handle it in the app (Section 5) and pass the same value as `redirectTo` in `signInWithOAuth` (Section 6).

> **Caution:** Both `customer-mobile` and `driver-mobile` currently use the same `safeshift://` scheme. On a device with both installed, the OS may show an app chooser or route unpredictably for custom-scheme links. Consider app-specific schemes in a follow-up (e.g., `safeshift-customer://`, `safeshift-driver://`) and register each in Supabase. For now, test with only the target app installed or verify routing carefully.

---

## 5) Handle the OAuth callback deep link (required with `detectSessionInUri: false`)

Both apps set `detectSessionInUri: false` (`lib/core/network/supabase_init.dart`) and delegate deep links to `DeepLinkService`. OAuth returns a URL containing auth data (PKCE `code` and/or tokens depending on flow). You need to process it **before** normal route handling.

### 5.1 Update `DeepLinkService` (both apps)

File: `lib/core/deep_links/deep_link_service.dart` (customer + driver; implementations are similar).

Add Supabase import and handle the auth callback URI:

```dart
import 'package:supabase_flutter/supabase_flutter.dart';
```

In `_handle(Uri uri)`, detect and process auth callbacks first:

```dart
void _handle(Uri uri) async {
  final router = _router;
  if (router == null) return;

  // OAuth callback (e.g., safeshift://login-callback?code=...)
  if (_isAuthCallback(uri)) {
    try {
      await Supabase.instance.client.auth.getSessionFromUrl(uri);
      // Session is stored; onAuthStateChange/router guards should take over.
      // Optionally navigate to a post-login route if needed.
    } catch (error) {
      debugPrint('OAuth callback handling failed: $error');
    }
    return;
  }

  final location = deepLinkLocation(uri);
  if (location == null) {
    debugPrint('Unhandled deep link: $uri');
    return;
  }
  router.go(location);
}

bool _isAuthCallback(Uri uri) {
  // Match the redirectTo you configure, e.g. safeshift://login-callback
  if (uri.scheme == 'safeshift' && uri.host == 'login-callback') return true;
  // Defensive: some flows may include auth params in fragment/query.
  if (uri.queryParameters.containsKey('code') ||
      uri.queryParameters.containsKey('error') ||
      uri.fragment.contains('access_token=')) {
    return true;
  }
  return false;
}
```

Adjust the matcher to exactly match your chosen `redirectTo`.

### 5.2 Alternative: enable SDK session detection (use with care)

You *could* set `detectSessionInUri: true` in `supabase_init.dart`, but this repo explicitly disabled it because deep links are owned by the app. If you enable it, verify it doesn’t interfere with existing `safeshift://tracking/...` links and `DeepLinkService` behavior. The explicit `getSessionFromUrl` approach keeps control clear.

---

## 6) Implement Google sign-in in `AuthService`

### 6.1 Customer app (`apps/customer-mobile/lib/features/auth/data/auth_service.dart`)

Replace the placeholder method with a real OAuth initiation that uses `redirectTo` and does not throw on success:

```dart
Future<void> signInWithGoogle() async {
  await _client.auth.signInWithOAuth(
    OAuthProvider.google,
    redirectTo: 'safeshift://login-callback',
    authScreenLaunchMode: LaunchMode.externalApplication,
  );
  // Browser opens; on return, DeepLinkService handles the callback and
  // getSessionFromUrl() stores the session. Listen to onAuthStateChange /
  // router/auth provider to react to SIGNED_IN.
}
```

Then, on `SIGNED_IN`/session restore, run your existing profile bootstrap/fetch flow (this file already has `_ensureProfile(...)` and `fetchUserProfile(...)`). Make sure the auth provider/UI listens to `onAuthStateChange` and navigates appropriately (same pattern as OTP flows).

### 6.2 Driver app (`apps/driver-mobile/lib/features/auth/data/auth_service.dart`)

Add the same `signInWithGoogle()` method (driver-mobile currently has no OAuth method). After sign-in, preserve driver-specific checks used by the app:

- `fetchUserProfile()` / `profiles` sync
- `fetchDriverRegistration()` / `hasDriverProfile()` — unregistered users are routed through onboarding; `verification_status == 'verified'` gates going online (`DriverRegistrationStatus.isVerified`).

Call `_ensureProfile(...)` as appropriate for new Google users (role defaults to `driver` via `appRole`).

> **API note:** `supabase_flutter` v2 APIs can vary slightly across minor versions. Confirm the exact `signInWithOAuth` signature/options for `^2.18.3` if your analyzer reports issues (e.g., parameter names or launch mode enum).

---

## 7) Add a Google button to the login UI

### Customer app
File: `apps/customer-mobile/lib/features/auth/presentation/screens/login_screen.dart`
- Add a “Continue with Google” button (e.g., below the OTP action/terms).
- Call `ref.read(authProvider.notifier).signInWithGoogle()` (or your provider’s equivalent) and show errors via `AppSnackbar` on `Failure`.
- While the browser flow is in progress, handle loading/state carefully (OAuth opens an external browser; completion arrives via deep link + auth state change).

### Driver app
File: `apps/driver-mobile/lib/features/auth/presentation/screens/login_screen.dart`
- Add the same button and wire it to the driver auth provider/service.
- Ensure post-login routing respects driver registration/verification (existing router logic).

Keep UI consistent with `AppColors`, `TextStyles`, and existing button components.

---

## 8) Supabase.com + mobile provisioning gotchas

- **Profiles/roles:** Google sign-in creates/authenticates a Supabase Auth user. Your app may require a `profiles` row and correct role/driver records. `customer-mobile` and `driver-mobile` call `ensure_my_profile` RPC — verify this RPC exists and behaves correctly for OAuth users in your hosted DB.
- **Driver app:** A valid Google session is not enough to drive; the user may still need a `drivers` row and `verification_status='verified'` (`fetchDriverRegistration` / go-online gate).
- **Email conflicts/linking:** If a user previously signed up with phone/email and later uses Google with the same email, behavior depends on Supabase Auth settings/identities. Test account linking/conflict scenarios in the Dashboard.
- **Redirect allowlist:** Every `redirectTo` used in code must be present in **Authentication → URL Configuration → Redirect URLs**.
- **Same custom scheme on two apps:** can misroute callbacks if both apps are installed — prefer unique schemes per app when feasible.

---

## 9) Test checklist (hosted Supabase.com)

1. **Google Console:** Authorized redirect URI = `https://<PROJECT_REF>.supabase.co/auth/v1/callback`.
2. **Supabase Dashboard:**
   - Google provider enabled with correct client ID/secret.
   - Redirect URLs include `safeshift://login-callback` (or your chosen value).
3. **App config:** `SUPABASE_URL`/`SUPABASE_ANON_KEY` point to the hosted project.
4. **Deep link handling:** `DeepLinkService` processes the auth callback and calls `getSessionFromUrl`.
5. **Run app** → tap **Continue with Google** → complete Google sign-in in browser → app receives deep link → session is established → user is routed correctly.
6. **Driver-specific:** verify behavior for users with no `drivers` row and for unverified/verified drivers.
7. **Negative tests:** cancel browser flow, use a Google account that should not access the app context, and confirm safe error handling.

---

## Files to change (summary)

| Area | File(s) |
|---|---|
| Supabase init (review only; `detectSessionInUri` remains `false`) | `apps/customer-mobile/lib/core/network/supabase_init.dart`, `apps/driver-mobile/lib/core/network/supabase_init.dart` |
| OAuth deep link handling | `apps/customer-mobile/lib/core/deep_links/deep_link_service.dart`, `apps/driver-mobile/lib/core/deep_links/deep_link_service.dart` |
| Auth service | `apps/customer-mobile/lib/features/auth/data/auth_service.dart`, `apps/driver-mobile/lib/features/auth/data/auth_service.dart` |
| Login UI | `apps/customer-mobile/lib/features/auth/presentation/screens/login_screen.dart`, `apps/driver-mobile/lib/features/auth/presentation/screens/login_screen.dart` |
| Auth state/providers | `apps/*/lib/features/auth/providers/*` (wire method + react to session/auth state as needed) |
| Platform deep links (already present for `safeshift://`) | Android `AndroidManifest.xml`, iOS `Info.plist` for each app |

---

## Quick checklist

- [ ] Hosted Supabase.com project configured (not self-hosted on your domain).
- [ ] Google **Web** OAuth client created; redirect URI = `https://<PROJECT_REF>.supabase.co/auth/v1/callback`.
- [ ] Supabase Dashboard: Google provider enabled + mobile `redirectTo` allowlisted (e.g., `safeshift://login-callback`).
- [ ] Mobile `redirectTo` matches `DeepLinkService` auth-callback handling.
- [ ] `signInWithOAuth` passes `redirectTo` and uses external browser launch (as supported by your `supabase_flutter` version).
- [ ] Deep link callback calls `Supabase.instance.client.auth.getSessionFromUrl(uri)`.
- [ ] Post-login profile bootstrap (`ensure_my_profile`) and driver registration/verification flows verified.
- [ ] Tested on Android/iOS with hosted Supabase.com; considered unique schemes if both apps are installed.
