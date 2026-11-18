import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/cache/cache_service.dart';
import '../../../core/network/supabase_client.dart';
import '../../home/domain/entities/driver_job.dart';
import '../../auth/providers/auth_provider.dart';
import '../../home/data/driver_repository.dart';

class TripsFilter extends Notifier<String> {
  @override
  String build() => 'All';

  void setFilter(String value) => state = value;
}

final tripsFilterProvider = NotifierProvider<TripsFilter, String>(
  TripsFilter.new,
);

/// Shared repository instance so trip lookups can be overridden in tests.
final driverRepositoryProvider = Provider<DriverRepository>(
  (ref) => DriverRepository(ref.read(supabaseProvider)),
);

const _tripCacheKey = 'driver_trips';

DriverJob _tripFromCacheMap(Map<String, dynamic> map) {
  return DriverJob(
    id: map['id'] as String? ?? '',
    pickup: map['pickup'] as String? ?? '',
    destination: map['destination'] as String? ?? '',
    distanceKm: (map['distance_km'] as num?)?.toDouble() ?? 0,
    estimatedFareTzs: (map['fare'] as num?)?.toInt() ?? 0,
    cargoClass: map['cargo'] as String? ?? 'Cargo',
    cargoTypeId: map['cargo_type_id'] as String?,
    cargoIconUrl: map['cargo_icon_url'] as String?,
    customerName: map['customer'] as String? ?? 'Customer',
    pickupDistanceKm: 0,
    status: map['status'] as String?,
    completedAt: DateTime.tryParse('${map['completed_at'] ?? ''}'),
    cargoDescription: map['cargo_description'] as String?,
    cargoWeightKg: (map['cargo_weight_kg'] as num?)?.toDouble(),
    declaredValueTzs: (map['declared_value_tzs'] as num?)?.toDouble(),
  );
}

Map<String, dynamic> _tripToJson(DriverJob trip) => {
  'id': trip.id,
  'pickup': trip.pickup,
  'destination': trip.destination,
  'distance_km': trip.distanceKm,
  'fare': trip.estimatedFareTzs,
  'cargo': trip.cargoClass,
  'cargo_type_id': trip.cargoTypeId,
  'cargo_icon_url': trip.cargoIconUrl,
  'customer': trip.customerName,
  'status': trip.status,
  'completed_at': trip.completedAt?.toIso8601String(),
  'cargo_description': trip.cargoDescription,
  'cargo_weight_kg': trip.cargoWeightKg,
  'declared_value_tzs': trip.declaredValueTzs,
};

class DriverTripsNotifier extends AsyncNotifier<List<DriverJob>> {
  @override
  Future<List<DriverJob>> build() async {
    final user = ref.watch(authProvider).currentUser;
    if (user == null) return const <DriverJob>[];
    final cache = ref.read(cacheServiceProvider);
    final cached = _readCache(cache, user.id);
    if (cached.isNotEmpty) {
      unawaited(_refreshCached(user.id));
      return cached;
    }
    return _refresh(user.id);
  }

  Future<List<DriverJob>> _refresh(String userId) async {
    final trips = await ref.read(driverRepositoryProvider).trips();
    await ref
        .read(cacheServiceProvider)
        .putJson(
          userId,
          _tripCacheKey,
          trips.map(_tripToJson).toList(growable: false),
        );
    return trips;
  }

  Future<void> _refreshCached(String userId) async {
    try {
      final fresh = await _refresh(userId);
      if (ref.mounted) state = AsyncData(fresh);
    } catch (_) {
      // The cached trip list remains available until the next explicit retry.
    }
  }

  Future<void> refresh() async {
    final user = ref.read(authProvider).currentUser;
    if (user == null) {
      state = const AsyncData(<DriverJob>[]);
      return;
    }
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _refresh(user.id));
  }

  List<DriverJob> _readCache(CacheService cache, String userId) {
    final raw = cache.getJson(userId, _tripCacheKey);
    if (raw is! List) return const <DriverJob>[];
    final trips = <DriverJob>[];
    for (final item in raw) {
      if (item is! Map) continue;
      trips.add(_tripFromCacheMap(item.cast<String, dynamic>()));
    }
    return trips;
  }
}

final driverTripsProvider =
    AsyncNotifierProvider<DriverTripsNotifier, List<DriverJob>>(
      DriverTripsNotifier.new,
    );

/// Resolves one trip for the detail route.
///
/// The server lookup is authoritative, so trips older than the history page
/// still open. A locally cached copy keeps the route usable offline; a null
/// result means the trip is not the driver's own or does not exist.
final driverTripDetailProvider = FutureProvider.family<DriverJob?, String>((
  ref,
  jobId,
) async {
  final user = ref.watch(authProvider).currentUser;
  if (user == null) return null;
  final cache = ref.read(cacheServiceProvider);
  try {
    final trip = await ref.read(driverRepositoryProvider).trip(jobId);
    if (trip != null) {
      await cache.putJson(user.id, 'driver_trip', _tripToJson(trip), id: jobId);
    }
    return trip;
  } catch (error) {
    final cached = cache.getJson(user.id, 'driver_trip', id: jobId);
    if (cached is Map) {
      final trip = _tripFromCacheMap(cached.cast<String, dynamic>());
      if (trip.id == jobId) return trip;
    }
    rethrow;
  }
});

final filteredTripsProvider = Provider<AsyncValue<List<DriverJob>>>((ref) {
  final filter = ref.watch(tripsFilterProvider);
  final trips = ref.watch(driverTripsProvider);
  return trips.whenData((items) {
    final now = DateTime.now();
    return switch (filter) {
      'Today' =>
        items
            .where(
              (t) =>
                  t.completedAt != null &&
                  t.completedAt!.year == now.year &&
                  t.completedAt!.month == now.month &&
                  t.completedAt!.day == now.day,
            )
            .toList(growable: false),
      'This Week' =>
        items
            .where(
              (t) =>
                  t.completedAt != null &&
                  now.difference(t.completedAt!).inDays < 7,
            )
            .toList(growable: false),
      'This Month' =>
        items
            .where(
              (t) =>
                  t.completedAt != null &&
                  t.completedAt!.year == now.year &&
                  t.completedAt!.month == now.month,
            )
            .toList(growable: false),
      _ => items,
    };
  });
});
