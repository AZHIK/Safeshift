// Planned: implement with Supabase OTP APIs in a later sprint.
import '../entities/user.dart';

/// Auth repository contract. Placeholder only.
abstract class AuthRepository {
  Future<void> sendOtp(String phone);
  Future<User> verifyOtp(String phone, String otp);
  Future<void> signOut();
  Future<User?> currentUser();
}
