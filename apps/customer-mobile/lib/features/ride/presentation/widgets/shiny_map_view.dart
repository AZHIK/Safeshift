import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../providers/ride_provider.dart';

/// Light gray "Bolt-style" map. Pure Canvas (no API key needed):
/// soft gray gradient, subtle grid, blue route + pins.
class ShinyMapView extends StatefulWidget {
  const ShinyMapView({super.key, required this.state});

  final RideState state;

  @override
  State<ShinyMapView> createState() => _ShinyMapViewState();
}

class _ShinyMapViewState extends State<ShinyMapView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, _) => Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF2F6FB), Color(0xFFE2EAF3), Color(0xFFD5E1EE)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _MapGridPainter(),
              ),
            ),
            // Soft blue tint orb for depth (no green tint).
            const Positioned(
              left: -70,
              top: -50,
              child: _GlowOrb(size: 230, color: Color(0x332E9BFF)),
            ),
            const Positioned(
              left: 40,
              bottom: 120,
              child: _GlowOrb(size: 200, color: Color(0x220B63D6)),
            ),
            if (widget.state.hasRoute)
              Positioned.fill(
                child: CustomPaint(
                  painter: _GlowingRoutePainter(progress: 1),
                ),
              ),
            // Animated truck marker along the route.
            if (widget.state.hasRoute ||
                widget.state.stage == RideStage.tracking ||
                widget.state.stage == RideStage.searching)
              Positioned(
                left: _truckX(context),
                top: _truckY(context),
                child: _TruckMarker(pulse: _pulse.value),
              ),
            if (widget.state.hasRoute)
              const Positioned(left: 36, bottom: 250, child: _PinDot.pickup()),
            if (widget.state.hasRoute)
              const Positioned(right: 52, top: 150, child: _PinDot.drop()),
            // Route chip.
            if (widget.state.hasRoute)
              Positioned(
                left: 0,
                right: 0,
                top: 108,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.94),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: AppColors.divider,
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x144E5E73),
                          blurRadius: 14,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Text(
                      '${widget.state.distanceKm.toStringAsFixed(1)} km  ·  ${widget.state.durationMin} min  ·  ${widget.state.etaMin} min away',
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  double _truckX(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    final t = 0.45 + 0.12 * math.sin(_pulse.value * math.pi * 2);
    return w * t;
  }

  double _truckY(BuildContext context) {
    final h = MediaQuery.sizeOf(context).height * 0.42;
    final t = 0.48 + 0.08 * math.cos(_pulse.value * math.pi * 2);
    return h * t + 60;
  }
}

class _GlowOrb extends StatelessWidget {
  const _GlowOrb({required this.size, required this.color});
  final double size;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: RadialGradient(colors: [color, Colors.transparent]),
    ),
  );
}

class _PinDot extends StatelessWidget {
  const _PinDot.pickup()
    : color = const Color(0xFF34D17B),
      icon = Icons.trip_origin_rounded;
  const _PinDot.drop()
    : color = const Color(0xFFFF5A5A),
      icon = Icons.location_on_rounded;
  final Color color;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Container(
    width: 44,
    height: 44,
    decoration: BoxDecoration(
      color: Colors.white,
      shape: BoxShape.circle,
      boxShadow: [
        BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 18),
      ],
    ),
    child: Icon(icon, color: color, size: 24),
  );
}

class _TruckMarker extends StatelessWidget {
  const _TruckMarker({required this.pulse});
  final double pulse;
  @override
  Widget build(BuildContext context) {
    final ring = 34 + pulse * 22;
    return SizedBox(
      width: 72,
      height: 72,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: ring,
            height: ring,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary.withValues(
                alpha: (0.32 * (1 - pulse)).clamp(0.0, 0.4),
              ),
            ),
          ),
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              gradient: AppColors.brandGradient,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: AppColors.glowShadow,
            ),
            child: const Icon(
              Icons.local_shipping_rounded,
              color: Colors.white,
              size: 26,
            ),
          ),
        ],
      ),
    );
  }
}

class _MapGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..color = AppColors.mapGrid.withValues(alpha: 0.35)
      ..strokeWidth = 1;
    for (var x = 0.0; x < size.width; x += 34) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), line);
    }
    for (var y = 0.0; y < size.height; y += 34) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), line);
    }
    // Fake roads.
    final road = Paint()
      ..color = Colors.white.withValues(alpha: 0.9)
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(0, size.height * 0.32),
      Offset(size.width, size.height * 0.42),
      road,
    );
    canvas.drawLine(
      Offset(size.width * 0.2, 0),
      Offset(size.width * 0.34, size.height),
      road,
    );
    final road2 = Paint()
      ..color = AppColors.mapNightSoft.withValues(alpha: 0.8)
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(0, size.height * 0.62),
      Offset(size.width, size.height * 0.55),
      road2,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _GlowingRoutePainter extends CustomPainter {
  _GlowingRoutePainter({required this.progress});
  final double progress;
  @override
  void paint(Canvas canvas, Size size) {
    final start = Offset(58, size.height - 268);
    final end = Offset(size.width - 74, 168);
    final ctrl = Offset(size.width * 0.52, size.height * 0.45);
    final path = Path()
      ..moveTo(start.dx, start.dy)
      ..quadraticBezierTo(ctrl.dx, ctrl.dy, end.dx, end.dy);

    // Outer glow.
    for (final w in [14.0, 8.0]) {
      canvas.drawPath(
        path,
        Paint()
          ..color = AppColors.primary.withValues(alpha: w > 10 ? 0.18 : 0.32)
          ..strokeWidth = w
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round,
      );
    }
    // Core dashed route line — darker blue for contrast on light gray.
    final dashPath = Path();
    for (final m in path.computeMetrics()) {
      var d = 0.0;
      while (d < m.length * progress) {
        dashPath.addPath(m.extractPath(d, d + 9), Offset.zero);
        d += 15;
      }
    }
    canvas.drawPath(
      dashPath,
      Paint()
        ..color = AppColors.primaryDark
        ..strokeWidth = 3.4
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _GlowingRoutePainter old) =>
      old.progress != progress;
}
