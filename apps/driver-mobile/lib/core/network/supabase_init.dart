import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/env_config.dart';
import '../config/supabase_config.dart';
import 'secure_local_storage.dart';

/// Idempotent Supabase bootstrap. Call once from `main()` before `runApp`.
abstract final class SupabaseInit {
  static Future<void>? _initialization;
  static SupabaseClient? _client;

  /// Ensures the Supabase SDK is initialized exactly once.
  ///
  /// Safe to call from tests, hot restart, and repeated app boots. The future
  /// is cached so concurrent callers await the same initialization.
  static Future<void> ensureInitialized() {
    return _initialization ??= _initialize();
  }

  static Future<void> _initialize() async {
    if (Supabase.instance.isInitialized) {
      _client = Supabase.instance.client;
      return;
    }

    final env = EnvConfig.current;
    env.validate();
    final config = SupabaseConfig.fromEnvironment(env);

    final host = Uri.parse(config.url).host.split('.').first;
    final supabase = await Supabase.initialize(
      url: config.url,
      publishableKey: config.anonKey,
      debug: false,
      authOptions: FlutterAuthClientOptions(
        // Session is stored in Keychain / EncryptedSharedPreferences.
        localStorage: SecureLocalStorage(
          persistSessionKey: 'sb-$host-auth-token',
        ),
        // OTP-only auth. Deep links are owned by DeepLinkHandler, not the SDK.
        detectSessionInUri: false,
        autoRefreshToken: true,
        persistSession: true,
      ),
    );
    _client = supabase.client;

    if (kDebugMode) {
      debugPrint(
        'SafeShift Supabase initialized for ENV=${env.environment.label} '
        '(${config.isLocal ? 'local' : 'remote'})',
      );
    }
  }

  /// The initialized client. Throws if [ensureInitialized] has not run.
  static SupabaseClient get client {
    final existing = _client;
    if (existing != null) return existing;
    if (Supabase.instance.isInitialized) {
      _client = Supabase.instance.client;
      return _client!;
    }
    throw StateError('SupabaseInit.ensureInitialized() must be called first.');
  }
}
