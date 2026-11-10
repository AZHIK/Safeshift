import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Decodes a Google encoded polyline string into [LatLng] coordinates.
///
/// Google's encoded polyline algorithm stores each latitude/longitude delta as
/// a variable-length, signed, 5-bit chunked integer. Coordinates are scaled by
/// 1e5 before encoding, so each decoded value is divided by 1e5.
///
/// Returns an empty list when the input is null, empty, or malformed.
List<LatLng> decodePolyline(String? encoded) {
  if (encoded == null || encoded.isEmpty) return const <LatLng>[];

  final points = <LatLng>[];
  var index = 0;
  var lat = 0;
  var lng = 0;

  while (index < encoded.length) {
    final latDelta = _decodeCoord(encoded, index);
    index = latDelta.$2;
    lat += latDelta.$1;

    final lngDelta = _decodeCoord(encoded, index);
    index = lngDelta.$2;
    lng += lngDelta.$1;

    points.add(LatLng(lat / 1e5, lng / 1e5));
  }

  return points;
}

/// Decodes a single signed coordinate delta from [encoded] starting at
/// [index]. Returns `(delta, nextIndex)`.
(int, int) _decodeCoord(String encoded, int index) {
  var result = 0;
  var shift = 0;
  var byte = 0;

  do {
    if (index >= encoded.length) break;
    byte = encoded.codeUnitAt(index) - 63;
    index += 1;
    result |= (byte & 0x1F) << shift;
    shift += 5;
  } while (byte >= 0x20);

  final delta = (result & 1) == 1 ? ~(result >> 1) : (result >> 1);
  return (delta, index);
}
