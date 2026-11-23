import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safeshift_customer/core/theme/app_theme.dart';
import 'package:safeshift_customer/features/auth/domain/entities/auth_state.dart';
import 'package:safeshift_customer/features/auth/presentation/screens/login_screen.dart';
import 'package:safeshift_customer/features/auth/presentation/widgets/phone_input_field.dart';
import 'package:safeshift_customer/features/auth/providers/auth_provider.dart';
import 'package:safeshift_shared/safeshift_shared.dart' show GoogleSignInButton;

class _FakeAuthNotifier extends AuthNotifier {
  _FakeAuthNotifier() : super(appRole: 'customer');

  int googleCalls = 0;

  @override
  AuthState build() => const AuthState(isInitialized: true);

  @override
  Future<void> signInWithGoogle() async => googleCalls++;
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

      expect(find.text('SafeShift'), findsOneWidget);
      expect(find.text('Enter your phone number'), findsOneWidget);
      expect(find.byType(PhoneInputField), findsOneWidget);
      // Phone OTP and Google are the sign-in methods; email is gone.
      expect(find.byType(GoogleSignInButton), findsOneWidget);
      expect(find.text('Continue with Google'), findsOneWidget);
      expect(find.textContaining('Email'), findsNothing);
      FilledButton button() =>
          tester.widget<FilledButton>(find.byType(FilledButton));
      expect(button().onPressed, isNull);

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
        // Plain field: no fill and no outer border.
        expect(field.decoration!.filled, isFalse);
        expect(field.decoration!.border, InputBorder.none);
        expect(field.style!.color, theme.colorScheme.onSurface);
        expect(button().onPressed, isNotNull);
        expect(field.controller!.text, '712 345 678');
        expect(
          tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
          theme.colorScheme.surface,
        );
      }
    },
  );

  testWidgets('Tapping Continue with Google starts Google sign-in', (
    tester,
  ) async {
    final notifier = _FakeAuthNotifier();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [authProvider.overrideWith(() => notifier)],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const LoginScreen(),
        ),
      ),
    );
    await tester.tap(find.byType(GoogleSignInButton));
    await tester.pumpAndSettle();
    expect(notifier.googleCalls, 1);
  });

  testWidgets('Phone field outline stays grey and thickens when focused', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [authProvider.overrideWith(_FakeAuthNotifier.new)],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const LoginScreen(),
        ),
      ),
    );
    Color outline() {
      final box = tester.widget<AnimatedContainer>(
        find
            .descendant(
              of: find.byType(PhoneInputField),
              matching: find.byType(AnimatedContainer),
            )
            .first,
      );
      return ((box.decoration! as BoxDecoration).border! as Border).top.color;
    }

    double width() {
      final box = tester.widget<AnimatedContainer>(
        find
            .descendant(
              of: find.byType(PhoneInputField),
              matching: find.byType(AnimatedContainer),
            )
            .first,
      );
      return ((box.decoration! as BoxDecoration).border! as Border).top.width;
    }

    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    expect(outline(), AppTheme.lightTheme.colorScheme.outline);
    expect(width(), 1.0);

    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();
    expect(outline(), AppTheme.lightTheme.colorScheme.outline);
    expect(width(), 1.5);
  });
}
