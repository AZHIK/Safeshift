import 'package:supabase_flutter/supabase_flutter.dart' hide User;

import '../../../core/errors/failures.dart';
import '../domain/entities/user.dart';

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
    await _client.auth.signInWithOtp(
      phone: normalized,
      shouldCreateUser: true,
    );
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

    await _ensureProfile(authUser.userMetadata?['full_name'] as String?);
    final profile = await fetchUserProfile(userId: authUser.id);
    if (profile == null) {
      throw const AuthFailure(
        'Your account was created but the profile is still syncing. Try again.',
      );
    }
    return profile;
  }

  Future<void> signOut() => _client.auth.signOut();

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
      fullName:
          (row['full_name'] as String?)?.trim().isNotEmpty == true
              ? row['full_name'] as String
              : ((row['display_name'] as String?) ?? ''),
      role: role,
      email: (row['email'] as String?) ?? '',
    );
  }

  /// Returns true when the authenticated profile has a drivers row.
  Future<bool> hasDriverProfile({String? userId}) async {
    final id = userId ?? _client.auth.currentUser?.id;
    if (id == null) return false;
    final row = await _client
        .from('drivers')
        .select('id')
        .eq('id', id)
        .maybeSingle();
    return row != null;
  }

  Future<void> _ensureProfile(String? fullName) async {
    try {
      await _client.rpc(
        'ensure_my_profile',
        params: <String, dynamic>{
          'p_role': appRole,
          'p_full_name': fullName,
        },
      );
    } on PostgrestException catch (error) {
      // The auth trigger normally creates the row. A missing RPC in an older
      // environment must not block a valid login; the profile fetch below is
      // the source of truth.
      if (error.code != 'PGRST202' && error.code != '42883') rethrow;
    }
  }
}
