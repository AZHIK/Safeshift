import 'package:flutter_test/flutter_test.dart';
import 'package:safeshift_shared/safeshift_shared.dart';

void main() {
  // A straight road east along the equator-ish latitude of Dar es Salaam,
  // ~1.1 km long, with a vertex every ~110 m.
  final route = <GeoPoint>[
    for (var i = 0; i <= 10; i++) (lat: -6.8, lng: 39.27 + i * 0.001),
  ];

  test('distance and bearing', () {
    final a = (lat: -6.8, lng: 39.27);
    final b = (lat: -6.8, lng: 39.271);
    expect(distanceMeters(a, b), closeTo(110.5, 1));
    expect(bearingDegrees(a, b), closeTo(90, 0.5));
    expect(bearingDegrees(b, a), closeTo(270, 0.5));
    expect(lerpBearing(350, 10, 0.5), closeTo(0, 0.001));
  });

  test('projects a nearby position onto the route', () {
    final p = projectOntoRoute(route, (lat: -6.8003, lng: 39.2735))!;
    expect(p.segmentIndex, 3);
    expect(p.offRouteMeters, closeTo(33, 1.5));
    expect(p.snapped.lng, closeTo(39.2735, 1e-6));
  });

  test('remaining route starts at the snapped point', () {
    final rest = remainingRoute(route, (lat: -6.8, lng: 39.2755));
    expect(rest.first.lng, closeTo(39.2755, 1e-6));
    expect(rest.length, 1 + 5);
    expect(polylineLengthMeters(rest), closeTo(4.5 * 110.5, 3));
  });

  test('reroute only when off route or stale', () {
    const rule = RerouteRule();
    final fetched = DateTime(2026, 1, 1, 12);
    expect(
      rule.needsReroute(
        route: route,
        position: (lat: -6.8002, lng: 39.274),
        fetchedAt: fetched,
        now: fetched.add(const Duration(minutes: 1)),
      ),
      isFalse,
    );
    expect(
      rule.needsReroute(
        route: route,
        position: (lat: -6.8015, lng: 39.274),
        fetchedAt: fetched,
        now: fetched.add(const Duration(minutes: 1)),
      ),
      isTrue,
      reason: '~166 m off the road',
    );
    expect(
      rule.needsReroute(
        route: route,
        position: (lat: -6.8, lng: 39.274),
        fetchedAt: fetched,
        now: fetched.add(const Duration(minutes: 6)),
      ),
      isTrue,
      reason: 'route older than 5 minutes',
    );
  });
}
