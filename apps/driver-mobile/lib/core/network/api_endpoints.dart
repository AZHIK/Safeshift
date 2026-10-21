// Planned: replace placeholder paths with the finalized backend API contract.
abstract final class ApiEndpoints {
  static const String sendOtp = '/auth/otp/send';
  static const String verifyOtp = '/auth/otp/verify';
  static const String refreshToken = '/auth/refresh';
  static const String currentUser = '/auth/me';
  static const String quote = '/quotes';
  static const String jobs = '/jobs';
  static const String jobById = '/jobs/{id}';
  static const String drivers = '/drivers';
  static const String driverLocation = '/drivers/{id}/location';
  static const String payments = '/payments';
  static const String deliveryEvidence = '/jobs/{id}/delivery-evidence';
}
