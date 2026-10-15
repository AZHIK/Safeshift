// TODO: add role-based and onboarding guards in a later sprint. Mock auth only.

/// Pure auth redirect decision used by the app router.
///
/// - Unauthenticated users visiting a protected route go to /login.
/// - Authenticated users visiting /login or /otp go to /home.
/// - Returns null when navigation is allowed.
String? authRedirect({required bool isAuthenticated, required String location}) {
  const publicPaths = <String>['/login', '/otp'];
  final isPublic = publicPaths.contains(location);
  if (!isAuthenticated && !isPublic) {
    return '/login';
  }
  if (isAuthenticated && isPublic) {
    return '/home';
  }
  return null;
}
