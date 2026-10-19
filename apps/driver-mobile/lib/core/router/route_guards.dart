// TODO: add role-based guards in a later sprint. Mock auth only.

/// Pure auth + profile redirect decision used by the app router.
///
/// - Unauthenticated users visiting a protected route go to /login.
/// - Authenticated users without a completed profile are forced to
///   /complete-profile (except while on /login, /otp, /complete-profile).
/// - Authenticated users with a completed profile visiting /login, /otp or
///   /complete-profile go to /home.
/// - Returns null when navigation is allowed.
String? authRedirect({
  required bool isAuthenticated,
  required bool hasCompletedProfile,
  required String location,
}) {
  const publicPaths = <String>['/login', '/otp'];
  const profileSetupPath = '/complete-profile';

  final isPublic = publicPaths.contains(location);
  final isProfileSetup = location == profileSetupPath;

  if (!isAuthenticated && !isPublic) {
    return '/login';
  }
  if (isAuthenticated && isPublic) {
    return hasCompletedProfile ? '/home' : profileSetupPath;
  }
  if (isAuthenticated && !hasCompletedProfile && !isPublic && !isProfileSetup) {
    return profileSetupPath;
  }
  if (isAuthenticated && hasCompletedProfile && isProfileSetup) {
    return '/home';
  }
  return null;
}
