// Phase 8 auth guard. Pure function so it is unit-testable without a router.

/// Pure auth redirect decision used by the customer app router.
///
/// - The router must not redirect until session recovery completes.
/// - Unauthenticated users visiting a protected route go to /login.
/// - Authenticated users visiting /login, /otp, or /onboarding go to /home.
/// - Returns null when navigation is allowed.
String? authRedirect({
  required bool isAuthenticated,
  required bool isInitialized,
  required String location,
}) {
  if (!isInitialized) return null;

  const publicPaths = <String>['/login', '/otp', '/onboarding'];
  final isPublic = publicPaths.contains(location);

  if (!isAuthenticated && !isPublic) {
    return '/login';
  }
  if (isAuthenticated && isPublic) {
    return '/home';
  }
  return null;
}
