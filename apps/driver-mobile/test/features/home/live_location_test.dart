import 'package:flutter_test/flutter_test.dart';
import 'package:safeshift_driver/features/home/data/live_location.dart';

void main() {
  final t0 = DateTime.utc(2026, 11, 20, 12);
  LiveFix fix(
    double lng,
    int seconds, {
    double accuracy = 8,
    double? heading,
  }) => LiveFix(
    lat: -6.8,
    lng: lng,
    at: t0.add(Duration(seconds: seconds)),
    accuracyM: accuracy,
    heading: heading,
  );

  test('keeps normal driving and drops bad fixes', () {
    final filter = GpsFilter();
    expect(filter.accept(fix(39.2700, 0)), isNotNull);
    // ~110 m in 10 s = 40 km/h: fine.
    expect(filter.accept(fix(39.2710, 10)), isNotNull);
    // Poor accuracy.
    expect(filter.accept(fix(39.2711, 12, accuracy: 120)), isNull);
    // ~1.1 km in 3 s: a GPS jump.
    expect(filter.accept(fix(39.2810, 13)), isNull);
    // Same timestamp as the last accepted fix.
    expect(filter.accept(fix(39.2712, 10)), isNull);
    expect(filter.last!.lng, 39.2710);
  });

  test('broadcast payload is compact and typed', () {
    final payload = fix(39.27, 0, heading: 271.6).toBroadcast();
    expect(payload['lat'], -6.8);
    expect(payload['lng'], 39.27);
    expect(payload['heading'], 272);
    expect(payload['accuracy_m'], 8);
    expect(payload.containsKey('speed_kmh'), isFalse);
    expect(payload['at'], '2026-11-20T12:00:00.000Z');
  });
}
