import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safeshift_customer/core/theme/app_theme.dart';
import 'package:safeshift_customer/features/auth/domain/entities/auth_state.dart';
import 'package:safeshift_customer/features/auth/presentation/screens/login_screen.dart';
import 'package:safeshift_customer/features/auth/presentation/widgets/phone_input_field.dart';
import 'package:safeshift_customer/features/auth/providers/auth_provider.dart';

class _FakeAuthNotifier extends AuthNotifier {
  _FakeAuthNotifier() : super(appRole: 'customer');

  @override
  AuthState build() => const AuthState(isInitialized: true);
}

void main() {
  testWidgets(
    'Phone entry follows system appearance and keeps the entered number',
    (tester) async {
      final dispatcher = tester.platformDispatcher;
      dispatcher.platformBrightnessTestValue = Brightness.light;
      addTearDown(dispatcher.clearPlatformBrightnessTestValue);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [authProvider.overrideWith(_FakeAuthNotifier.new)],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            home: const LoginScreen(),
          ),
        ),
      );

      expect(find.text('safeshift'), findsOneWidget);
      expect(find.byType(PhoneInputField), findsOneWidget);
      expect(find.text('9 more digits needed'), findsOneWidget);
      expect(find.text('Send OTP'), findsOneWidget);

      await tester.enterText(find.byType(TextField), '712345678');
      for (final brightness in [
        Brightness.light,
        Brightness.dark,
        Brightness.light,
      ]) {
        dispatcher.platformBrightnessTestValue = brightness;
        await tester.pumpAndSettle();
        final theme = brightness == Brightness.dark
            ? AppTheme.darkTheme
            : AppTheme.lightTheme;
        final field = tester.widget<TextField>(find.byType(TextField));
        expect(field.decoration!.fillColor, theme.colorScheme.surface);
        expect(field.style!.color, theme.colorScheme.onSurface);
        expect(field.controller!.text, '712 345 678');
        expect(
          tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
          theme.colorScheme.surface,
        );
      }
    },
  );
}
