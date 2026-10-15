// TODO: add loading/error/empty variants during the mock UI phase.
import 'package:flutter/material.dart';

import '../../constants/app_colors.dart';

/// Reusable premium card with soft layered shadow and optional glow border.
class InfoCard extends StatelessWidget {
  const InfoCard({
    super.key,
    required this.child,
    this.padding = 18,
    this.radius = 22,
    this.selected = false,
  });

  final Widget child;
  final double padding;
  final double radius;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.all(Radius.circular(radius)),
        border: Border.all(
          color: selected ? AppColors.primary : AppColors.divider,
          width: selected ? 1.6 : 0.9,
        ),
        boxShadow: AppColors.cardShadow,
      ),
      child: child,
    );
  }
}
