import 'package:flutter/material.dart';

import '../../constants/app_colors.dart';

class LoadingRadar extends StatefulWidget {
  const LoadingRadar({super.key, this.size = 220});
  final double size;

  @override
  State<LoadingRadar> createState() => _LoadingRadarState();
}

class _LoadingRadarState extends State<LoadingRadar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    width: widget.size,
    height: widget.size,
    child: AnimatedBuilder(
      animation: _controller,
      builder: (context, child) =>
          CustomPaint(painter: _RadarPainter(_controller.value), child: child),
      child: Center(
        child: Container(
          width: 68,
          height: 68,
          decoration: BoxDecoration(
            color: AppColors.primary,
            shape: BoxShape.circle,
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.25),
                blurRadius: 22,
                spreadRadius: 5,
              ),
            ],
          ),
          child: const Icon(
            Icons.local_shipping_rounded,
            color: Colors.white,
            size: 30,
          ),
        ),
      ),
    ),
  );
}

class _RadarPainter extends CustomPainter {
  const _RadarPainter(this.progress);
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide / 2;
    for (var i = 0; i < 3; i++) {
      final phase = (progress + i / 3) % 1;
      final paint = Paint()
        ..color = AppColors.primary.withValues(alpha: (1 - phase) * 0.2)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      canvas.drawCircle(center, radius * (0.28 + phase * 0.66), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _RadarPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
