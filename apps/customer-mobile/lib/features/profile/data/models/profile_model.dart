// TODO: convert to a @freezed class with json_serializable and run
// build_runner in a later sprint. Manual stubs below unblock the mock UI phase.
import '../../domain/entities/profile.dart';

/// Placeholder data model mirroring [Profile].
class ProfileModel {
  const ProfileModel({
    required this.id,
    required this.fullName,
    required this.phone,
    required this.email,
  });

  final String id;
  final String fullName;
  final String phone;
  final String email;

  factory ProfileModel.fromJson(Map<String, dynamic> json) {
    return ProfileModel(
      id: json['id'] as String? ?? '',
      fullName: json['full_name'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      email: json['email'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'full_name': fullName,
      'phone': phone,
      'email': email,
    };
  }

  Profile toEntity() {
    return Profile(id: id, fullName: fullName, phone: phone, email: email);
  }
}
