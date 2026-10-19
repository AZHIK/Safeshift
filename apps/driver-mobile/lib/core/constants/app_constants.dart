// TODO: add environment-specific overrides (dev/staging/prod flavors) and read
// secrets from .env instead of hardcoding placeholders.
abstract final class AppConstants {
  static const String appName = 'safeshift';
  static const String appVersion = '0.1.0';
  static const String apiBaseUrl = 'https://api.safeshift.example.com/v1';
  static const String supabaseUrl = 'https://your-project.supabase.co';
  static const String supabaseAnonKey = 'SUPABASE_ANON_KEY_FROM_ENV';
  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 15);
}
