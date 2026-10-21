// Planned: convert to a @freezed class with json_serializable and run
// build_runner in a later sprint. Manual stubs below unblock the mock UI phase.
import '../../domain/entities/user.dart';

/// Placeholder data model mirroring [User].
class UserModel {
  const UserModel({
    required this.id,
    required this.phone,
    required this.fullName,
    required this.role,
  });

  final String id;
  final String phone;
  final String fullName;
  final String role;

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      fullName: json['full_name'] as String? ?? '',
      role: json['role'] as String? ?? 'customer',
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'phone': phone,
      'full_name': fullName,
      'role': role,
    };
  }

  User toEntity() {
    return User(id: id, phone: phone, fullName: fullName, role: role);
  }
}
