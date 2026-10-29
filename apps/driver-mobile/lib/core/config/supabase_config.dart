import 'env_config.dart';

/// Immutable Supabase connection settings resolved at compile time.
class SupabaseConfig {
  const SupabaseConfig({required this.url, required this.anonKey});

  final String url;
  final String anonKey;

  factory SupabaseConfig.fromEnvironment([EnvConfig? config]) {
    final env = config ?? EnvConfig.current;
    env.validate();
    return SupabaseConfig(url: env.supabaseUrl, anonKey: env.supabaseAnonKey);
  }

  bool get isLocal => url.contains('127.0.0.1') || url.contains('localhost');
}
