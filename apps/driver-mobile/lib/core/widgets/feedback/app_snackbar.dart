// Planned: add action snackbars (undo/retry) in a later sprint.
import 'package:flutter/material.dart';

import '../../constants/app_colors.dart';

/// Feedback colors are paired with their matching foreground.
abstract final class AppSnackbar {
  static void showSuccess(BuildContext context, String message) {
    _show(
      context,
      message,
      context.colors.secondary,
      context.colors.onSecondary,
    );
  }

  static void showError(BuildContext context, String message) {
    _show(context, message, context.colors.error, context.colors.onError);
  }

  static void showInfo(BuildContext context, String message) {
    _show(context, message, context.colors.primary, context.colors.onPrimary);
  }

  static void _show(
    BuildContext context,
    String message,
    Color color,
    Color foreground,
  ) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: TextStyle(color: foreground)),
        backgroundColor: color,
      ),
    );
  }
}
