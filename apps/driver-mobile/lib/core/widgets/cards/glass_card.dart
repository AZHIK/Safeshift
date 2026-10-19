import 'dart:ui';

import 'package:flutter/material.dart';

import '../../constants/app_colors.dart';

/// Frosted-glass container used for overlays on top of the map.
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = 22,
    this.opacity = 0.86,
  });

  final Widget child;
  final EdgeInsets padding;
  final double radius;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: opacity),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.9),
              width: 1.1,
            ),
            boxShadow: AppColors.cardShadow,
          ),
          child: child,
        ),
      ),
    );
  }
}
