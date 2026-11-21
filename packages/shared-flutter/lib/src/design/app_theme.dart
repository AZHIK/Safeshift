import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'text_styles.dart';
import 'tokens.dart';

/// Material themes shared by both SafeShift mobile apps.
abstract final class AppTheme {
  static final lightTheme = _build(Brightness.light);
  static final darkTheme = _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final scheme = ColorScheme.fromSeed(
      seedColor: SafeShiftColors.primary,
      brightness: brightness,
      primary: dark ? const Color(0xFF94C9FF) : SafeShiftColors.primaryDark,
      onPrimary: dark ? const Color(0xFF072E53) : Colors.white,
      primaryContainer: dark
          ? const Color(0xFF203B55)
          : const Color(0xFFE3F0FE),
      onPrimaryContainer: dark
          ? const Color(0xFFD5EAFF)
          : const Color(0xFF104775),
      secondary: dark ? const Color(0xFF83DCB7) : const Color(0xFF176449),
      onSecondary: dark ? const Color(0xFF073B2A) : Colors.white,
      secondaryContainer: dark
          ? const Color(0xFF1A3B31)
          : const Color(0xFFE4F4EB),
      onSecondaryContainer: dark
          ? const Color(0xFFABE9CA)
          : const Color(0xFF15563D),
      tertiary: dark ? const Color(0xFFF2C36B) : const Color(0xFF805300),
      onTertiary: dark ? const Color(0xFF402C05) : Colors.white,
      error: dark ? const Color(0xFFFFB4AB) : const Color(0xFFAD2929),
      surface: dark ? const Color(0xFF1A232D) : SafeShiftColors.surface,
      surfaceContainerLow: dark
          ? const Color(0xFF18212C)
          : const Color(0xFFF1F5FA),
      surfaceContainer: dark
          ? const Color(0xFF202B37)
          : const Color(0xFFECF1F7),
      surfaceContainerHigh: dark
          ? const Color(0xFF263340)
          : const Color(0xFFE5ECF4),
      surfaceContainerHighest: dark
          ? const Color(0xFF303E4C)
          : const Color(0xFFDFE7F0),
      onSurface: dark ? const Color(0xFFE5EDF5) : SafeShiftColors.textPrimary,
      onSurfaceVariant: dark
          ? const Color(0xFFB3C0CF)
          : const Color(0xFF526479),
      outlineVariant: dark ? const Color(0xFF41505F) : SafeShiftColors.divider,
    );
    final overlay =
        (dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark)
            .copyWith(
              statusBarColor: Colors.transparent,
              systemNavigationBarColor: scheme.surface,
              systemNavigationBarIconBrightness: dark
                  ? Brightness.light
                  : Brightness.dark,
            );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: dark
          ? const Color(0xFF101820)
          : SafeShiftColors.background,
      dividerColor: scheme.outlineVariant,
      fontFamily: TextStyles.fontFamily,
      appBarTheme: AppBarTheme(
        systemOverlayStyle: overlay,
        backgroundColor: Colors.transparent,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(54),
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          elevation: 8,
          shadowColor: scheme.primary.withValues(alpha: 0.4),
          textStyle: TextStyles.button,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
      cardTheme: CardThemeData(
        color: scheme.surface,
        elevation: 8,
        shadowColor: scheme.shadow.withValues(alpha: dark ? 0.24 : 0.08),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(color: scheme.outlineVariant, width: 0.8),
        ),
        margin: EdgeInsets.zero,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surface,
        indicatorColor: scheme.primaryContainer,
        elevation: 12,
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? scheme.primary
                : scheme.onSurfaceVariant,
            size: 20,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyles.caption.copyWith(
            color: states.contains(WidgetState.selected)
                ? scheme.primary
                : scheme.onSurfaceVariant,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        selectedColor: scheme.primaryContainer,
        backgroundColor: scheme.surface,
        side: BorderSide(color: scheme.outlineVariant),
        labelStyle: TextStyles.caption.copyWith(fontWeight: FontWeight.w700),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        hintStyle: TextStyles.body.copyWith(color: scheme.onSurfaceVariant),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: scheme.primary, width: 1.6),
        ),
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyles.display,
        headlineMedium: TextStyles.headline,
        headlineLarge: TextStyles.display,
        titleMedium: TextStyles.title,
        titleLarge: TextStyles.title,
        bodyLarge: TextStyles.body,
        bodyMedium: TextStyles.body,
        bodySmall: TextStyles.caption,
        labelLarge: TextStyles.button,
        labelSmall: TextStyles.overline,
      ),
    );
  }
}
