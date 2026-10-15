// TODO: add refresh-token storage, session expiry, and biometric-gated reads
// in a later sprint. Placeholder wrapper only.
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Thin wrapper around [FlutterSecureStorage] for session tokens.
class StorageService {
  StorageService({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const String _tokenKey = 'safeshift_session_token';

  Future<void> writeToken(String token) {
    return _storage.write(key: _tokenKey, value: token);
  }

  Future<String?> readToken() {
    return _storage.read(key: _tokenKey);
  }

  Future<void> deleteToken() {
    return _storage.delete(key: _tokenKey);
  }

  Future<void> writeValue(String key, String value) {
    return _storage.write(key: key, value: value);
  }

  Future<String?> readValue(String key) {
    return _storage.read(key: key);
  }
}
