import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

class GeoPoint {
  const GeoPoint(this.latitude, this.longitude);
  final double latitude;
  final double longitude;

  bool get isValid =>
      latitude.isFinite &&
      longitude.isFinite &&
      latitude >= -90 &&
      latitude <= 90 &&
      longitude >= -180 &&
      longitude <= 180;
}

/// Great-circle distance in metres between two coordinates.
double distanceMetersBetween(GeoPoint a, GeoPoint b) {
  const earthRadiusMeters = 6371000.0;
  final dLat = _radians(b.latitude - a.latitude);
  final dLng = _radians(b.longitude - a.longitude);
  final lat1 = _radians(a.latitude);
  final lat2 = _radians(b.latitude);
  final sinDLat = math.sin(dLat / 2);
  final sinDLng = math.sin(dLng / 2);
  final h =
      sinDLat * sinDLat + math.cos(lat1) * math.cos(lat2) * sinDLng * sinDLng;
  // Floating-point error can push h slightly outside [0, 1] for antipodal
  // points; clamp before taking square roots.
  final clamped = h.clamp(0.0, 1.0).toDouble();
  return earthRadiusMeters *
      2 *
      math.atan2(math.sqrt(clamped), math.sqrt(1 - clamped));
}

/// Formats a distance for compact UI, e.g. "850 m", "4.2 km", "24 km".
String formatDistanceMeters(double? meters) {
  if (meters == null || !meters.isFinite || meters < 0) return '';
  if (meters < 1000) return '${meters.round()} m';
  final km = meters / 1000;
  if (km < 10) return '${km.toStringAsFixed(1)} km';
  return '${km.round()} km';
}

/// Formats a horizontal accuracy, e.g. "±35 m".
String formatAccuracyMeters(double? meters) {
  if (meters == null || !meters.isFinite || meters <= 0) {
    return 'Accuracy unavailable';
  }
  return '±${meters.round()} m';
}

double _radians(double degrees) => degrees * math.pi / 180;

/// Parses a PostGIS point from common Supabase/PostgREST representations.
GeoPoint? parseGeoPoint(Object? value) {
  if (value == null) return null;
  if (value is Map) {
    final map = value.cast<String, dynamic>();
    final coords = map['coordinates'];
    if (coords is List && coords.length >= 2) {
      final lng = (coords[0] as num?)?.toDouble();
      final lat = (coords[1] as num?)?.toDouble();
      if (lat != null && lng != null) return GeoPoint(lat, lng);
    }
  }
  if (value is! String) return null;
  final text = value.trim();
  if (text.isEmpty) return null;

  // GeoJSON string
  if (text.startsWith('{')) {
    try {
      return parseGeoPoint(jsonDecode(text));
    } catch (_) {}
  }

  // EWKT/WKT: SRID=4326;POINT(lng lat) or POINT(lng lat)
  final point = RegExp(
    r'POINT\s*\(\s*([-\d.]+)\s+([-\d.]+)\s*\)',
    caseSensitive: false,
  ).firstMatch(text);
  if (point != null) {
    final lng = double.tryParse(point.group(1)!);
    final lat = double.tryParse(point.group(2)!);
    if (lat != null && lng != null) return GeoPoint(lat, lng);
  }

  // EWKB hex (common for geography)
  if (RegExp(r'^[0-9A-Fa-f]+$').hasMatch(text) && text.length >= 34) {
    try {
      return _parseEwkbPoint(text);
    } catch (_) {}
  }
  return null;
}

GeoPoint? _parseEwkbPoint(String hex) {
  final bytes = Uint8List(hex.length ~/ 2);
  for (var i = 0; i < bytes.length; i++) {
    bytes[i] = int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16);
  }
  final data = ByteData.sublistView(bytes);
  var offset = 0;
  final littleEndian = data.getUint8(offset) == 1;
  offset += 1;
  final endian = littleEndian ? Endian.little : Endian.big;
  var type = data.getUint32(offset, endian);
  offset += 4;
  // EWKB SRID flag
  if ((type & 0x20000000) != 0) {
    offset += 4; // srid
    type &= ~0x20000000;
  }
  // Point = 1
  if ((type & 0xFF) != 1) return null;
  final x = data.getFloat64(offset, endian); // lng
  offset += 8;
  final y = data.getFloat64(offset, endian); // lat
  return GeoPoint(y, x);
}
