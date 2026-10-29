import 'user.dart';

enum AuthStatus { unauthenticated, authenticating, authenticated, error }

/// Auth UI state shared by the login, OTP, and guarded screens.
class AuthState {
  const AuthState({
    this.status = AuthStatus.unauthenticated,
    this.phoneNumber,
    this.currentUser,
    this.isLoading = false,
    this.failureMessage,
    this.driverRegistered,
    this.isInitialized = false,
  });

  final AuthStatus status;

  /// Raw digits entered by the user, without the +255 prefix.
  final String? phoneNumber;

  final User? currentUser;

  final bool isLoading;

  /// User-safe failure message. Raw errors are never stored here.
  final String? failureMessage;

  /// Driver app only: whether the authenticated profile has a drivers row.
  final bool? driverRegistered;

  /// False until session recovery and the first auth event have completed.
  /// The router does not redirect while this is false.
  final bool isInitialized;

  bool get isAuthenticated =>
      status == AuthStatus.authenticated && currentUser != null;

  bool get isUnauthenticated => status == AuthStatus.unauthenticated;

  AuthState copyWith({
    AuthStatus? status,
    String? phoneNumber,
    User? currentUser,
    bool? isLoading,
    String? failureMessage,
    bool? driverRegistered,
    bool? isInitialized,
    bool clearUser = false,
    bool clearPhone = false,
    bool clearFailure = false,
  }) {
    return AuthState(
      status: status ?? this.status,
      phoneNumber: clearPhone ? null : (phoneNumber ?? this.phoneNumber),
      currentUser: clearUser ? null : (currentUser ?? this.currentUser),
      isLoading: isLoading ?? this.isLoading,
      failureMessage:
          clearFailure ? null : (failureMessage ?? this.failureMessage),
      driverRegistered: driverRegistered ?? this.driverRegistered,
      isInitialized: isInitialized ?? this.isInitialized,
    );
  }
}
