import 'package:flutter/material.dart';

import '../../domain/entities/onboarding_slide.dart';
import '../../../../core/constants/app_colors.dart';

const List<OnboardingSlide> onboardingSlides = <OnboardingSlide>[
  OnboardingSlide(
    title: 'Drive with SafeShift',
    description:
        "Join verified drivers moving people's property safely.",
    lottieAsset: 'assets/lottie/onboarding_drive.json',
    accentColor: AppColors.primary,
    badgeLabel: 'Verified drivers',
    badgeIcon: Icons.verified_rounded,
    glow: Color(0x552E9BFF),
    artScale: 1.0,
  ),
  OnboardingSlide(
    title: 'Get Jobs Nearby',
    description:
        'Go online and receive job requests from customers in your zone.',
    lottieAsset: 'assets/lottie/onboarding_jobs.json',
    accentColor: AppColors.lime,
    badgeLabel: 'Jobs in your zone',
    badgeIcon: Icons.bolt_rounded,
    glow: Color(0x44C6F135),
  ),
  OnboardingSlide(
    title: 'Track Your Earnings',
    description:
        'See every trip, every fare, and your payout — all in one place.',
    lottieAsset: 'assets/lottie/onboarding_earnings.json',
    accentColor: AppColors.glow,
    badgeLabel: 'TZS payouts',
    badgeIcon: Icons.account_balance_wallet_rounded,
    glow: Color(0x557ED7FF),
  ),
];
