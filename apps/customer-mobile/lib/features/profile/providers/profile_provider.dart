import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_provider.dart';
import '../domain/entities/profile.dart';

/// Profile data comes from the authenticated `profiles` row loaded by
/// [AuthService]. No mock user is used in the real app.
final profileProvider = Provider<Profile>((ref) {
  final user = ref.watch(authProvider).currentUser;
  if (user == null) {
    return const Profile(id: '', fullName: '', phone: '', email: '');
  }
  return Profile(
    id: user.id,
    fullName: user.fullName.isEmpty ? 'SafeShift customer' : user.fullName,
    phone: user.phone,
    email: user.email,
  );
});
