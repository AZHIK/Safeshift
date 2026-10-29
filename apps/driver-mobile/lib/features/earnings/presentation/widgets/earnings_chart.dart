import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../home/data/driver_repository.dart';

/// Custom bar chart (no new packages) for the last 7 days.
class EarningsChart extends StatelessWidget {
  const EarningsChart({super.key, required this.days});

  final List<DailyEarning> days;

  @override
  Widget build(BuildContext context) {
    final max = days.isEmpty
        ? 1.0
        : days.map((d) => d.amount).reduce((a, b) => a > b ? a : b).toDouble();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (final day in days)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Container(
                    height: 110 * (day.amount / (max == 0 ? 1 : max)),
                    decoration: BoxDecoration(
                      gradient: AppColors.brandGradient,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    day.day,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
