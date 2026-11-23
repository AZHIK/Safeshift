import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;

import '../../../core/config/env_config.dart';
import '../../../core/errors/failures.dart';
import '../domain/entities/user.dart';

/// Result of [AuthService.signInWithGoogle].
enum GoogleSignInOutcome {
  /// Native sign-in finished; a Supabase session now exists.
  signedIn,

  /// The in-app browser opened; the session arrives via the deep link.
  openedBrowser,

  /// The user closed the account picker.
  canceled,
}

/// Registration + trust state used by the router and the go-online gate.
class DriverRegistrationStatus {
  const DriverRegistrationStatus({
    required this.registered,
    this.verificationStatus,
  });

  const DriverRegistrationStatus.unregistered()
    : registered = false,
      verificationStatus = null;

  final bool registered;
  final String? verificationStatus;

  bool get isVerified => registered && verificationStatus == 'verified';
}

/// Thin, testable wrapper around Supabase Auth and the profile bootstrap.
class AuthService {
  AuthService(this._client, {this.appRole = 'driver'});

  final SupabaseClient _client;
  final String appRole;

  SupabaseClient get client => _client;

  /// Normalizes a Tanzanian number to E.164. Accepts `0712345678`,
  /// `712345678`, `255712345678`, or `+255712345678`.
  static String normalizePhone(String raw) {
    final trimmed = raw.trim();
    if (trimmed.startsWith('+')) {
      return '+${trimmed.substring(1).replaceAll(RegExp(r'\D'), '')}';
    }
    var digits = trimmed.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('255')) return '+$digits';
    if (digits.startsWith('0')) digits = digits.substring(1);
    return '+255$digits';
  }

  Future<void> sendOtp(String phone) async {
    final normalized = normalizePhone(phone);
    if (normalized.length != 13) {
      throw const ValidationFailure('Enter a valid 9-digit phone number');
    }
    await _client.auth.signInWithOtp(phone: normalized, shouldCreateUser: true);
  }

  Future<User> verifyOtp(String phone, String otp) async {
    final code = otp.replaceAll(RegExp(r'\D'), '');
    if (!RegExp(r'^\d{6}$').hasMatch(code)) {
      throw const ValidationFailure('Enter the 6-digit code');
    }

    final response = await _client.auth.verifyOTP(
      phone: normalizePhone(phone),
      token: code,
      type: OtpType.sms,
    );

    final authUser = response.user;
    if (authUser == null) {
      throw const AuthFailure('Sign-in failed. Please request a new code.');
    }

    await ensureProfile(authUser.userMetadata?['full_name'] as String?);
    final profile = await fetchUserProfile(userId: authUser.id);
    if (profile == null) {
      throw const AuthFailure(
        'Your account was created but the profile is still syncing. Try again.',
      );
    }
    return profile;
  }

  /// Signs in with Google.
  ///
  /// Uses the native account picker (Android Credential Manager bottom sheet,
  /// iOS Google sheet) and exchanges the Google ID token with Supabase, so no
  /// browser opens. When the client IDs are not configured for this build it
  /// falls back to OAuth in an in-app browser tab, which returns through
  /// `safeshift://login-callback`.
  Future<GoogleSignInOutcome> signInWithGoogle() async {
    if (!_nativeGoogleConfigured) {
      await _client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: kIsWeb ? null : 'safeshift://login-callback',
        authScreenLaunchMode: LaunchMode.inAppBrowserView,
      );
      return GoogleSignInOutcome.openedBrowser;
    }

    final google = GoogleSignIn.instance;
    await _initGoogle(google);
    final GoogleSignInAccount account;
    try {
      account = await google.authenticate();
    } on GoogleSignInException catch (error) {
      switch (error.code) {
        case GoogleSignInExceptionCode.canceled:
        case GoogleSignInExceptionCode.interrupted:
          return GoogleSignInOutcome.canceled;
        case GoogleSignInExceptionCode.uiUnavailable:
          throw const AuthFailure(
            'Google sign-in is not available right now. Use your phone number.',
          );
        default:
          throw const AuthFailure(
            'Google sign-in failed. Please try again or use your phone number.',
          );
      }
    }

    final idToken = account.authentication.idToken;
    if (idToken == null) {
      throw const AuthFailure('Google did not return a sign-in token.');
    }
    await _client.auth.signInWithIdToken(
      provider: OAuthProvider.google,
      idToken: idToken,
      nonce: _googleRawNonce,
    );
    return GoogleSignInOutcome.signedIn;
  }

  static bool get _nativeGoogleConfigured {
    if (kIsWeb || EnvConfig.googleWebClientId.isEmpty) return false;
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => true,
      TargetPlatform.iOS => EnvConfig.googleIosClientId.isNotEmpty,
      _ => false,
    };
  }

  // GoogleSignIn.initialize may run only once per process, so the nonce is
  // generated once per app run. Google embeds its SHA-256 in the ID token and
  // Supabase checks it against the raw value, which never leaves this device
  // except in the token exchange.
  static final String _googleRawNonce = _randomNonce();
  static Future<void>? _googleInit;

  static Future<void> _initGoogle(GoogleSignIn google) {
    return _googleInit ??= google
        .initialize(
          clientId: defaultTargetPlatform == TargetPlatform.iOS
              ? EnvConfig.googleIosClientId
              : null,
          serverClientId: EnvConfig.googleWebClientId,
          nonce: sha256.convert(utf8.encode(_googleRawNonce)).toString(),
        )
        .catchError((Object error) {
          _googleInit = null;
          throw error;
        });
  }

  static String _randomNonce([int length = 32]) {
    const charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(
      length,
      (_) => charset[random.nextInt(charset.length)],
    ).join();
  }

  Future<void> signOut() async {
    if (_googleInit != null) {
      try {
        // Next Google sign-in shows the account picker instead of silently
        // reusing the previous account.
        await GoogleSignIn.instance.signOut();
      } catch (_) {
        // Never block sign-out on Google cleanup.
      }
    }
    await _client.auth.signOut();
  }

  User? currentUser() {
    final authUser = _client.auth.currentUser;
    if (authUser == null) return null;
    return User(
      id: authUser.id,
      phone: authUser.phone ?? '',
      fullName: (authUser.userMetadata?['full_name'] as String?) ?? '',
      role: appRole,
      email: authUser.email ?? '',
    );
  }

  Stream<AuthState> get onAuthStateChange => _client.auth.onAuthStateChange;

  Future<User?> fetchUserProfile({String? userId}) async {
    final id = userId ?? _client.auth.currentUser?.id;
    if (id == null) return null;

    final row = await _client
        .from('profiles')
        .select(
          'id, full_name, display_name, phone, email, primary_role, is_active',
        )
        .eq('id', id)
        .maybeSingle();

    if (row == null) return null;
    if (row['is_active'] == false) {
      throw const AuthFailure('This account has been deactivated.');
    }

    final role = (row['primary_role'] as String?) ?? appRole;
    return User(
      id: row['id'] as String,
      phone: (row['phone'] as String?) ?? '',
      fullName: (row['full_name'] as String?)?.trim().isNotEmpty == true
          ? row['full_name'] as String
          : ((row['display_name'] as String?) ?? ''),
      role: role,
      email: (row['email'] as String?) ?? '',
    );
  }

  /// Returns true when the authenticated profile has a drivers row.
  Future<bool> hasDriverProfile({String? userId}) async {
    return (await fetchDriverRegistration(userId: userId)).registered;
  }

  /// Loads the drivers row registration and verification status.
  ///
  /// A missing row is not an error: the router sends those users through
  /// guided onboarding. `verificationStatus` is only meaningful when
  /// [DriverRegistrationStatus.registered] is true.
  Future<DriverRegistrationStatus> fetchDriverRegistration({
    String? userId,
  }) async {
    final id = userId ?? _client.auth.currentUser?.id;
    if (id == null) return const DriverRegistrationStatus.unregistered();
    final row = await _client
        .from('drivers')
        .select('id, verification_status')
        .eq('id', id)
        .maybeSingle();
    if (row == null) return const DriverRegistrationStatus.unregistered();
    return DriverRegistrationStatus(
      registered: true,
      verificationStatus: row['verification_status'] as String?,
    );
  }

  /// Creates or completes the profile for any authenticated sign-in method.
  Future<void> ensureProfile(String? fullName) async {
    try {
      await _client.rpc(
        'ensure_my_profile',
        params: <String, dynamic>{'p_role': appRole, 'p_full_name': fullName},
      );
    } on PostgrestException catch (error) {
      // The auth trigger normally creates the row. A missing RPC in an older
      // environment must not block a valid login; the profile fetch below is
      // the source of truth.
      if (error.code != 'PGRST202' && error.code != '42883') rethrow;
    }
  }
}
