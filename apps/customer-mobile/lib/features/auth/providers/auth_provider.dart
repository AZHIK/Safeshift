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
    unawaited(_restoreSession());
    return const AuthState();
  }

  Future<void> _restoreSession() async {
    final session = _service.client.auth.currentSession;
    if (session == null) {
      state = state.copyWith(isInitialized: true);
      return;
    }
    await _loadProfile(showLoading: false);
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
