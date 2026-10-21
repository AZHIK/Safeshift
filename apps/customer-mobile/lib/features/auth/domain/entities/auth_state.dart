// Planned: persist the session (secure storage) and add token/expiry fields in
// a
// later sprint. Mock flow only — no backend involved.
import 'user.dart';

/// Local auth UI state for the mock login/OTP flow.
class AuthState {
  const AuthState({
    this.phoneNumber,
    this.currentUser,
    this.isLoading = false,
    this.failureMessage,
  });

  /// Raw digits entered by the user, without the +255 prefix.
  final String? phoneNumber;

  /// Set to the mock user once a valid OTP is verified.
  final User? currentUser;

  /// True while a mock network delay is in flight.
  final bool isLoading;

  /// Last failure message, null unless an action failed.
  final String? failureMessage;

  bool get isAuthenticated => currentUser != null;

  AuthState copyWith({
    String? phoneNumber,
    User? currentUser,
    bool? isLoading,
    String? failureMessage,
    bool clearUser = false,
    bool clearPhone = false,
    bool clearFailure = false,
  }) {
    return AuthState(
      phoneNumber: clearPhone ? null : (phoneNumber ?? this.phoneNumber),
      currentUser: clearUser ? null : (currentUser ?? this.currentUser),
      isLoading: isLoading ?? this.isLoading,
      failureMessage:
          clearFailure ? null : (failureMessage ?? this.failureMessage),
    );
  }
}
