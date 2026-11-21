import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safeshift_shared/safeshift_shared.dart';

double contrast(Color foreground, Color background) {
  final a = foreground.computeLuminance();
  final b = background.computeLuminance();
  return (math.max(a, b) + 0.05) / (math.min(a, b) + 0.05);
}

void main() {
  for (final theme in [AppTheme.lightTheme, AppTheme.darkTheme]) {
    test(
      'Text and status colors are legible in ${theme.brightness.name} mode',
      () {
        final colors = theme.colorScheme;
        final pairs = [
          (colors.onSurface, colors.surface),
          (colors.onSurfaceVariant, theme.scaffoldBackgroundColor),
          (colors.onSurfaceVariant, colors.surfaceContainerHighest),
          (colors.onPrimary, colors.primary),
          (colors.onError, colors.error),
          (colors.onSecondary, colors.secondary),
          for (final tint in [
            colors.primary,
            colors.secondary,
            colors.tertiary,
            colors.error,
          ])
            (
              tint,
              Color.alphaBlend(tint.withValues(alpha: 0.12), colors.surface),
            ),
          for (final stop in SafeShiftColors.brandGradient.colors)
            (Colors.white, stop),
        ];
        for (final (foreground, background) in pairs) {
          expect(
            contrast(foreground, background),
            greaterThanOrEqualTo(4.5),
            reason: '$foreground on $background',
          );
        }
      },
    );
  }
}
