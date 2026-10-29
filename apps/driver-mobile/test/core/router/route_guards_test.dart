import 'package:flutter_test/flutter_test.dart';
import 'package:safeshift_driver/core/router/route_guards.dart';

void main() {
  group('driver authRedirect', () {
    test('waits for session recovery', () {
      expect(
        authRedirect(
          isAuthenticated: false,
          isInitialized: false,
          isDriverRegistered: false,
          location: '/home',
        ),
        isNull,
      );
    });

    test('sends unauthenticated users to login', () {
      expect(
        authRedirect(
          isAuthenticated: false,
          isInitialized: true,
          isDriverRegistered: false,
          location: '/home',
        ),
        '/login',
      );
    });

    test('authenticated but unregistered drivers go to onboarding', () {
      expect(
        authRedirect(
          isAuthenticated: true,
          isInitialized: true,
          isDriverRegistered: false,
          location: '/home',
        ),
        '/driver-onboarding',
      );
      expect(
        authRedirect(
          isAuthenticated: true,
          isInitialized: true,
          isDriverRegistered: false,
          location: '/login',
        ),
        '/driver-onboarding',
      );
    });

    test('registered drivers can use protected routes', () {
      expect(
        authRedirect(
          isAuthenticated: true,
          isInitialized: true,
          isDriverRegistered: true,
          location: '/trips',
        ),
        isNull,
      );
    });

    test('registered drivers are sent away from onboarding', () {
      expect(
        authRedirect(
          isAuthenticated: true,
          isInitialized: true,
          isDriverRegistered: true,
          location: '/driver-onboarding',
        ),
        '/home',
      );
    });
  });
}
