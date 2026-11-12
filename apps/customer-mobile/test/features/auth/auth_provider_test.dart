import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:safeshift_customer/core/network/supabase_client.dart';
import 'package:safeshift_customer/features/auth/providers/auth_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supa;

class _MockSupabaseClient extends Mock implements supa.SupabaseClient {}

class _MockGoTrueClient extends Mock implements supa.GoTrueClient {}

void main() {
  ProviderContainer buildContainer(supa.GoTrueClient auth) {
    final client = _MockSupabaseClient();
    when(() => client.auth).thenReturn(auth);
    final container = ProviderContainer(
      overrides: [supabaseProvider.overrideWithValue(client)],
    );
    addTearDown(container.dispose);
    return container;
  }

  void stubSignedOut(supa.GoTrueClient auth) {
    when(() => auth.currentSession).thenReturn(null);
    when(() => auth.onAuthStateChange).thenAnswer(
      (_) => const Stream<supa.AuthState>.empty(),
    );
  }

  group('AuthNotifier session restore', () {
    test('building the provider does not read state before it is initialised',
        () async {
      final auth = _MockGoTrueClient();
      stubSignedOut(auth);
      final container = buildContainer(auth);

      // Riverpod 3 throws "Tried to read the state of an uninitialized
      // provider" when `state` is read while build() is still running.
      expect(() => container.read(authProvider), returnsNormally);
    });

    test('a signed-out user still reaches isInitialized so the router works',
        () async {
      final auth = _MockGoTrueClient();
      stubSignedOut(auth);
      final container = buildContainer(auth);

      container.read(authProvider);
      await Future<void>.delayed(const Duration(milliseconds: 900));

      // Without this the auth guard never redirects and the app is stuck on
      // its initial route.
      expect(container.read(authProvider).isInitialized, isTrue);
    });

    test('an already-restored session is not treated as signed out', () async {
      final auth = _MockGoTrueClient();
      final session = supa.Session(
        accessToken: 'token',
        refreshToken: 'refresh',
        expiresIn: 3600,
        tokenType: 'bearer',
        user: supa.User(
          id: 'user-1',
          appMetadata: const <String, dynamic>{},
          userMetadata: const <String, dynamic>{},
          aud: 'authenticated',
          createdAt: DateTime.now().toUtc().toIso8601String(),
        ),
      );
      when(() => auth.currentSession).thenReturn(session);
      when(() => auth.onAuthStateChange).thenAnswer(
        (_) => const Stream<supa.AuthState>.empty(),
      );

      final container = buildContainer(auth);
      container.read(authProvider);
      await Future<void>.delayed(const Duration(milliseconds: 300));

      // The signed-in path is handled by the auth stream, not by the
      // restore fallback, so the provider must not be marked signed out here.
      expect(container.read(authProvider).isInitialized, isFalse);
    });
  });
}
