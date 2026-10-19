import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/theme/text_styles.dart';
import '../../../../core/widgets/buttons/primary_button.dart';
import '../../data/models/onboarding_slide_model.dart';
import '../../providers/onboarding_provider.dart';
import '../widgets/onboarding_page.dart';
import '../widgets/page_indicator.dart';

/// Clean light onboarding. White background, ink text, subtle illustration
/// card. No emojis, no dark gradients.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentIndex = 0;
  double _pageOffset = 0;

  @override
  void initState() {
    super.initState();
    _pageController.addListener(_trackOffset);
  }

  void _trackOffset() {
    if (!_pageController.hasClients) return;
    final page = _pageController.page ?? _currentIndex.toDouble();
    setState(() => _pageOffset = (page - _currentIndex).clamp(-1.0, 1.0));
  }

  @override
  void dispose() {
    _pageController
      ..removeListener(_trackOffset)
      ..dispose();
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
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeInOutCubic,
      );
    } else {
      _complete();
    }
  }

  void _back() {
    if (_currentIndex > 0) {
      _pageController.animateToPage(
        _currentIndex - 1,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final last = _currentIndex == onboardingSlides.length - 1;
    final progress = (_currentIndex + 1) / onboardingSlides.length;
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Very subtle brand tint at the top — keeps it white, not flat.
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFEAF3FD), Colors.white],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: [0.0, 0.45],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Column(
                children: [
                  // Top bar: back / brand / step / skip.
                  Row(
                    children: [
                      if (_currentIndex > 0)
                        _OutlineIcon(
                          icon: Icons.arrow_back_rounded,
                          onTap: _back,
                        )
                      else
                        const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.bolt_rounded,
                              size: 18,
                              color: AppColors.primaryDark,
                            ),
                            SizedBox(width: 6),
                            Text(
                              'safeshift',
                              style: TextStyle(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w800,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 11,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: AppColors.divider),
                        ),
                        child: Text(
                          '${_currentIndex + 1} of ${onboardingSlides.length}',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (!last)
                        GestureDetector(
                          onTap: _complete,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 13,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(color: AppColors.divider),
                            ),
                            child: const Text(
                              'Skip',
                              style: TextStyle(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w700,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Thin progress bar.
                  ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: Container(
                      height: 5,
                      color: AppColors.divider.withValues(alpha: 0.7),
                      child: AnimatedFractionallySizedBox(
                        duration: const Duration(milliseconds: 350),
                        curve: Curves.easeInOut,
                        alignment: Alignment.centerLeft,
                        widthFactor: progress,
                        child: Container(
                          decoration: const BoxDecoration(
                            gradient: AppColors.brandGradient,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: PageView.builder(
                      controller: _pageController,
                      itemCount: onboardingSlides.length,
                      onPageChanged: (index) => setState(() {
                        _currentIndex = index;
                        _pageOffset = 0;
                      }),
                      itemBuilder: (context, index) => OnboardingPage(
                        key: ValueKey<int>(index),
                        slide: onboardingSlides[index],
                        pageOffset:
                            index == _currentIndex ? _pageOffset : 0,
                      ),
                    ),
                  ),
                  PageIndicator(currentIndex: _currentIndex),
                  const SizedBox(height: 14),
                  Center(
                    child: PrimaryButton(
                      label: last ? 'Get Started' : 'Next',
                      icon: last
                          ? Icons.bolt_rounded
                          : Icons.arrow_forward_rounded,
                      onPressed: _continue,
                      pill: true,
                      width: 220,
                      glowStrength: 1.4,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    last
                        ? 'Join verified drivers across Dar es Salaam'
                        : 'Swipe to explore',
                    style: TextStyles.caption.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OutlineIcon extends StatelessWidget {
  const _OutlineIcon({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    shape: const CircleBorder(
      side: BorderSide(color: AppColors.divider),
    ),
    child: InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Icon(
          icon,
          size: 18,
          color: AppColors.textPrimary,
        ),
      ),
    ),
  );
}
