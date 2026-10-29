/// Compile-time environment for the SafeShift driver app.
///
/// Selected with `--dart-define=ENV=dev|staging|prod`. The default is [dev]
/// so a plain `flutter run` can talk to the local Supabase stack.
enum AppEnvironment {
  dev,
  staging,
  prod;

  /// Parses the `ENV` dart-define. Unknown values fail fast instead of
  /// silently falling back to production.
  static AppEnvironment parse(String raw) {
    switch (raw.trim().toLowerCase()) {
      case 'dev':
      case 'development':
      case 'local':
        return AppEnvironment.dev;
      case 'staging':
      case 'stage':
        return AppEnvironment.staging;
      case 'prod':
      case 'production':
        return AppEnvironment.prod;
      default:
        throw ArgumentError.value(
          raw,
          'ENV',
          'Expected one of: dev, staging, prod',
        );
    }
  }

  bool get isDev => this == AppEnvironment.dev;
  bool get isStaging => this == AppEnvironment.staging;
  bool get isProd => this == AppEnvironment.prod;

  String get label => switch (this) {
    AppEnvironment.dev => 'dev',
    AppEnvironment.staging => 'staging',
    AppEnvironment.prod => 'prod',
  };
}
