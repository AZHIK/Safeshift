import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/theme/text_styles.dart';
import '../../domain/entities/onboarding_slide.dart';
import 'animated_text_reveal.dart';

/// Clean light illustration card on white. Soft shadow, ink text.
/// [pageOffset] drives subtle parallax from the PageView.
class OnboardingPage extends StatelessWidget {
  const OnboardingPage({
    super.key,
    required this.slide,
    this.pageOffset = 0,
  });

  final OnboardingSlide slide;
  final double pageOffset;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final illustrationHeight = size.height * 0.34;
    final parallax = (pageOffset * 28).clamp(-28.0, 28.0);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Column(
        children: [
          SizedBox(
            height: illustrationHeight + 26,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // White illustration card with soft professional shadow.
                Transform.translate(
                  offset: Offset(parallax, 0),
                  child: Container(
                    height: illustrationHeight,
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(
                        color: AppColors.divider,
                        width: 1,
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x144E5E73),
                          blurRadius: 28,
                          offset: Offset(0, 14),
                        ),
                      ],
                    ),
                    child: TweenAnimationBuilder<double>(
                      tween: Tween<double>(begin: 0.94, end: 1),
                      duration: const Duration(milliseconds: 450),
                      curve: Curves.easeOutCubic,
                      builder: (context, scale, child) => Opacity(
                        opacity: ((scale - 0.94) / 0.06).clamp(0, 1),
                        child:
                            Transform.scale(scale: scale, child: child),
                      ),
                      child: Lottie.asset(
                        slide.lottieAsset,
                        fit: BoxFit.contain,
                        repeat: true,
                      ),
                    ),
                  ),
                ),
                // Small badge pill overlapping the card bottom edge.
                Positioned(
                  bottom: 0,
                  child: Transform.translate(
                    offset: Offset(-parallax * 0.5, 0),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primaryDeep,
                        borderRadius: BorderRadius.circular(999),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x224E5E73),
                            blurRadius: 14,
                            offset: Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            slide.badgeIcon,
                            size: 15,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            slide.badgeLabel,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSizes.lg),
          AnimatedTextReveal(
            child: Text(
              slide.title,
              textAlign: TextAlign.center,
              style: TextStyles.display.copyWith(
                color: AppColors.textPrimary,
                fontSize: 24,
              ),
            ),
          ),
          const SizedBox(height: AppSizes.sm),
          AnimatedTextReveal(
            delay: const Duration(milliseconds: 200),
            child: Text(
              slide.description,
              textAlign: TextAlign.center,
              style: TextStyles.body.copyWith(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.55,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
