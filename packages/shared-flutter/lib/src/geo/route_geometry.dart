import 'dart:math' as math;

/// A latitude/longitude pair in degrees.
///
/// Kept independent of any map SDK so both apps (and tests) can share the
/// geometry; convert to the map's own type at the edge.
typedef GeoPoint = ({double lat, double lng});

const double _earthRadiusM = 6371008.8;

double _rad(double deg) => deg * math.pi / 180.0;
double _deg(double rad) => rad * 180.0 / math.pi;

/// Great-circle distance between two points, in metres.
double distanceMeters(GeoPoint a, GeoPoint b) {
  final dLat = _rad(b.lat - a.lat);
  final dLng = _rad(b.lng - a.lng);
  final h =
      math.pow(math.sin(dLat / 2), 2) +
      math.cos(_rad(a.lat)) *
          math.cos(_rad(b.lat)) *
          math.pow(math.sin(dLng / 2), 2);
  return 2 * _earthRadiusM * math.asin(math.min(1, math.sqrt(h)));
}

/// Initial compass bearing from [a] to [b], 0–360 degrees (0 = north).
double bearingDegrees(GeoPoint a, GeoPoint b) {
  final lat1 = _rad(a.lat);
  final lat2 = _rad(b.lat);
  final dLng = _rad(b.lng - a.lng);
  final y = math.sin(dLng) * math.cos(lat2);
  final x =
      math.cos(lat1) * math.sin(lat2) -
      math.sin(lat1) * math.cos(lat2) * math.cos(dLng);
  return (_deg(math.atan2(y, x)) + 360) % 360;
}

/// Linear interpolation between two points; fine for the few metres a
/// vehicle moves between live updates.
GeoPoint lerpPoint(GeoPoint a, GeoPoint b, double t) =>
    (lat: a.lat + (b.lat - a.lat) * t, lng: a.lng + (b.lng - a.lng) * t);

/// Shortest-turn interpolation between two headings in degrees.
double lerpBearing(double from, double to, double t) {
  final delta = ((to - from + 540) % 360) - 180;
  return (from + delta * t + 360) % 360;
}

/// Total length of a polyline, in metres.
double polylineLengthMeters(List<GeoPoint> points) {
  var total = 0.0;
  for (var i = 1; i < points.length; i++) {
    total += distanceMeters(points[i - 1], points[i]);
  }
  return total;
}

/// Where a position sits relative to a route.
class RouteProgress {
  const RouteProgress({
    required this.segmentIndex,
    required this.snapped,
    required this.offRouteMeters,
  });

  /// Index of the route segment (points[i] → points[i+1]) nearest the position.
  final int segmentIndex;

  /// The nearest point on the route.
  final GeoPoint snapped;

  /// Distance from the position to the route, in metres.
  final double offRouteMeters;
}

/// Projects [position] onto [route] (needs at least two points).
///
/// Uses a local equirectangular projection around the position, which is
/// accurate to well under a metre over city-scale segments.
RouteProgress? projectOntoRoute(List<GeoPoint> route, GeoPoint position) {
  if (route.length < 2) return null;
  final cosLat = math.cos(_rad(position.lat));
  // Metres per degree in this neighbourhood.
  const mPerDegLat = 111320.0;
  final mPerDegLng = 111320.0 * cosLat;

  double bestDist = double.infinity;
  var bestIndex = 0;
  GeoPoint bestPoint = route.first;

  for (var i = 0; i < route.length - 1; i++) {
    final a = route[i];
    final b = route[i + 1];
    final ax = (a.lng - position.lng) * mPerDegLng;
    final ay = (a.lat - position.lat) * mPerDegLat;
    final bx = (b.lng - position.lng) * mPerDegLng;
    final by = (b.lat - position.lat) * mPerDegLat;
    final dx = bx - ax;
    final dy = by - ay;
    final len2 = dx * dx + dy * dy;
    var t = len2 == 0 ? 0.0 : -(ax * dx + ay * dy) / len2;
    t = t.clamp(0.0, 1.0);
    final px = ax + dx * t;
    final py = ay + dy * t;
    final d = math.sqrt(px * px + py * py);
    if (d < bestDist) {
      bestDist = d;
      bestIndex = i;
      bestPoint = lerpPoint(a, b, t);
    }
  }
  return RouteProgress(
    segmentIndex: bestIndex,
    snapped: bestPoint,
    offRouteMeters: bestDist,
  );
}

/// The part of [route] still ahead of [position]: the snapped point followed
/// by every remaining vertex. Returns [route] unchanged when it cannot be
/// projected.
List<GeoPoint> remainingRoute(List<GeoPoint> route, GeoPoint position) {
  final progress = projectOntoRoute(route, position);
  if (progress == null) return route;
  return <GeoPoint>[
    progress.snapped,
    ...route.sublist(progress.segmentIndex + 1),
  ];
}

/// Decides when a live route must be fetched again instead of trimmed.
///
/// Big apps trim the route locally as the vehicle advances and only ask the
/// routing service again when the vehicle leaves the route, the destination
/// changes, or the route is old enough that traffic may have changed.
class RerouteRule {
  const RerouteRule({
    this.offRouteMeters = 80,
    this.maxAge = const Duration(minutes: 5),
  });

  final double offRouteMeters;
  final Duration maxAge;

  bool needsReroute({
    required List<GeoPoint> route,
    required GeoPoint position,
    required DateTime fetchedAt,
    DateTime? now,
  }) {
    if (route.length < 2) return true;
    if ((now ?? DateTime.now()).difference(fetchedAt) > maxAge) return true;
    final progress = projectOntoRoute(route, position);
    return progress == null || progress.offRouteMeters > offRouteMeters;
  }
}
