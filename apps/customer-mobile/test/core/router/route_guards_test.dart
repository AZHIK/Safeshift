import 'package:flutter_test/flutter_test.dart';
import 'package:safeshift_customer/core/router/route_guards.dart';

void main() {
  group('customer authRedirect', () {
    test('waits for session recovery', () {
      expect(
        authRedirect(
          isAuthenticated: false,
          isInitialized: false,
          location: '/home',
        ),
        isNull,
      );
    });

    test('sends unauthenticated protected routes to login', () {
      expect(
        authRedirect(
          isAuthenticated: false,
          isInitialized: true,
          location: '/history',
        ),
        '/login',
      );
    });

    test('allows public routes while unauthenticated', () {
      for (final path in ['/login', '/otp', '/onboarding']) {
        expect(
          authRedirect(
            isAuthenticated: false,
            isInitialized: true,
            location: path,
          ),
          isNull,
        );
      }
    });

    test('sends authenticated users away from auth routes', () {
      for (final path in ['/login', '/otp', '/onboarding']) {
        expect(
          authRedirect(
            isAuthenticated: true,
            isInitialized: true,
            location: path,
          ),
          '/home',
        );
      }
    });

    test('allows authenticated protected routes', () {
      expect(
        authRedirect(
          isAuthenticated: true,
          isInitialized: true,
          location: '/home',
        ),
        isNull,
      );
    });
  });
}
