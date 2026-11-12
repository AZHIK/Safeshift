import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/network/supabase_client.dart';
import '../../auth/providers/auth_provider.dart';
import '../domain/entities/driver_profile.dart';

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

    // The vehicle category is a catalogue row, not a fixed label: read the
    // name and the icon of the vehicle type the driver actually operates.
    final vehicle = await _currentVehicleType(
      client,
      row['current_vehicle_id'] as String?,
    );

    return DriverProfile(
      id: user.id,
      fullName: user.fullName.isEmpty ? 'SafeShift driver' : user.fullName,
      phone: user.phone,
      email: user.email,
      rating: (row['rating'] as num?)?.toDouble() ?? 0,
      completedTrips: (row['total_trips'] as num?)?.toInt() ?? 0,
      verified: row['verification_status'] == 'verified',
      vehicleTypeId: vehicle?.id,
      vehicleClass: vehicle?.name ?? '',
      vehicleIconUrl: vehicle?.iconUrl,
      zone: 'Tanzania',
    );
  }

  /// The `public.vehicle_types` row behind the driver's current vehicle.
  Future<_VehicleTypeRow?> _currentVehicleType(
    SupabaseClient client,
    String? vehicleId,
  ) async {
    if (vehicleId == null) return null;
    final row = await client
        .from('vehicles')
        .select('vehicle_types(id, name, icon_url)')
        .eq('id', vehicleId)
        .maybeSingle();
    final types = row?['vehicle_types'];
    if (types is! Map) return null;
    return _VehicleTypeRow(
      id: types['id'] as String? ?? '',
      name: types['name'] as String? ?? '',
      iconUrl: types['icon_url'] as String?,
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

class _VehicleTypeRow {
  const _VehicleTypeRow({
    required this.id,
    required this.name,
    required this.iconUrl,
  });

  final String id;
  final String name;
  final String? iconUrl;
}
