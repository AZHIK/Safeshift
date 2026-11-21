import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Which top-down vehicle to draw on the map.
enum VehicleMarkerKind { car, van, pickup, truck, flatbed }

/// Picks the marker shape from a vehicle type code or name, e.g. the
/// catalogue codes `small_van`, `pickup`, `medium_truck`, `flatbed`.
VehicleMarkerKind vehicleMarkerKindFor(String? codeOrName) {
  final text = (codeOrName ?? '').toLowerCase();
  bool has(List<String> words) => words.any(text.contains);
  if (has(const ['flatbed', 'flat bed', 'low loader'])) {
    return VehicleMarkerKind.flatbed;
  }
  if (has(const [
    'truck',
    'lorry',
    'canter',
    'fuso',
    'tipper',
    'refrigerated',
  ])) {
    return VehicleMarkerKind.truck;
  }
  if (has(const ['pickup', 'pick-up', 'pick up', 'kirikuu'])) {
    return VehicleMarkerKind.pickup;
  }
  if (has(const ['van', 'minibus'])) return VehicleMarkerKind.van;
  return VehicleMarkerKind.car;
}

/// A rendered marker image. [width] and [height] are logical pixels; pass them
/// to `BitmapDescriptor.bytes(png, width: ..., height: ...)`.
class VehicleMarkerImage {
  const VehicleMarkerImage(this.png, this.width, this.height);

  final Uint8List png;
  final double width;
  final double height;
}

/// Renders top-down vehicle markers (nose pointing up, i.e. north at
/// rotation 0) so a map can rotate them to the direction of travel, like the
/// cars in Bolt or Uber.
///
/// The vehicles are SVG drawn in code — no image assets, crisp at any screen
/// density, and tinted with any colour. Results are cached for the app's
/// lifetime, so every map and rebuild reuses the same bytes.
class VehicleMarkers {
  VehicleMarkers._();

  static final Map<String, Future<VehicleMarkerImage>> _cache = {};

  static Future<VehicleMarkerImage> render({
    VehicleMarkerKind kind = VehicleMarkerKind.car,
    required Color color,
    required double devicePixelRatio,
  }) {
    final dpr = devicePixelRatio.clamp(1.0, 4.0);
    final key = '${kind.name}|${color.toARGB32()}|${dpr.toStringAsFixed(2)}';
    return _cache.putIfAbsent(key, () async {
      try {
        return await _render(kind, color, dpr);
      } catch (_) {
        // Let a later call try again instead of caching the failure.
        unawaited(Future<void>(() => _cache.remove(key)));
        rethrow;
      }
    });
  }

  static Future<VehicleMarkerImage> _render(
    VehicleMarkerKind kind,
    Color color,
    double dpr,
  ) async {
    final (svg, w, h) = switch (kind) {
      VehicleMarkerKind.car => (_carSvg(color), 24.0, 48.0),
      VehicleMarkerKind.van => (_vanSvg(color), 25.0, 52.0),
      VehicleMarkerKind.pickup => (_pickupSvg(color), 25.0, 52.0),
      VehicleMarkerKind.truck => (_truckSvg(color), 26.0, 62.0),
      VehicleMarkerKind.flatbed => (_flatbedSvg(color), 26.0, 64.0),
    };
    const pad = 5.0; // room for the shadow
    final info = await vg.loadPicture(SvgStringLoader(svg), null);
    try {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder)..scale(dpr);

      // Soft ground shadow, slightly offset like a light from above.
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(pad + 1.5, pad + 2.5, w - 3, h - 3),
          Radius.circular(w * 0.35),
        ),
        Paint()
          ..color = Colors.black.withValues(alpha: 0.30)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.4),
      );

      canvas
        ..translate(pad, pad)
        ..scale(w / info.size.width, h / info.size.height)
        ..drawPicture(info.picture);

      final totalW = w + pad * 2;
      final totalH = h + pad * 2;
      final image = await recorder.endRecording().toImage(
        (totalW * dpr).ceil(),
        (totalH * dpr).ceil(),
      );
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      return VehicleMarkerImage(bytes!.buffer.asUint8List(), totalW, totalH);
    } finally {
      info.picture.dispose();
    }
  }

  static String _hex(Color c) =>
      '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';

  static Color _shade(Color c, double lightnessDelta) {
    final hsl = HSLColor.fromColor(c);
    return hsl
        .withLightness((hsl.lightness + lightnessDelta).clamp(0.0, 1.0))
        .toColor();
  }

  /// Sedan seen from above, nose up. viewBox 40 × 80.
  static String _carSvg(Color color) {
    final body = _hex(color);
    final dark = _hex(_shade(color, -0.18));
    final light = _hex(_shade(color, 0.18));
    return '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 40 80">
  <rect x="2.6" y="14" width="5" height="12" rx="2" fill="#1b1d21"/>
  <rect x="32.4" y="14" width="5" height="12" rx="2" fill="#1b1d21"/>
  <rect x="2.6" y="55" width="5" height="12" rx="2" fill="#1b1d21"/>
  <rect x="32.4" y="55" width="5" height="12" rx="2" fill="#1b1d21"/>
  <path d="M20 2 C29.5 2 34.2 6.5 34.6 15 L35 64 C35 73.5 30 78 20 78 C10 78 5 73.5 5 64 L5.4 15 C5.8 6.5 10.5 2 20 2 Z"
        fill="$body" stroke="$dark" stroke-width="1.2"/>
  <ellipse cx="4.2" cy="27" rx="2.6" ry="1.7" fill="$dark"/>
  <ellipse cx="35.8" cy="27" rx="2.6" ry="1.7" fill="$dark"/>
  <path d="M12.5 7 Q20 4.6 27.5 7" stroke="$light" stroke-width="1.6" fill="none" stroke-linecap="round"/>
  <path d="M9.6 24.5 Q20 19.8 30.4 24.5 L28.4 33.5 Q20 31.4 11.6 33.5 Z" fill="#1f2a37" fill-opacity="0.92"/>
  <rect x="11" y="35" width="18" height="18" rx="3.5" fill="$dark" fill-opacity="0.55"/>
  <path d="M11.6 55 Q20 57 28.4 55 L29.8 62.5 Q20 65.4 10.2 62.5 Z" fill="#1f2a37" fill-opacity="0.88"/>
  <rect x="9" y="5.2" width="5.5" height="2.4" rx="1.2" fill="#fff6d1"/>
  <rect x="25.5" y="5.2" width="5.5" height="2.4" rx="1.2" fill="#fff6d1"/>
  <rect x="9" y="74" width="5.5" height="2.2" rx="1.1" fill="#e5484d"/>
  <rect x="25.5" y="74" width="5.5" height="2.2" rx="1.1" fill="#e5484d"/>
</svg>''';
  }

  /// Panel van seen from above: short nose, long roof. viewBox 40 × 84.
  static String _vanSvg(Color color) {
    final body = _hex(color);
    final dark = _hex(_shade(color, -0.18));
    final light = _hex(_shade(color, 0.14));
    return '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 40 84">
  <rect x="2.4" y="12" width="5" height="12" rx="2" fill="#1b1d21"/>
  <rect x="32.6" y="12" width="5" height="12" rx="2" fill="#1b1d21"/>
  <rect x="2.4" y="62" width="5" height="12" rx="2" fill="#1b1d21"/>
  <rect x="32.6" y="62" width="5" height="12" rx="2" fill="#1b1d21"/>
  <path d="M10 2 Q20 0 30 2 Q35 3.5 35 10 L35 78 Q35 82 31 82 L9 82 Q5 82 5 78 L5 10 Q5 3.5 10 2 Z" fill="$body" stroke="$dark" stroke-width="1.2"/>
  <ellipse cx="3.6" cy="19" rx="2.5" ry="1.7" fill="$dark"/>
  <ellipse cx="36.4" cy="19" rx="2.5" ry="1.7" fill="$dark"/>
  <path d="M8.5 12 Q20 8.5 31.5 12 L30.5 19.5 Q20 18 9.5 19.5 Z" fill="#1f2a37" fill-opacity="0.92"/>
  <rect x="8.5" y="22" width="23" height="56" rx="3" fill="$light" fill-opacity="0.55"/>
  <line x1="20" y1="66" x2="20" y2="81" stroke="$dark" stroke-width="1"/>
  <rect x="9" y="3.4" width="5" height="2.2" rx="1.1" fill="#fff6d1"/>
  <rect x="26" y="3.4" width="5" height="2.2" rx="1.1" fill="#fff6d1"/>
  <rect x="7.5" y="79.2" width="4.5" height="2" rx="1" fill="#e5484d"/>
  <rect x="28" y="79.2" width="4.5" height="2" rx="1" fill="#e5484d"/>
</svg>''';
  }

  /// Pickup seen from above: cab up front, open load bed behind.
  /// viewBox 40 × 84.
  static String _pickupSvg(Color color) {
    final body = _hex(color);
    final dark = _hex(_shade(color, -0.18));
    final bed = _hex(_shade(color, -0.1));
    return '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 40 84">
  <rect x="2.4" y="13" width="5" height="12" rx="2" fill="#1b1d21"/>
  <rect x="32.6" y="13" width="5" height="12" rx="2" fill="#1b1d21"/>
  <rect x="2.4" y="60" width="5" height="12" rx="2" fill="#1b1d21"/>
  <rect x="32.6" y="60" width="5" height="12" rx="2" fill="#1b1d21"/>
  <path d="M20 2 C29 2 34.5 5.5 34.8 13 L35 79 Q35 82 32 82 L8 82 Q5 82 5 79 L5.2 13 C5.5 5.5 11 2 20 2 Z" fill="$body" stroke="$dark" stroke-width="1.2"/>
  <ellipse cx="4" cy="24" rx="2.5" ry="1.7" fill="$dark"/>
  <ellipse cx="36" cy="24" rx="2.5" ry="1.7" fill="$dark"/>
  <path d="M9.6 21 Q20 16.8 30.4 21 L28.8 29 Q20 27.2 11.2 29 Z" fill="#1f2a37" fill-opacity="0.92"/>
  <rect x="11" y="30" width="18" height="12" rx="3" fill="$dark" fill-opacity="0.5"/>
  <path d="M11.6 42 Q20 43.5 28.4 42 L29 46 L11 46 Z" fill="#1f2a37" fill-opacity="0.85"/>
  <rect x="8" y="48" width="24" height="31" rx="1.5" fill="$bed" stroke="$dark" stroke-width="1"/>
  <line x1="14" y1="50" x2="14" y2="77" stroke="$dark" stroke-opacity="0.5" stroke-width="0.8"/>
  <line x1="20" y1="50" x2="20" y2="77" stroke="$dark" stroke-opacity="0.5" stroke-width="0.8"/>
  <line x1="26" y1="50" x2="26" y2="77" stroke="$dark" stroke-opacity="0.5" stroke-width="0.8"/>
  <rect x="9" y="4.8" width="5.5" height="2.3" rx="1.1" fill="#fff6d1"/>
  <rect x="25.5" y="4.8" width="5.5" height="2.3" rx="1.1" fill="#fff6d1"/>
  <rect x="6.5" y="79.6" width="4.5" height="2" rx="1" fill="#e5484d"/>
  <rect x="29" y="79.6" width="4.5" height="2" rx="1" fill="#e5484d"/>
</svg>''';
  }

  /// Flatbed seen from above: cab up front, open deck with slats.
  /// viewBox 40 × 100.
  static String _flatbedSvg(Color color) {
    final body = _hex(color);
    final dark = _hex(_shade(color, -0.18));
    return '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 40 100">
  <rect x="2.4" y="10" width="5" height="11" rx="2" fill="#1b1d21"/>
  <rect x="32.6" y="10" width="5" height="11" rx="2" fill="#1b1d21"/>
  <rect x="2.4" y="68" width="5" height="11" rx="2" fill="#1b1d21"/>
  <rect x="32.6" y="68" width="5" height="11" rx="2" fill="#1b1d21"/>
  <rect x="2.4" y="82" width="5" height="11" rx="2" fill="#1b1d21"/>
  <rect x="32.6" y="82" width="5" height="11" rx="2" fill="#1b1d21"/>
  <path d="M8 3 Q20 0.5 32 3 Q35 4 35 8 L35 25 L5 25 L5 8 Q5 4 8 3 Z" fill="$body" stroke="$dark" stroke-width="1.2"/>
  <path d="M8.5 9.5 Q20 6.5 31.5 9.5 L30.5 16 Q20 14.5 9.5 16 Z" fill="#1f2a37" fill-opacity="0.92"/>
  <ellipse cx="3.6" cy="14" rx="2.4" ry="1.6" fill="$dark"/>
  <ellipse cx="36.4" cy="14" rx="2.4" ry="1.6" fill="$dark"/>
  <rect x="8.5" y="3.2" width="5" height="2.2" rx="1.1" fill="#fff6d1"/>
  <rect x="26.5" y="3.2" width="5" height="2.2" rx="1.1" fill="#fff6d1"/>
  <rect x="4" y="27" width="32" height="71" rx="1.5" fill="#a07850" stroke="#6b4f33" stroke-width="1.2"/>
  <line x1="4" y1="38" x2="36" y2="38" stroke="#6b4f33" stroke-width="0.8"/>
  <line x1="4" y1="50" x2="36" y2="50" stroke="#6b4f33" stroke-width="0.8"/>
  <line x1="4" y1="62" x2="36" y2="62" stroke="#6b4f33" stroke-width="0.8"/>
  <line x1="4" y1="74" x2="36" y2="74" stroke="#6b4f33" stroke-width="0.8"/>
  <line x1="4" y1="86" x2="36" y2="86" stroke="#6b4f33" stroke-width="0.8"/>
  <rect x="6" y="95.5" width="5" height="2" rx="1" fill="#e5484d"/>
  <rect x="29" y="95.5" width="5" height="2" rx="1" fill="#e5484d"/>
</svg>''';
  }

  /// Box truck seen from above: coloured cab up front, cargo box behind.
  /// viewBox 40 × 96.
  static String _truckSvg(Color color) {
    final body = _hex(color);
    final dark = _hex(_shade(color, -0.18));
    return '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 40 96">
  <rect x="2.4" y="10" width="5" height="11" rx="2" fill="#1b1d21"/>
  <rect x="32.6" y="10" width="5" height="11" rx="2" fill="#1b1d21"/>
  <rect x="2.4" y="64" width="5" height="11" rx="2" fill="#1b1d21"/>
  <rect x="32.6" y="64" width="5" height="11" rx="2" fill="#1b1d21"/>
  <rect x="2.4" y="78" width="5" height="11" rx="2" fill="#1b1d21"/>
  <rect x="32.6" y="78" width="5" height="11" rx="2" fill="#1b1d21"/>
  <path d="M8 3 Q20 0.5 32 3 Q35 4 35 8 L35 25 L5 25 L5 8 Q5 4 8 3 Z" fill="$body" stroke="$dark" stroke-width="1.2"/>
  <path d="M8.5 9.5 Q20 6.5 31.5 9.5 L30.5 16 Q20 14.5 9.5 16 Z" fill="#1f2a37" fill-opacity="0.92"/>
  <ellipse cx="3.6" cy="14" rx="2.4" ry="1.6" fill="$dark"/>
  <ellipse cx="36.4" cy="14" rx="2.4" ry="1.6" fill="$dark"/>
  <rect x="8.5" y="3.2" width="5" height="2.2" rx="1.1" fill="#fff6d1"/>
  <rect x="26.5" y="3.2" width="5" height="2.2" rx="1.1" fill="#fff6d1"/>
  <rect x="4" y="27" width="32" height="67" rx="2.5" fill="#eef1f5" stroke="#9aa3ae" stroke-width="1.2"/>
  <rect x="4" y="27" width="32" height="6" rx="2" fill="$body" fill-opacity="0.9"/>
  <line x1="20" y1="35" x2="20" y2="92" stroke="#c9d0d8" stroke-width="1"/>
  <rect x="6" y="91.5" width="5" height="2" rx="1" fill="#e5484d"/>
  <rect x="29" y="91.5" width="5" height="2" rx="1" fill="#e5484d"/>
</svg>''';
  }
}
