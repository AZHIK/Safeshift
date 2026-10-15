import 'package:flutter/material.dart';

class OnboardingSlide {
  const OnboardingSlide({
    required this.title,
    required this.description,
    required this.lottieAsset,
    required this.accentColor,
    this.badgeLabel = '',
    this.badgeIcon = Icons.verified_rounded,
    this.glow = const Color(0x552E9BFF),
  });

  final String title;
  final String description;
  final String lottieAsset;
  final Color accentColor;
  final String badgeLabel;
  final IconData badgeIcon;
  final Color glow;
}
