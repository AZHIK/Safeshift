// Mock driver user for the auth flow. Demo only.
class MockUser {
  const MockUser({
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

const MockUser mockUser = MockUser(
  id: 'driver-001',
  fullName: 'Baraka Mwansa',
  phone: '+255713456789',
  email: 'baraka.mwansa@example.com',
);
