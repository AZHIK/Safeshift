import 'package:flutter/material.dart';

import '../../constants/app_colors.dart';

class StatusPill extends StatelessWidget {
  const StatusPill({super.key, required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final normalized = status.toLowerCase().replaceAll(' ', '_');
    final (label, color) = switch (normalized) {
      'completed' || 'delivered' => ('Completed', AppColors.success),
      'cancelled' || 'canceled' => ('Cancelled', AppColors.error),
      'in_progress' ||
      'in progress' ||
      'loading' ||
      'in_transit' => ('In progress', AppColors.warning),
      _ => (
        '${status[0].toUpperCase()}${status.substring(1)}',
        AppColors.primaryDark,
      ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
