import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safeshift_shared/safeshift_shared.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('vehicle shape follows the catalogue codes', () {
    expect(vehicleMarkerKindFor('small_van'), VehicleMarkerKind.van);
    expect(vehicleMarkerKindFor('Pickup'), VehicleMarkerKind.pickup);
    expect(vehicleMarkerKindFor('medium_truck'), VehicleMarkerKind.truck);
    expect(vehicleMarkerKindFor('Refrigerated truck'), VehicleMarkerKind.truck);
    expect(vehicleMarkerKindFor('flatbed'), VehicleMarkerKind.flatbed);
    expect(vehicleMarkerKindFor(null), VehicleMarkerKind.car);
  });

  for (final kind in VehicleMarkerKind.values) {
    testWidgets('renders a ${kind.name} marker PNG at 3x', (tester) async {
      final image = await tester.runAsync(
        () => VehicleMarkers.render(
          kind: kind,
          color: const Color(0xFF00A86B),
          devicePixelRatio: 3,
        ),
      );
      expect(image, isNotNull);
      // PNG signature.
      expect(image!.png.sublist(0, 4), [0x89, 0x50, 0x4E, 0x47]);
      expect(image.height, greaterThan(image.width));
      final codec = await tester.runAsync(
        () => ui.instantiateImageCodec(image.png),
      );
      final frame = await tester.runAsync(() => codec!.getNextFrame());
      expect(frame!.image.width, (image.width * 3).ceil());
      expect(frame.image.height, (image.height * 3).ceil());
    });
  }

  testWidgets('renders are cached per kind, colour and density', (tester) async {
    final a = VehicleMarkers.render(
      color: Colors.black,
      devicePixelRatio: 2,
    );
    final b = VehicleMarkers.render(
      color: Colors.black,
      devicePixelRatio: 2,
    );
    expect(identical(a, b), isTrue);
    await tester.runAsync(() => a);
  });

  testWidgets('glide moves smoothly and turns toward travel', (tester) async {
    var frames = 0;
    late MarkerGlide glide;
    await tester.pumpWidget(
      _GlideHost(onReady: (vsync) {
        glide = MarkerGlide(vsync: vsync, onFrame: () => frames++);
      }),
    );
    glide.update((lat: -6.8, lng: 39.27), animate: false);
    expect(glide.position, (lat: -6.8, lng: 39.27));
    // ~110 m east.
    glide.update((lat: -6.8, lng: 39.271));
    // The first fix gap is ~0 s here, so the glide uses its 600 ms minimum.
    await tester.pump();
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }
    final mid = glide.position!;
    expect(mid.lng, greaterThan(39.27));
    expect(mid.lng, lessThan(39.271));
    expect(glide.bearing, greaterThan(0));
    await tester.pump(const Duration(seconds: 5));
    expect(glide.position!.lng, closeTo(39.271, 1e-9));
    expect(glide.bearing, closeTo(90, 0.5));
    expect(frames, greaterThan(3));
    glide.dispose();
  });
}

class _GlideHost extends StatefulWidget {
  const _GlideHost({required this.onReady});
  final void Function(TickerProvider vsync) onReady;
  @override
  State<_GlideHost> createState() => _GlideHostState();
}

class _GlideHostState extends State<_GlideHost>
    with SingleTickerProviderStateMixin {
  @override
  void initState() {
    super.initState();
    widget.onReady(this);
  }

  @override
  Widget build(BuildContext context) => const SizedBox();
}
