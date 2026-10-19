import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../shared/mock/mock_jobs.dart';
import '../../domain/entities/driver_status.dart';

/// Stylized map placeholder: light gray background with grid lines and
/// pins for pickup (green), destination (red), and the driver (car).
/// google_maps_flutter is intentionally unused in this mock phase.
class MapPlaceholder extends StatelessWidget {
  const MapPlaceholder({super.key, required this.status, this.job});

  final DriverStatus status;
  final DriverJob? job;

  bool get _showJobPins =>
      status.hasActiveJob || status == DriverStatus.incomingJob;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.mapNight,
      child: Stack(
        children: [
          const Positioned.fill(child: CustomPaint(painter: _MapGridPainter())),
          // Zone label.
          Positioned(
            top: MediaQuery.paddingOf(context).top + 12,
            left: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: AppColors.divider),
                boxShadow: AppColors.cardShadow,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.my_location_rounded,
                    size: 14,
                    color: status == DriverStatus.offline
                        ? AppColors.offlineGray
                        : AppColors.onlineGreen,
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    'Kinondoni · Dar es Salaam',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_showJobPins && job != null) ...[
            const Positioned(
              top: 140,
              left: 70,
              child: _MapPin(
                icon: Icons.location_on_rounded,
                color: AppColors.onlineGreen,
                label: 'Pickup',
              ),
            ),
            const Positioned(
              bottom: 320,
              right: 60,
              child: _MapPin(
                icon: Icons.flag_rounded,
                color: AppColors.error,
                label: 'Drop-off',
              ),
            ),
            const Positioned(
              top: 260,
              left: 160,
              child: _DriverMarker(),
            ),
            // Fake route line between pins.
            Positioned.fill(
              child: CustomPaint(
                painter: _RoutePainter(),
              ),
            ),
          ] else
            const Center(
              child: _DriverMarker(),
            ),
        ],
      ),
    );
  }
}

class _MapPin extends StatelessWidget {
  const _MapPin({required this.icon, required this.color, required this.label});

  final IconData icon;
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2.5),
            boxShadow: AppColors.cardShadow,
          ),
          child: Icon(icon, size: 18, color: Colors.white),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: AppColors.divider),
          ),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}

class _DriverMarker extends StatelessWidget {
  const _DriverMarker();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.primaryDark,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: AppColors.glowShadow,
      ),
      child: const Icon(
        Icons.local_shipping_rounded,
        size: 24,
        color: Colors.white,
      ),
    );
  }
}

class _MapGridPainter extends CustomPainter {
  const _MapGridPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..color = AppColors.mapGrid.withValues(alpha: 0.5)
      ..strokeWidth = 1;
    const step = 44.0;
    for (var x = 0.0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), line);
    }
    for (var y = 0.0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), line);
    }
    // A couple of fake "roads".
    final road = Paint()
      ..color = Colors.white.withValues(alpha: 0.9)
      ..strokeWidth = 10
      ..style = PaintingStyle.stroke;
    canvas.drawLine(
      Offset(0, size.height * 0.35),
      Offset(size.width, size.height * 0.45),
      road,
    );
    canvas.drawLine(
      Offset(size.width * 0.3, 0),
      Offset(size.width * 0.4, size.height),
      road,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _RoutePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.primaryDark
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke;
    final path = Path()
      ..moveTo(90, 170)
      ..quadraticBezierTo(
        size.width * 0.5,
        size.height * 0.45,
        size.width - 100,
        size.height - 340,
      );
    canvas.drawPath(
      path,
      paint
        ..color = AppColors.primaryDark.withValues(alpha: 0.65),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
