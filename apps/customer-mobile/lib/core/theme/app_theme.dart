// TODO: polish the dark theme with the design team during mock UI phase.
import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import 'text_styles.dart';

/// App themes for the SafeShift Customer app.
abstract final class AppTheme {
  static ThemeData get lightTheme {
    const scheme = ColorScheme(
      brightness: Brightness.light,
      primary: AppColors.primaryDark,
      onPrimary: Colors.white,
      secondary: Color(0xFF55BFA8),
      onSecondary: Colors.white,
      error: AppColors.error,
      onError: Colors.white,
      surface: AppColors.surface,
      onSurface: AppColors.textPrimary,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.background,
      dividerColor: AppColors.divider,
      fontFamily: TextStyles.fontFamily,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.textPrimary,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(54),
          backgroundColor: AppColors.primaryDark,
          foregroundColor: Colors.white,
          elevation: 8,
          shadowColor: AppColors.primary.withValues(alpha: 0.4),
          textStyle: TextStyles.button,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 8,
        shadowColor: const Color(0x144E5E73),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: const BorderSide(color: AppColors.divider, width: 0.8),
        ),
        margin: EdgeInsets.zero,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.surface.withValues(alpha: 0.92),
        indicatorColor: AppColors.primaryLight.withValues(alpha: 0.6),
        elevation: 12,
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? AppColors.primaryDark
                : AppColors.textSecondary,
            size: 20,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyles.caption.copyWith(
            color: states.contains(WidgetState.selected)
                ? AppColors.primaryDark
                : AppColors.textSecondary,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
        ),
        selectedColor: AppColors.primaryDark,
        backgroundColor: AppColors.surface,
        side: const BorderSide(color: AppColors.divider),
        labelStyle: TextStyles.caption.copyWith(fontWeight: FontWeight.w700),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        hintStyle: TextStyles.body.copyWith(color: AppColors.textDisabled),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.divider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
            color: AppColors.primary,
            width: 1.6,
          ),
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

  static ThemeData get darkTheme {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.dark,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: TextStyles.fontFamily,
      appBarTheme: const AppBarTheme(foregroundColor: AppColors.textPrimary),
      textTheme: const TextTheme(
        headlineLarge: TextStyles.headline,
        titleLarge: TextStyles.title,
        bodyLarge: TextStyles.body,
        bodySmall: TextStyles.caption,
        labelLarge: TextStyles.button,
      ),
    );
  }
}
