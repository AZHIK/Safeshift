import 'package:flutter/material.dart';

class OnboardingSlide {
  const OnboardingSlide({
    required this.title,
    required this.description,
    required this.lottieAsset,
    required this.accentColor,
  });

  final String title;
  final String description;
  final String lottieAsset;
  final Color accentColor;
}
