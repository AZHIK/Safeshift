import 'package:flutter/material.dart';

/// SafeShift brand palette shared by the customer and driver apps.
abstract final class SafeShiftColors {
  static const Color primary = Color(0xFF2E9BFF);
  static const Color primaryDark = Color(0xFF0B63D6);
  static const Color primaryDeep = Color(0xFF4E5E73);
  static const Color primaryLight = Color(0xFFBFE4FF);
  static const Color glow = Color(0xFF7ED7FF);
  static const Color secondary = Color(0xFFFF8F00);
  static const Color lime = Color(0xFFC6F135);
  static const Color background = Color(0xFFF2F6FB);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color error = Color(0xFFD32F2F);
  static const Color success = Color(0xFF2E7D32);
  static const Color warning = Color(0xFFF9A825);
  static const Color textPrimary = Color(0xFF4E5E73);
  static const Color textSecondary = Color(0xFF6B7A8D);
  static const Color textDisabled = Color(0xFFBDBDBD);
  static const Color divider = Color(0xFFE1EBF2);
  static const Color transparent = Color(0x00000000);

  static const LinearGradient brandGradient = LinearGradient(
    colors: [primaryDark, primary],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient heroGradient = LinearGradient(
    colors: [primaryDeep, Color(0xFF7A8DA3), primary],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const List<BoxShadow> cardShadow = [
    BoxShadow(
      color: Color(0x144E5E73),
      blurRadius: 16,
      offset: Offset(0, 8),
    ),
  ];
}

/// Consistent spacing scale for padding, gaps, and margins.
abstract final class SafeShiftSpacing {
  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;
}

/// Shared corner radii.
abstract final class SafeShiftRadii {
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 20;
  static const double pill = 999;
}
