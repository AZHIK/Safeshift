// Planned: add dark theme color variants in a later sprint.
import 'package:flutter/material.dart';

/// SafeShift brand colors for the Driver app.
/// Soft gray-ink palette: charcoal-gray text, light gray map.
/// Nothing uses deep/pure black.
abstract final class AppColors {
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
  static const Color cardBackground = Color(0xFFFFFFFF);
  static const Color transparent = Color(0x00000000);

  // Driver online/offline toggle (Bolt-style).
  static const Color onlineGreen = Color(0xFF00C853);
  static const Color offlineGray = Color(0xFF9E9E9E);

  // Light gray map tones (no dark background).
  static const Color mapNight = Color(0xFFE4EAF1);
  static const Color mapNightSoft = Color(0xFFD4DFEA);
  static const Color mapGrid = Color(0xFFAEBFCE);

  static const LinearGradient brandGradient = LinearGradient(
    colors: [Color(0xFF0B63D6), Color(0xFF2E9BFF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient heroGradient = LinearGradient(
    colors: [Color(0xFF4E5E73), Color(0xFF7A8DA3), Color(0xFF2E9BFF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient limeGradient = LinearGradient(
    colors: [Color(0xFFC6F135), Color(0xFF8FE000)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static List<BoxShadow> get cardShadow => const [
    BoxShadow(
      color: Color(0x144E5E73),
      blurRadius: 16,
      offset: Offset(0, 8),
    ),
  ];

  static List<BoxShadow> get glowShadow => const [
    BoxShadow(
      color: Color(0x662E9BFF),
      blurRadius: 24,
      offset: Offset(0, 8),
    ),
  ];
}
