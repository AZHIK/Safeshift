// Planned: load and update the profile via a repository in a later sprint.
// Reads
// the mock user for now.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/mock/mock_users.dart';
import '../domain/entities/profile.dart';

final profileProvider = Provider<Profile>((ref) {
  return Profile(
    id: mockUser.id,
    fullName: mockUser.fullName,
    phone: mockUser.phone,
    email: mockUser.email,
  );
});
