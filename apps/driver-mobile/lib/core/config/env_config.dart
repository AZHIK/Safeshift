import 'app_environment.dart';

/// Resolves all build-time configuration from `--dart-define` values.
///
/// Production and staging builds are intentionally strict: a missing URL or
/// anon key throws when the Supabase client initializes. Dev builds fall back
/// to the local Supabase CLI stack so `flutter run` works with no defines.
class EnvConfig {
  const EnvConfig._({
    required this.environment,
    required this.supabaseUrl,
    required this.supabaseAnonKey,
    required this.functionsUrl,
    required this.isUsingLocalFallback,
  });

  static const String _envName = String.fromEnvironment(
    'ENV',
    defaultValue: 'dev',
  );
  static const String _supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const String _supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
  );

  /// Local Supabase CLI defaults. The anon key is public by design and is
  /// only used when ENV=dev and no explicit value was supplied.
  static const String localSupabaseUrl = 'http://127.0.0.1:54321';
  static const String localSupabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.'
      'eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.'
      'CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0';

  final AppEnvironment environment;
  final String supabaseUrl;
  final String supabaseAnonKey;

  /// Edge Function base URL. `supabase.functions.invoke()` derives this from
  /// [supabaseUrl], but screens/services can also display or use it directly.
  final String functionsUrl;

  /// True when dev defaults were used instead of explicit dart-defines.
  final bool isUsingLocalFallback;

  static final EnvConfig current = _resolve();

  static EnvConfig _resolve() {
    final environment = AppEnvironment.parse(_envName);
    final url = _supabaseUrl.trim();
    final key = _supabaseAnonKey.trim();
    final usingFallback = environment.isDev && (url.isEmpty || key.isEmpty);
    final resolvedUrl = usingFallback ? localSupabaseUrl : url;
    final resolvedKey = usingFallback ? localSupabaseAnonKey : key;

    return EnvConfig._(
      environment: environment,
      supabaseUrl: _normalizeUrl(resolvedUrl),
      supabaseAnonKey: resolvedKey,
      functionsUrl: _functionsUrl(resolvedUrl),
      isUsingLocalFallback: usingFallback,
    );
  }

  static String _normalizeUrl(String value) {
    if (value.isEmpty) return value;
    return value.endsWith('/') ? value.substring(0, value.length - 1) : value;
  }

  static String _functionsUrl(String supabaseUrl) {
    final normalized = _normalizeUrl(supabaseUrl);
    if (normalized.isEmpty) return '';
    return '$normalized/functions/v1';
  }

  /// Throws a descriptive error for incomplete staging/production builds.
  void validate() {
    if (supabaseUrl.isEmpty) {
      throw StateError(
        'SUPABASE_URL is required for ENV=${environment.label}. '
        'Pass --dart-define=SUPABASE_URL=...',
      );
    }
    if (supabaseAnonKey.isEmpty) {
      throw StateError(
        'SUPABASE_ANON_KEY is required for ENV=${environment.label}. '
        'Pass --dart-define=SUPABASE_ANON_KEY=...',
      );
    }
    final uri = Uri.tryParse(supabaseUrl);
    if (uri == null || !uri.hasScheme) {
      throw StateError('SUPABASE_URL must include http:// or https://');
    }
  }
}
