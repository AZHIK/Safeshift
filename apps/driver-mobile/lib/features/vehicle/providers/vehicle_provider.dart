import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/cache/cache_service.dart';
import '../../../core/network/supabase_client.dart';
import '../../auth/providers/auth_provider.dart';
import '../../home/data/driver_repository.dart';

class VehicleNotifier extends AsyncNotifier<DriverVehicleSnapshot?> {
  @override
  Future<DriverVehicleSnapshot?> build() async {
    final user = ref.watch(authProvider).currentUser;
    if (user == null) return null;
    final cache = ref.read(cacheServiceProvider);
    final cached = _readCache(cache, user.id);
    if (cached != null) {
      unawaited(_refresh(user.id));
      return cached;
    }
    return _refresh(user.id);
  }

  Future<DriverVehicleSnapshot?> _refresh(String userId) async {
    final vehicle = await DriverRepository(
      ref.read(supabaseProvider),
    ).vehicle();
    if (vehicle != null) {
      await ref.read(cacheServiceProvider).putJson(
        userId,
        'driver_vehicle',
        {
          'id': vehicle.id,
          'registration_number': vehicle.registrationNumber,
          'vehicle_type': vehicle.vehicleType,
          'verification_status': vehicle.verificationStatus,
          'make': vehicle.make,
          'model': vehicle.model,
          'year': vehicle.year,
          'color': vehicle.color,
          'capacity_kg': vehicle.capacityKg,
          'photo_urls': vehicle.photoUrls,
        },
      );
    }
    return vehicle;
  }

  Future<void> refresh() async {
    final user = ref.read(authProvider).currentUser;
    if (user == null) {
      state = const AsyncData(null);
      return;
    }
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _refresh(user.id));
  }

  DriverVehicleSnapshot? _readCache(CacheService cache, String userId) {
    final raw = cache.getJson(userId, 'driver_vehicle');
    if (raw is! Map) return null;
    final map = raw.cast<String, dynamic>();
    final photos = map['photo_urls'];
    return DriverVehicleSnapshot(
      id: map['id'] as String? ?? '',
      registrationNumber: map['registration_number'] as String? ?? '',
      vehicleType: map['vehicle_type'] as String? ?? 'Vehicle',
      verificationStatus: map['verification_status'] as String? ?? 'pending',
      make: map['make'] as String?,
      model: map['model'] as String?,
      year: (map['year'] as num?)?.toInt(),
      color: map['color'] as String?,
      capacityKg: (map['capacity_kg'] as num?)?.toInt(),
      photoUrls: photos is List ? photos.whereType<String>().toList() : const [],
    );
  }
}

final vehicleStateProvider =
    AsyncNotifierProvider<VehicleNotifier, DriverVehicleSnapshot?>(
      VehicleNotifier.new,
    );
