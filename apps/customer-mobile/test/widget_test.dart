import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safeshift_customer/features/auth/domain/entities/auth_state.dart';
import 'package:safeshift_customer/features/auth/presentation/screens/login_screen.dart';
import 'package:safeshift_customer/features/auth/providers/auth_provider.dart';

class _FakeAuthNotifier extends AuthNotifier {
  _FakeAuthNotifier() : super(appRole: 'customer');

  @override
  AuthState build() => const AuthState(isInitialized: true);
}

void main() {
  testWidgets('LoginScreen renders the phone entry flow', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [authProvider.overrideWith(_FakeAuthNotifier.new)],
        child: const MaterialApp(home: LoginScreen()),
      ),
    );

    expect(find.text('safeshift'), findsOneWidget);
    expect(find.text('Enter your phone number'), findsOneWidget);
    expect(find.text('Send OTP'), findsOneWidget);
  });
}
