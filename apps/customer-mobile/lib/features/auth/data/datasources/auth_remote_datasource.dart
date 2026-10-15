// TODO: implement with Supabase (OTP send/verify, session) in a later sprint.
import '../models/user_model.dart';

/// Remote data source contract for auth. Placeholder only.
abstract class AuthRemoteDataSource {
  Future<void> sendOtp(String phone);
  Future<UserModel> verifyOtp(String phone, String otp);
  Future<void> signOut();
  Future<UserModel?> currentUser();
}
