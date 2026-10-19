import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';

/// Quiet progress pills for white onboarding. Active pill uses brand
/// gradient, inactive pills are light grey.
class PageIndicator extends StatelessWidget {
  const PageIndicator({super.key, required this.currentIndex, this.count = 3});

  final int currentIndex;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List<Widget>.generate(count, (index) {
        final active = index == currentIndex;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeInOut,
          width: active ? 32 : 8,
          height: 8,
          margin: const EdgeInsets.symmetric(horizontal: AppSizes.xs),
          decoration: BoxDecoration(
            gradient: active ? AppColors.brandGradient : null,
            color: active ? null : AppColors.divider,
            borderRadius: BorderRadius.circular(AppSizes.radiusFull),
          ),
        );
      }),
    );
  }
}
