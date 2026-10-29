import 'env_config.dart';

/// Edge Function endpoints used by the customer app.
///
/// These are relative names passed to `supabase.functions.invoke()`. The
/// absolute base URL is resolved from the Supabase project URL.
abstract final class ApiConfig {
  static String get functionsBaseUrl => EnvConfig.current.functionsUrl;

  static const String quoteCalculate = 'quote-calculate';
  static const String mapsGeocode = 'maps-geocode';
  static const String mapsDistance = 'maps-distance';
  static const String paymentSelcomInitiate = 'payment-selcom-initiate';
  static const String dataExport = 'data-export';
  static const String authValidate = 'auth-validate';

  /// Returns the fully-qualified URL for diagnostics/logging. Never include
  /// query strings or tokens in logs.
  static String functionUrl(String name) => '$functionsBaseUrl/$name';
}
