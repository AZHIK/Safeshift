import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../domain/entities/onboarding_slide.dart';

const List<OnboardingSlide> onboardingSlides = <OnboardingSlide>[
  OnboardingSlide(
    title: 'Welcome to safeshift',
    description:
        "Moving people's property safely — verified drivers, right from your phone.",
    lottieAsset: 'assets/lottie/truck.lottie',
    accentColor: AppColors.primary,
    badgeLabel: 'Verified drivers',
    badgeIcon: Icons.verified_rounded,
    glow: Color(0x552E9BFF),
    artScale: 1.4,
  ),
  OnboardingSlide(
    title: 'Book in Seconds',
    description:
        'Pickup + destination, parcel details, vehicle — one transparent TZS quote. No haggling.',
    lottieAsset: 'assets/lottie/delivery_bike.lottie',
    accentColor: AppColors.lime,
    badgeLabel: 'TZS 45,000 instant quote',
    badgeIcon: Icons.bolt_rounded,
    glow: Color(0x44C6F135),
  ),
  OnboardingSlide(
    title: 'Track Every Move',
    description:
        'Live map, M-Pesa / cash / card (mock), digital proof of delivery and claims protection.',
    lottieAsset: 'assets/lottie/Global delivery.lottie',
    accentColor: AppColors.glow,
    badgeLabel: 'Live tracking',
    badgeIcon: Icons.radar_rounded,
    glow: Color(0x557ED7FF),
  ),
];
