// TODO: add avatar, saved addresses, and payment methods in a later sprint.
// Placeholder entity only.
class Profile {
  const Profile({
    required this.id,
    required this.fullName,
    required this.phone,
    required this.email,
  });

  final String id;
  final String fullName;
  final String phone;
  final String email;
}
