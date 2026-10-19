// TODO: add copyWith and value equality (or convert to Freezed) in a later
// sprint. Placeholder entity only.
class User {
  const User({
    required this.id,
    required this.phone,
    required this.fullName,
    required this.role,
  });

  final String id;
  final String phone;
  final String fullName;
  final String role;
}
