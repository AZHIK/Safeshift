// TODO: add action snackbars (undo/retry) in a later sprint.
import 'package:flutter/material.dart';

/// Static helper for showing snackbars. Placeholder styling only.
abstract final class AppSnackbar {
  static void showSuccess(BuildContext context, String message) {
    _show(context, message, Colors.green);
  }

  static void showError(BuildContext context, String message) {
    _show(context, message, Colors.red);
  }

  static void showInfo(BuildContext context, String message) {
    _show(context, message, Colors.blue);
  }

  static void _show(BuildContext context, String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color),
    );
  }
}
