// Planned: add variants (secondary, danger, sizes) during the mock UI phase.
import 'package:flutter/material.dart';

import '../../constants/app_colors.dart';
import '../../constants/app_sizes.dart';
import '../../theme/text_styles.dart';

/// Shiny gradient primary button with glow + disabled handling.
/// Set [pill] for fully circular sides, [width] to constrain size
/// (e.g. centered onboarding CTA), [glowStrength] to boost the halo.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.icon,
    this.compact = false,
    this.pill = false,
    this.width,
    this.glowStrength = 0.0,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? icon;
  final bool compact;
  final bool pill;
  final double? width;
  final double glowStrength;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !isLoading;
    final radius = pill ? 999.0 : 18.0;
    return Opacity(
      opacity: enabled ? 1 : 0.55,
      child: Container(
        width: width ?? double.infinity,
        height: compact ? 48 : 56,
        decoration: BoxDecoration(
          gradient: enabled
              ? AppColors.brandGradient
              : const LinearGradient(
                  colors: [Color(0xFF9DB4C8), Color(0xFFB9CBD9)],
                ),
          borderRadius: BorderRadius.circular(radius),
          // No halo by default (glowStrength 0) — flat normal button.
          // Onboarding passes glowStrength 1.4 for its glowing pill CTA.
          boxShadow: enabled && glowStrength > 0
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(
                      alpha: (0.45 * glowStrength).clamp(0.0, 0.7),
                    ),
                    blurRadius: 28 * glowStrength,
                    spreadRadius: 2 * glowStrength,
                    offset: const Offset(0, 10),
                  ),
                  BoxShadow(
                    color: Colors.white.withValues(alpha: 0.7),
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: isLoading ? null : onPressed,
            borderRadius: BorderRadius.circular(radius),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Shine sweep overlay.
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(radius),
                      gradient: LinearGradient(
                        colors: [
                          Colors.white.withValues(alpha: 0.22),
                          Colors.transparent,
                          Colors.transparent,
                          Colors.white.withValues(alpha: 0.08),
                        ],
                        stops: const [0.0, 0.28, 0.75, 1.0],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                  ),
                ),
                if (isLoading)
                  const SizedBox.square(
                    dimension: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  )
                else
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (icon != null) ...[
                        Icon(icon, size: 20, color: Colors.white),
                        const SizedBox(width: AppSizes.sm),
                      ],
                      Text(
                        label,
                        style: TextStyles.button.copyWith(color: Colors.white),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
