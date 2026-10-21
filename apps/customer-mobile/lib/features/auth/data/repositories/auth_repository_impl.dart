// Planned: wire to [AuthRemoteDataSource] and map failures in a later sprint.
// Every method throws until the auth feature is implemented.
import '../../domain/entities/user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_datasource.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl(this._remoteDataSource);

  // ignore: unused_field, field reserved for the real implementation.
  final AuthRemoteDataSource _remoteDataSource;

  @override
  Future<void> sendOtp(String phone) {
    throw UnimplementedError('sendOtp is not implemented yet.');
  }

  @override
  Future<User> verifyOtp(String phone, String otp) {
    throw UnimplementedError('verifyOtp is not implemented yet.');
  }

  @override
  Future<void> signOut() {
    throw UnimplementedError('signOut is not implemented yet.');
  }

  @override
  Future<User?> currentUser() {
    throw UnimplementedError('currentUser is not implemented yet.');
  }
}
