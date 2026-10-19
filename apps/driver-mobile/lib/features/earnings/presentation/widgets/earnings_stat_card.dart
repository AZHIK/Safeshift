import 'package:flutter/material.dart';

import '../../../../core/constants/app_sizes.dart';
import '../../../../core/theme/text_styles.dart';
import '../../../../core/widgets/cards/info_card.dart';

/// Small stat card used on the earnings dashboard.
class EarningsStatCard extends StatelessWidget {
  const EarningsStatCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InfoCard(
        padding: 14,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20),
            const SizedBox(height: AppSizes.sm),
            Text(value, style: TextStyles.title.copyWith(fontSize: 15)),
            Text(label, style: TextStyles.caption),
          ],
        ),
      ),
    );
  }
}
