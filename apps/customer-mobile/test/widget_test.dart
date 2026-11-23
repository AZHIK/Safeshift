import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safeshift_customer/core/router/app_router.dart';
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

  void setLoading(bool value) => state = state.copyWith(isLoading: value);

  @override
  Future<void> signInWithGoogle({VoidCallback? onAccountSelected}) async =>
      googleCalls++;
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

  testWidgets('Choosing a Google account shows a signing-in overlay', (
    tester,
  ) async {
    final finish = Completer<void>();
    final notifier = _PendingGoogleNotifier(finish.future);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [authProvider.overrideWith(() => notifier)],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const LoginScreen(),
        ),
      ),
    );
    expect(find.text('Signing you in…'), findsNothing);

    await tester.tap(find.byType(GoogleSignInButton));
    // The spinner never settles, so pump past the 200ms fade instead.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('Signing you in…'), findsOneWidget);

    finish.complete();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    // Not authenticated in this fake, so the overlay clears again.
    expect(find.text('Signing you in…'), findsNothing);
  });

  test('auth state changes do not rebuild the router', () async {
    final container = ProviderContainer(
      overrides: [
        authProvider.overrideWith(_FakeAuthNotifier.new),
        routerInitialLocationProvider.overrideWithValue('/onboarding'),
      ],
    );
    addTearDown(container.dispose);

    final router = container.read(routerProvider);
    final notifier = container.read(authProvider.notifier) as _FakeAuthNotifier;
    notifier.setLoading(true);
    notifier.setLoading(false);

    // A new GoRouter would restart at /onboarding mid sign-in.
    expect(identical(container.read(routerProvider), router), isTrue);
  });
}

class _PendingGoogleNotifier extends _FakeAuthNotifier {
  _PendingGoogleNotifier(this._done);

  final Future<void> _done;

  @override
  Future<void> signInWithGoogle({VoidCallback? onAccountSelected}) async {
    onAccountSelected?.call();
    await _done;
  }
}
