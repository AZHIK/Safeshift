// TODO: add sign-out/session-restore tests once persistence lands.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safeshift_customer/core/errors/failures.dart';
import 'package:safeshift_customer/features/auth/providers/auth_provider.dart';

void main() {
  test('authProvider starts unauthenticated', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final state = container.read(authProvider);
    expect(state.currentUser, isNull);
    expect(state.phoneNumber, isNull);
    expect(state.isLoading, isFalse);
    expect(state.isAuthenticated, isFalse);
  });

  test('sendOtp stores a valid phone number', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await container.read(authProvider.notifier).sendOtp('712345678');
    expect(container.read(authProvider).phoneNumber, '712345678');
  });

  test('sendOtp rejects an invalid phone number', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await expectLater(
      container.read(authProvider.notifier).sendOtp('123'),
      throwsA(isA<ValidationFailure>()),
    );
  });

  test('verifyOtp accepts any 6-digit code as the mock user', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(authProvider.notifier);
    await notifier.sendOtp('712345678');
    await notifier.verifyOtp('482910');
    final state = container.read(authProvider);
    expect(state.isAuthenticated, isTrue);
    expect(state.currentUser?.fullName, 'Neema Juma');
  });

  test('verifyOtp rejects codes that are not 6 digits', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(authProvider.notifier);
    await notifier.sendOtp('712345678');
    await expectLater(
      notifier.verifyOtp('123'),
      throwsA(isA<ValidationFailure>()),
    );
    expect(container.read(authProvider).isAuthenticated, isFalse);
  });
}
