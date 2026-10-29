import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// Small Hive-backed cache used for offline-first rendering.
///
/// Every write is scoped by user id where the data is personal, so signing out
/// and signing in as another user cannot surface stale data.
class CacheService {
  CacheService(this._box);

  static const String boxName = 'safeshift_cache_v1';

  static Future<void> init() async {
    await Hive.initFlutter();
    await Hive.openBox<String>(boxName);
  }

  final Box<String> _box;

  String _key(String userId, String namespace, [String? id]) =>
      '$userId:$namespace${id == null ? '' : ':$id'}';

  Future<void> putJson(
    String userId,
    String namespace,
    Object? value, {
    String? id,
  }) async {
    await _box.put(_key(userId, namespace, id), jsonEncode(value));
  }

  Object? getJson(String userId, String namespace, {String? id}) {
    final raw = _box.get(_key(userId, namespace, id));
    if (raw == null) return null;
    try {
      return jsonDecode(raw);
    } catch (_) {
      return null;
    }
  }

  Future<void> clearNamespace(String userId, String namespace) async {
    final prefix = '$userId:$namespace';
    final keys = _box.keys
        .where((key) => key.toString().startsWith(prefix))
        .toList();
    await _box.deleteAll(keys);
  }

  Future<void> clearUser(String userId) async {
    final prefix = '$userId:';
    final keys = _box.keys
        .where((key) => key.toString().startsWith(prefix))
        .toList();
    await _box.deleteAll(keys);
  }

  Future<void> clearAll() => _box.clear();
}

final cacheServiceProvider = Provider<CacheService>((ref) {
  return CacheService(Hive.box<String>(CacheService.boxName));
});
