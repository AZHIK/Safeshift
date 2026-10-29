// Phase 8 driver auth + registration guard. Pure function for unit tests.

/// Pure auth + driver-registration redirect decision.
///
/// - The router must not redirect until session recovery completes.
/// - Unauthenticated users visiting a protected route go to /login.
/// - Authenticated users without a drivers row go to /driver-onboarding.
/// - Registered drivers visiting /login, /otp, /onboarding, or
///   /driver-onboarding go to /home.
String? authRedirect({
  required bool isAuthenticated,
  required bool isInitialized,
  required bool isDriverRegistered,
  required String location,
}) {
  if (!isInitialized) return null;

  const publicPaths = <String>['/login', '/otp', '/onboarding'];
  const onboardingPath = '/driver-onboarding';

  final isPublic = publicPaths.contains(location);
  final isOnboarding = location == onboardingPath;

  if (!isAuthenticated && !isPublic) {
    return '/login';
  }
  if (isAuthenticated && isPublic) {
    return isDriverRegistered ? '/home' : onboardingPath;
  }
  if (isAuthenticated && !isDriverRegistered && !isOnboarding) {
    return onboardingPath;
  }
  if (isAuthenticated && isDriverRegistered && isOnboarding) {
    return '/home';
  }
  return null;
}
