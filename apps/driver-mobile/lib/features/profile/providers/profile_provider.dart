import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/supabase_client.dart';
import '../../../shared/mock/mock_driver.dart';
import '../../auth/providers/auth_provider.dart';

/// Real driver profile loaded from `profiles` (via AuthService) and `drivers`.
///
/// Returns null when the authenticated profile has no drivers row. The router
/// sends that case to /driver-onboarding instead of /home.
final driverProfileStateProvider =
    AsyncNotifierProvider<DriverProfileNotifier, DriverProfile?>(
      DriverProfileNotifier.new,
    );

class DriverProfileNotifier extends AsyncNotifier<DriverProfile?> {
  @override
  Future<DriverProfile?> build() async {
    final auth = ref.watch(authProvider);
    final user = auth.currentUser;
    if (!auth.isAuthenticated || user == null) return null;

    final client = ref.watch(supabaseProvider);
    final row = await client
        .from('drivers')
        .select(
          'id, rating, total_trips, verification_status, home_city_id, '
          'current_vehicle_id',
        )
        .eq('id', user.id)
        .maybeSingle();

    if (row == null) return null;

    return DriverProfile(
      id: user.id,
      fullName: user.fullName.isEmpty ? 'SafeShift driver' : user.fullName,
      phone: user.phone,
      email: user.email,
      rating: (row['rating'] as num?)?.toDouble() ?? 0,
      completedTrips: (row['total_trips'] as num?)?.toInt() ?? 0,
      verified: row['verification_status'] == 'verified',
      vehicleClass: '—',
      zone: 'Tanzania',
    );
  }

  /// Kept for the Phase 9 complete-profile form. Phase 8 never fabricates a
  /// drivers row from the client.
  void setProfile(DriverProfile profile) {
    state = AsyncData(profile);
  }

  Future<void> refreshProfile() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(build);
  }

  void clearProfile() {
    state = const AsyncData(null);
  }
}
