import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import '../../../../core/constants/app_sizes.dart';
import '../../../../core/theme/text_styles.dart';
import '../../domain/entities/onboarding_slide.dart';
import 'animated_text_reveal.dart';

class OnboardingPage extends StatelessWidget {
  const OnboardingPage({super.key, required this.slide});

  final OnboardingSlide slide;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return LayoutBuilder(
      builder: (context, _) {
        final illustrationHeight = size.height * 0.42;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSizes.xl),
          child: Column(
            children: [
              SizedBox(
                height: illustrationHeight,
                width: double.infinity,
                child: TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0.92, end: 1),
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.easeOutBack,
                  builder: (context, scale, child) => Opacity(
                    opacity: ((scale - 0.92) / 0.08).clamp(0, 1),
                    child: Transform.scale(scale: scale, child: child),
                  ),
                  child: Lottie.asset(
                    slide.lottieAsset,
                    fit: BoxFit.contain,
                    repeat: true,
                  ),
                ),
              ),
              const SizedBox(height: AppSizes.lg),
              AnimatedTextReveal(
                child: Text(
                  slide.title,
                  textAlign: TextAlign.center,
                  style: TextStyles.headline.copyWith(color: slide.accentColor),
                ),
              ),
              const SizedBox(height: AppSizes.md),
              AnimatedTextReveal(
                delay: const Duration(milliseconds: 300),
                child: Text(
                  slide.description,
                  textAlign: TextAlign.center,
                  style: TextStyles.body.copyWith(fontSize: 16),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
