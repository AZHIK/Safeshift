// TODO: replace the mock delays with real Supabase OTP APIs and persist the
// session in a later sprint. Mock logic only — no backend calls.
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/errors/failures.dart';
import '../../../shared/mock/mock_users.dart';
import '../domain/entities/auth_state.dart';
import '../domain/entities/user.dart';

part 'auth_provider.g.dart';

/// Mock auth state. Simulates OTP send/verify with local delays only.
@riverpod
class AuthNotifier extends _$AuthNotifier {
  @override
  AuthState build() {
    // Auth session must survive moments with zero listeners (e.g. during
    // route transitions to screens that don't watch auth state).
    ref.keepAlive();
    return const AuthState();
  }

  /// Simulates sending an OTP. Stores the phone number after a 1-second delay.
  /// Throws [ValidationFailure] when the number is not exactly 9 digits.
  Future<void> sendOtp(String phoneNumber) async {
    final digits = phoneNumber.replaceAll(RegExp(r'\D'), '');
    state = state.copyWith(isLoading: true, clearFailure: true);
    await Future<void>.delayed(const Duration(seconds: 1));
    if (digits.length != 9) {
      const message = 'Enter a valid 9-digit phone number';
      state = state.copyWith(isLoading: false, failureMessage: message);
      throw const ValidationFailure(message);
    }
    state = state.copyWith(
      isLoading: false,
      phoneNumber: digits,
      clearFailure: true,
    );
  }

  /// Simulates verifying an OTP. Any 6-digit code (including 123456) logs the
  /// user in as the mock driver. Throws [ValidationFailure] otherwise.
  Future<void> verifyOtp(String code) async {
    final digits = code.replaceAll(RegExp(r'\D'), '');
    state = state.copyWith(isLoading: true, clearFailure: true);
    await Future<void>.delayed(const Duration(seconds: 1));
    if (!RegExp(r'^\d{6}$').hasMatch(digits)) {
      const message = 'Invalid code';
      state = state.copyWith(isLoading: false, failureMessage: message);
      throw const ValidationFailure(message);
    }
    state = state.copyWith(
      isLoading: false,
      currentUser: User(
        id: mockUser.id,
        phone: mockUser.phone,
        fullName: mockUser.fullName,
        role: 'driver',
      ),
      clearFailure: true,
    );
  }

  /// Clears the current user and phone number.
  void signOut() {
    state = state.copyWith(clearUser: true, clearPhone: true);
  }

  /// Returns the notifier to its initial state.
  void reset() {
    state = const AuthState();
  }
}
