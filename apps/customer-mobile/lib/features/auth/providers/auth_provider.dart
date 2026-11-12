import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supa;

import '../../../core/cache/cache_service.dart';
import '../../../core/errors/error_handler.dart';
import '../../../core/errors/failures.dart';
import '../../../core/network/supabase_client.dart';
import '../../../core/notifications/push_service.dart';
import '../data/auth_service.dart';
import '../domain/entities/auth_state.dart';
import '../domain/entities/user.dart';

/// Real Supabase OTP auth for the customer app.
///
/// The notifier owns exactly one auth-state subscription and cancels it when
/// the provider is disposed. Profile rows are loaded after every signed-in
/// event, including session recovery and token refresh.
final authProvider = NotifierProvider<AuthNotifier, AuthState>(
  () => AuthNotifier(appRole: 'customer'),
);

class AuthNotifier extends Notifier<AuthState> {
  AuthNotifier({this.appRole = 'customer'});

  final String appRole;
  late final AuthService _service;
  StreamSubscription<supa.AuthState>? _authSubscription;

  @override
  AuthState build() {
    _service = AuthService(ref.watch(supabaseProvider), appRole: appRole);
    _authSubscription = _service.onAuthStateChange.listen(
      _onAuthEvent,
      onError: (Object error, StackTrace stack) {
        if (!ref.mounted) return;
        state = state.copyWith(
          status: AuthStatus.error,
          isLoading: false,
          failureMessage: ErrorHandler.map(error, stackTrace: stack).message,
        );
      },
    );
    ref.onDispose(() => _authSubscription?.cancel());
    // Riverpod 3 forbids reading `state` while the provider is still
    // building. Supabase.initialize() starts recoverSession() without
    // awaiting it, so currentSession is still null here and the restore
    // would write `state` synchronously inside build(), which throws
    // "Tried to read the state of an uninitialized provider" and leaves
    // isInitialized false forever, so the router never redirects.
    // Deferring to a microtask lets build() return first.
    scheduleMicrotask(() => unawaited(_restoreSession()));
    return const AuthState();
  }

  Future<void> _restoreSession() async {
    // Supabase.initialize() restores a stored session in the background, so
    // currentSession can still be null a moment after startup. Wait for the
    // restore to settle before declaring the user signed out, otherwise a
    // signed-in user is bounced to the login screen first.
    await _awaitSessionRestore();
    if (!ref.mounted) return;
    // A session that arrived in the meantime is handled by _onAuthEvent.
    if (_service.client.auth.currentSession != null) return;
    state = state.copyWith(isInitialized: true);
  }

  /// Waits for the first auth event, or a short grace period.
  Future<void> _awaitSessionRestore() async {
    if (_service.client.auth.currentSession != null) return;
    final completer = Completer<void>();
    final subscription = _service.onAuthStateChange.listen((_) {
      if (!completer.isCompleted) completer.complete();
    });
    try {
      await Future.any<void>([
        completer.future,
        Future<void>.delayed(const Duration(milliseconds: 500)),
      ]);
    } finally {
      await subscription.cancel();
    }
  }

  void _onAuthEvent(supa.AuthState event) {
    if (!ref.mounted) return;
    if (event.session == null) {
      state = const AuthState(isInitialized: true);
      return;
    }
    unawaited(_loadProfile(showLoading: false));
  }

  Future<void> sendOtp(String phoneNumber) async {
    state = state.copyWith(
      status: AuthStatus.authenticating,
      isLoading: true,
      clearFailure: true,
    );
    try {
      await _service.sendOtp(phoneNumber);
      if (!ref.mounted) return;
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        isLoading: false,
        phoneNumber: phoneNumber.replaceAll(RegExp(r'\D'), ''),
        clearFailure: true,
      );
    } catch (error, stack) {
      final failure = ErrorHandler.map(error, stackTrace: stack);
      if (!ref.mounted) return;
      state = state.copyWith(
        status: AuthStatus.error,
        isLoading: false,
        failureMessage: failure.message,
      );
      throw failure;
    }
  }

  Future<void> sendEmailOtp(String email) async {
    state = state.copyWith(
      status: AuthStatus.authenticating,
      isLoading: true,
      clearFailure: true,
    );
    try {
      await _service.sendEmailOtp(email);
      if (!ref.mounted) return;
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        isLoading: false,
        clearFailure: true,
      );
    } catch (error, stack) {
      final failure = ErrorHandler.map(error, stackTrace: stack);
      if (!ref.mounted) return;
      state = state.copyWith(
        status: AuthStatus.error,
        isLoading: false,
        failureMessage: failure.message,
      );
      throw failure;
    }
  }

  Future<User> verifyOtp(String code) async {
    final phone = state.phoneNumber;
    if (phone == null || phone.isEmpty) {
      const failure = AuthFailure('Request a new code first.');
      state = state.copyWith(
        status: AuthStatus.error,
        failureMessage: failure.message,
      );
      throw failure;
    }

    state = state.copyWith(
      status: AuthStatus.authenticating,
      isLoading: true,
      clearFailure: true,
    );
    try {
      final user = await _service.verifyOtp(phone, code);
      final driverRegistered = appRole == 'driver'
          ? await _service.hasDriverProfile(userId: user.id)
          : null;
      if (!ref.mounted) return user;
      state = AuthState(
        status: AuthStatus.authenticated,
        phoneNumber: phone,
        currentUser: user,
        driverRegistered: driverRegistered,
        isInitialized: true,
      );
      unawaited(
        ref
            .read(pushServiceProvider)
            .registerForUser(user.id, ref.read(supabaseProvider)),
      );
      return user;
    } catch (error, stack) {
      final failure = ErrorHandler.map(error, stackTrace: stack);
      if (!ref.mounted) throw failure;
      state = state.copyWith(
        status: AuthStatus.error,
        isLoading: false,
        failureMessage: failure.message,
      );
      throw failure;
    }
  }

  Future<User> verifyEmailOtp(String email, String code) async {
    state = state.copyWith(
      status: AuthStatus.authenticating,
      isLoading: true,
      clearFailure: true,
    );
    try {
      final user = await _service.verifyEmailOtp(email, code);
      final driverRegistered = appRole == 'driver'
          ? await _service.hasDriverProfile(userId: user.id)
          : null;
      if (!ref.mounted) return user;
      state = AuthState(
        status: AuthStatus.authenticated,
        currentUser: user,
        driverRegistered: driverRegistered,
        isInitialized: true,
      );
      unawaited(
        ref
            .read(pushServiceProvider)
            .registerForUser(user.id, ref.read(supabaseProvider)),
      );
      return user;
    } catch (error, stack) {
      final failure = ErrorHandler.map(error, stackTrace: stack);
      if (!ref.mounted) throw failure;
      state = state.copyWith(
        status: AuthStatus.error,
        isLoading: false,
        failureMessage: failure.message,
      );
      throw failure;
    }
  }

  Future<void> signInWithGoogle() async {
    state = state.copyWith(
      status: AuthStatus.authenticating,
      isLoading: true,
      clearFailure: true,
    );
    try {
      await _service.signInWithGoogle();
      // OAuth completes via browser redirect + deep link; the auth state
      // subscription (_onAuthEvent) will load the profile and update state.
      if (!ref.mounted) return;
      state = state.copyWith(isLoading: false);
    } catch (error, stack) {
      final failure = ErrorHandler.map(error, stackTrace: stack);
      if (!ref.mounted) return;
      state = state.copyWith(
        status: AuthStatus.error,
        isLoading: false,
        failureMessage: failure.message,
      );
      throw failure;
    }
  }

  Future<void> refreshProfile() => _loadProfile(showLoading: false);

  Future<void> _loadProfile({bool showLoading = true}) async {
    if (showLoading && ref.mounted) {
      state = state.copyWith(
        status: AuthStatus.authenticating,
        isLoading: true,
        clearFailure: true,
      );
    }
    try {
      final user = await _service.fetchUserProfile();
      if (user == null) {
        throw const AuthFailure('Your profile is still being created.');
      }
      final driverRegistered = appRole == 'driver'
          ? await _service.hasDriverProfile(userId: user.id)
          : null;
      if (!ref.mounted) return;
      state = AuthState(
        status: AuthStatus.authenticated,
        phoneNumber: user.phone.replaceFirst('+255', ''),
        currentUser: user,
        driverRegistered: driverRegistered,
        isInitialized: true,
      );
      unawaited(
        ref
            .read(pushServiceProvider)
            .registerForUser(user.id, ref.read(supabaseProvider)),
      );
    } catch (error, stack) {
      if (!ref.mounted) return;
      state = state.copyWith(
        status: AuthStatus.error,
        isLoading: false,
        failureMessage: ErrorHandler.map(error, stackTrace: stack).message,
        isInitialized: true,
      );
    }
  }

  Future<void> signOut() async {
    final userId = state.currentUser?.id;
    try {
      await _service.signOut();
    } catch (error, stack) {
      // A local sign-out still clears the UI even if the network call fails.
      ErrorHandler.map(error, stackTrace: stack);
    } finally {
      try {
        await ref.read(pushServiceProvider).unregister();
      } catch (_) {
        // Sign-out must not be blocked by push cleanup.
      }
      if (userId != null) {
        try {
          await ref.read(cacheServiceProvider).clearUser(userId);
        } catch (_) {
          // A cache failure must not keep the previous session visible.
        }
      }
      if (ref.mounted) state = const AuthState(isInitialized: true);
    }
  }

  void reset() {
    if (ref.mounted) state = const AuthState();
  }
}
