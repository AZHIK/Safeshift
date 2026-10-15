import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';

class MapView extends StatelessWidget {
  const MapView({super.key});

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => Container(
      width: double.infinity,
      color: const Color(0xFFEAF0F3),
      child: Stack(
        children: <Widget>[
          const Center(
            child: Text(
              'Map view — coming soon',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          CustomPaint(
            size: Size(constraints.maxWidth, constraints.maxHeight),
            painter: _MockRoutePainter(),
          ),
          const Positioned(
            left: 34,
            bottom: 34,
            child: _MapMarker(
              icon: Icons.trip_origin_rounded,
              color: AppColors.success,
            ),
          ),
          const Positioned(
            right: 44,
            top: 45,
            child: _MapMarker(
              icon: Icons.location_on_rounded,
              color: AppColors.error,
            ),
          ),
          const Positioned(
            left: 130,
            top: 95,
            child: _MapMarker(
              icon: Icons.local_shipping_rounded,
              color: AppColors.primaryDark,
              filled: true,
            ),
          ),
        ],
      ),
    ),
  );
}

class _MapMarker extends StatelessWidget {
  const _MapMarker({
    required this.icon,
    required this.color,
    this.filled = false,
  });
  final IconData icon;
  final Color color;
  final bool filled;
  @override
  Widget build(BuildContext context) => Container(
    width: 38,
    height: 38,
    decoration: BoxDecoration(
      color: filled ? Colors.white : Colors.white.withValues(alpha: 0.9),
      shape: BoxShape.circle,
      boxShadow: const <BoxShadow>[
        BoxShadow(
          color: Color(0x22000000),
          blurRadius: 8,
          offset: Offset(0, 2),
        ),
      ],
    ),
    child: Icon(icon, color: color, size: 21),
  );
}

class _MockRoutePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.primaryDark
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;
    const dash = 8.0;
    const gap = 6.0;
    final start = Offset(60, size.height - 52);
    final end = Offset(size.width - 62, 64);
    final control = Offset(size.width * 0.48, size.height * 0.45);
    final path = Path()
      ..moveTo(start.dx, start.dy)
      ..quadraticBezierTo(control.dx, control.dy, end.dx, end.dy);
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        canvas.drawPath(metric.extractPath(distance, distance + dash), paint);
        distance += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
