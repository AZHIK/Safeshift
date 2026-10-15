// TODO: replace with the authenticated Supabase user in a later sprint. One
// sample customer profile only.

/// Minimal mock user. Kept in shared code so features stay decoupled.
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
  id: 'user-001',
  fullName: 'Neema Juma',
  phone: '+255712345678',
  email: 'neema.juma@example.com',
);
