// TODO: tighten rules for Tanzanian phone formats (+255...) and add cargo/
// address validators in a later sprint.
abstract final class Validators {
  static bool isValidPhone(String value) {
    return value.trim().length >= 9;
  }

  static bool isValidEmail(String value) {
    return RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(value.trim());
  }

  static bool isNotEmpty(String? value) {
    return value != null && value.trim().isNotEmpty;
  }
}
