// Static product constants. Environment-specific Supabase/Firebase values are
// resolved in core/config from --dart-define, not from this file.
abstract final class AppConstants {
  static const String appName = 'safeshift';
  static const String appVersion = '0.1.0';
  static const String apiBaseUrl = 'https://api.safeshift.example.com/v1';
  static const String supabaseUrl = 'https://your-project.supabase.co';
  static const String supabaseAnonKey = 'SUPABASE_ANON_KEY_FROM_ENV';
  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 15);
}
