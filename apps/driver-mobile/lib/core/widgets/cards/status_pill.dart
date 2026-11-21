import 'package:flutter/material.dart';

import '../../constants/app_colors.dart';

class StatusPill extends StatelessWidget {
  const StatusPill({super.key, required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final normalized = status.toLowerCase().replaceAll(' ', '_');
    final (label, color) = switch (normalized) {
      'completed' || 'delivered' => ('Completed', context.colors.secondary),
      'cancelled' || 'canceled' => ('Cancelled', context.colors.error),
      'in_progress' ||
      'in progress' ||
      'loading' ||
      'in_transit' => ('In progress', context.colors.tertiary),
      _ => (
        '${status[0].toUpperCase()}${status.substring(1)}',
        context.colors.primary,
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
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
