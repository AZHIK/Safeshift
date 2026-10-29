import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:safeshift_customer/core/cache/cache_service.dart';

void main() {
  late Directory tempDir;
  late Box<String> box;
  late CacheService cache;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('safeshift-cache-test-');
    Hive.init(tempDir.path);
    box = await Hive.openBox<String>('cache-service-test');
  });

  tearDownAll(() async {
    await box.close();
    await Hive.deleteFromDisk();
    await tempDir.delete(recursive: true);
  });

  setUp(() async {
    await box.clear();
    cache = CacheService(box);
  });

  test('cache keys are scoped by user id', () async {
    await cache.putJson('user-a', 'history', <String, Object?>{
      'jobs': <String>['job-1'],
    });

    expect(cache.getJson('user-a', 'history'), <String, Object?>{
      'jobs': <String>['job-1'],
    });
    expect(cache.getJson('user-b', 'history'), isNull);
  });

  test('clearNamespace removes one user namespace only', () async {
    await cache.putJson('user-a', 'history', <String>['job-1']);
    await cache.putJson('user-a', 'earnings', <String, int>{'today': 10});
    await cache.putJson('user-b', 'history', <String>['job-2']);

    await cache.clearNamespace('user-a', 'history');

    expect(cache.getJson('user-a', 'history'), isNull);
    expect(cache.getJson('user-a', 'earnings'), isNotNull);
    expect(cache.getJson('user-b', 'history'), isNotNull);
  });

  test('clearUser removes every namespace for that user', () async {
    await cache.putJson('user-a', 'history', <String>['job-1']);
    await cache.putJson('user-a', 'earnings', <String, int>{'today': 10});
    await cache.putJson('user-b', 'history', <String>['job-2']);

    await cache.clearUser('user-a');

    expect(cache.getJson('user-a', 'history'), isNull);
    expect(cache.getJson('user-a', 'earnings'), isNull);
    expect(cache.getJson('user-b', 'history'), isNotNull);
  });
}
