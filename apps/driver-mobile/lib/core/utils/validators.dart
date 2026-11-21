import 'package:safeshift_shared/safeshift_shared.dart';

abstract final class Validators {
  /// True when [value] is a valid number for its country's numbering plan
  /// (local numbers are read as Tanzanian). [kind] decides whether a
  /// landline is acceptable; SMS-based uses need [PhoneKind.mobile].
  static bool isValidPhone(String value, {PhoneKind kind = PhoneKind.mobile}) {
    return checkPhone(value, kind: kind).isValid;
  }

  /// The number in E.164 form (`+255712345678`), or null when invalid.
  static String? normalizePhone(
    String value, {
    PhoneKind kind = PhoneKind.mobile,
  }) {
    return checkPhone(value, kind: kind).e164;
  }

  static bool isValidEmail(String value) {
    return RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(value.trim());
  }

  static bool isNotEmpty(String? value) {
    return value != null && value.trim().isNotEmpty;
  }
}
