import 'dart:math' as math;

import 'route_geometry.dart';

/// Camera helpers shared by the customer and driver maps, tuned to feel like
/// Bolt and Uber: the vehicle sits low on the screen with the road ahead in
/// view, and short trips are not zoomed in to street level.

const double _earthRadiusM = 6371008.8;

/// The point [metres] away from [from] in direction [bearing] (0 = north).
GeoPoint offsetPoint(GeoPoint from, double bearing, double metres) {
  final d = metres / _earthRadiusM;
  final b = bearing * math.pi / 180;
  final lat1 = from.lat * math.pi / 180;
  final lng1 = from.lng * math.pi / 180;
  final lat2 = math.asin(
    math.sin(lat1) * math.cos(d) + math.cos(lat1) * math.sin(d) * math.cos(b),
  );
  final lng2 =
      lng1 +
      math.atan2(
        math.sin(b) * math.sin(d) * math.cos(lat1),
        math.cos(d) - math.sin(lat1) * math.sin(lat2),
      );
  return (lat: lat2 * 180 / math.pi, lng: lng2 * 180 / math.pi);
}

/// Ground metres covered by one logical pixel at [zoom] (256-pixel tiles).
double metersPerPixel(double latitude, double zoom) =>
    156543.03392 * math.cos(latitude * math.pi / 180) / math.pow(2, zoom);

/// Navigation zoom for the driver's speed: closer in slow traffic, wider at
/// speed so the next turns stay on screen.
double navigationZoom(double? speedKmh) {
  final speed = speedKmh ?? 0;
  if (speed < 20) return 15.5;
  if (speed < 45) return 15.0;
  if (speed < 75) return 14.5;
  return 14.0;
}

/// Camera for following a moving vehicle.
///
/// The target is pushed ahead of the vehicle along [heading], so the vehicle
/// sits in the lower part of the visible map ([vehicleAt] of the way down,
/// 0.5 = centre) and the driver sees more of the road ahead than behind.
({GeoPoint target, double zoom}) navigationCamera({
  required GeoPoint vehicle,
  required double heading,
  required double visibleHeightPx,
  double? speedKmh,
  double vehicleAt = 0.72,
}) {
  final zoom = navigationZoom(speedKmh);
  final pixelsAhead = visibleHeightPx * (vehicleAt - 0.5);
  if (pixelsAhead <= 0) return (target: vehicle, zoom: zoom);
  final metresAhead = pixelsAhead * metersPerPixel(vehicle.lat, zoom);
  return (target: offsetPoint(vehicle, heading, metresAhead), zoom: zoom);
}

/// Bounds around [points], widened to at least [minSpanMeters] in each
/// direction so a short trip still shows the surrounding streets.
({double south, double west, double north, double east})? framingBounds(
  Iterable<GeoPoint> points, {
  double minSpanMeters = 1500,
}) {
  double? south, north, west, east;
  for (final p in points) {
    south = south == null ? p.lat : math.min(south, p.lat);
    north = north == null ? p.lat : math.max(north, p.lat);
    west = west == null ? p.lng : math.min(west, p.lng);
    east = east == null ? p.lng : math.max(east, p.lng);
  }
  if (south == null || north == null || west == null || east == null) {
    return null;
  }
  final midLat = (south + north) / 2;
  final midLng = (west + east) / 2;
  final minLatSpan = minSpanMeters / 111320;
  final minLngSpan =
      minSpanMeters /
      (111320 * math.max(0.01, math.cos(midLat * math.pi / 180)));
  if (north - south < minLatSpan) {
    south = midLat - minLatSpan / 2;
    north = midLat + minLatSpan / 2;
  }
  if (east - west < minLngSpan) {
    west = midLng - minLngSpan / 2;
    east = midLng + minLngSpan / 2;
  }
  return (south: south, west: west, north: north, east: east);
}
