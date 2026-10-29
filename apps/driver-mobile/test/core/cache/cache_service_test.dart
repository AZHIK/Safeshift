import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:safeshift_driver/core/cache/cache_service.dart';

void main() {
  late Directory tempDir;
  late Box<String> box;
  late CacheService cache;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('safeshift-driver-cache-');
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
    await cache.putJson('driver-a', 'earnings', <String, int>{'today': 10});

    expect(cache.getJson('driver-a', 'earnings'), <String, int>{'today': 10});
    expect(cache.getJson('driver-b', 'earnings'), isNull);
  });

  test('clearUser removes every namespace for that driver', () async {
    await cache.putJson('driver-a', 'earnings', <String, int>{'today': 10});
    await cache.putJson('driver-a', 'trips', <String>['job-1']);
    await cache.putJson('driver-b', 'trips', <String>['job-2']);

    await cache.clearUser('driver-a');

    expect(cache.getJson('driver-a', 'earnings'), isNull);
    expect(cache.getJson('driver-a', 'trips'), isNull);
    expect(cache.getJson('driver-b', 'trips'), isNotNull);
  });
}
