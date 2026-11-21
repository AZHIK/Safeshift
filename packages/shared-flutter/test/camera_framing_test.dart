import 'package:flutter_test/flutter_test.dart';
import 'package:safeshift_shared/safeshift_shared.dart';

void main() {
  const dar = (lat: -6.7924, lng: 39.2083);

  test('offsetPoint moves the given distance in the given direction', () {
    final north = offsetPoint(dar, 0, 500);
    expect(distanceMeters(dar, north), closeTo(500, 1));
    expect(north.lat, greaterThan(dar.lat));
    final east = offsetPoint(dar, 90, 500);
    expect(east.lng, greaterThan(dar.lng));
    expect(bearingDegrees(dar, east), closeTo(90, 0.5));
  });

  test('navigation zoom widens with speed', () {
    expect(navigationZoom(null), 15.5);
    expect(navigationZoom(10), greaterThan(navigationZoom(60)));
    expect(navigationZoom(120), 14.0);
  });

  test('navigation camera looks ahead of the vehicle', () {
    final camera = navigationCamera(
      vehicle: dar,
      heading: 0,
      visibleHeightPx: 400,
    );
    // Target is north (ahead) of a vehicle heading north.
    expect(camera.target.lat, greaterThan(dar.lat));
    final ahead = distanceMeters(dar, camera.target);
    // 22% of 400 px at zoom 15.5 is roughly 400 m.
    expect(ahead, inInclusiveRange(250, 600));
  });

  test('framing bounds keep a minimum span for short trips', () {
    final b = framingBounds([dar, (lat: dar.lat + 0.001, lng: dar.lng)])!;
    final height = distanceMeters(
      (lat: b.south, lng: b.west),
      (lat: b.north, lng: b.west),
    );
    final width = distanceMeters(
      (lat: b.south, lng: b.west),
      (lat: b.south, lng: b.east),
    );
    expect(height, closeTo(1500, 5));
    expect(width, closeTo(1500, 5));
  });

  test('framing bounds leave long trips untouched', () {
    final far = (lat: dar.lat - 0.1, lng: dar.lng + 0.1);
    final b = framingBounds([dar, far])!;
    expect(b.north, dar.lat);
    expect(b.south, far.lat);
    expect(framingBounds(const []), isNull);
  });
}
