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
    this.artScale = 1.0,
  });

  final String title;
  final String description;
  final String lottieAsset;
  final Color accentColor;
  final String badgeLabel;
  final IconData badgeIcon;
  final Color glow;
  /// Per-artwork scale. The truck file has wide transparent margins in its
  /// 1200x1200 canvas, so it renders small — bump it to match the others.
  final double artScale;
}
