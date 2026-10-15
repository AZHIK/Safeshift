import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/theme/text_styles.dart';
import '../../domain/entities/onboarding_slide.dart';
import 'animated_text_reveal.dart';

/// Clean light illustration on white — animation floats with no card
/// behind it, ink text below. [pageOffset] drives subtle parallax.
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
          // Bare animation — no card. The badge sits below in its own
          // layout space (never overlaid), so it can't touch the art
          // even when artScale overflows the box.
          Transform.translate(
            offset: Offset(parallax, 0),
            child: SizedBox(
              height: illustrationHeight,
              width: double.infinity,
              child: TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0.94, end: 1),
                duration: const Duration(milliseconds: 450),
                curve: Curves.easeOutCubic,
                builder: (context, scale, child) => Opacity(
                  opacity: ((scale - 0.94) / 0.06).clamp(0, 1),
                  child: Transform.scale(
                    scale: scale * slide.artScale,
                    child: child,
                  ),
                ),
                child: Lottie.asset(
                  slide.lottieAsset,
                  fit: BoxFit.contain,
                  repeat: true,
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          // Badge pill with guaranteed clearance below the animation.
          Transform.translate(
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
