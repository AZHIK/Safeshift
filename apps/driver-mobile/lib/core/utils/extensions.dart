// Planned: add currency (TZS) and distance formatting extensions in a later
// sprint.
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

extension BuildContextX on BuildContext {
  ThemeData get theme => Theme.of(this);
  TextTheme get textTheme => Theme.of(this).textTheme;
  Size get screenSize => MediaQuery.sizeOf(this);
  double get screenWidth => MediaQuery.sizeOf(this).width;
  double get screenHeight => MediaQuery.sizeOf(this).height;
}

extension StringX on String {
  String capitalize() {
    if (isEmpty) {
      return this;
    }
    return '${this[0].toUpperCase()}${substring(1)}';
  }

  bool get isPhone => trim().length >= 9;
}

extension DateTimeX on DateTime {
  String formatShort() {
    return DateFormat('dd MMM yyyy').format(this);
  }

  String formatRelative() {
    final diff = DateTime.now().difference(this);
    if (diff.inDays > 0) {
      return '${diff.inDays}d ago';
    }
    if (diff.inHours > 0) {
      return '${diff.inHours}h ago';
    }
    if (diff.inMinutes > 0) {
      return '${diff.inMinutes}m ago';
    }
    return 'Just now';
  }
}
