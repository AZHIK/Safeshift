import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/theme/text_styles.dart';
import '../../../../core/widgets/buttons/primary_button.dart';
import '../../data/models/onboarding_slide_model.dart';
import '../../providers/onboarding_provider.dart';
import '../widgets/onboarding_page.dart';
import '../widgets/page_indicator.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentIndex = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _complete() async {
    await ref.read(onboardingProvider.notifier).completeOnboarding();
    if (mounted) context.go('/login');
  }

  void _continue() {
    if (_currentIndex < onboardingSlides.length - 1) {
      _pageController.animateToPage(
        _currentIndex + 1,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    } else {
      _complete();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSizes.screenPadding,
            AppSizes.sm,
            AppSizes.screenPadding,
            AppSizes.md,
          ),
          child: Column(
            children: [
              SizedBox(
                height: 44,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'SafeShift',
                      style: TextStyles.title.copyWith(
                        color: AppColors.primary,
                        fontSize: 20,
                      ),
                    ),
                    if (_currentIndex < onboardingSlides.length - 1)
                      TextButton(
                        onPressed: _complete,
                        child: Text(
                          'Skip',
                          style: TextStyles.title.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      )
                    else
                      const SizedBox(width: 56),
                  ],
                ),
              ),
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: onboardingSlides.length,
                  onPageChanged: (index) =>
                      setState(() => _currentIndex = index),
                  itemBuilder: (context, index) => OnboardingPage(
                    key: ValueKey<int>(index),
                    slide: onboardingSlides[index],
                  ),
                ),
              ),
              PageIndicator(currentIndex: _currentIndex),
              const SizedBox(height: AppSizes.lg),
              PrimaryButton(
                label: _currentIndex == onboardingSlides.length - 1
                    ? 'Get Started'
                    : 'Next',
                onPressed: _continue,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
