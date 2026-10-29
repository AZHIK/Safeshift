import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/cache/cache_service.dart';
import '../../../core/network/supabase_client.dart';
import '../../../shared/mock/mock_jobs.dart';
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

class DriverTripsNotifier extends AsyncNotifier<List<DriverJob>> {
  @override
  Future<List<DriverJob>> build() async {
    final user = ref.watch(authProvider).currentUser;
    if (user == null) return const <DriverJob>[];
    final cache = ref.read(cacheServiceProvider);
    final cached = _readCache(cache, user.id);
    if (cached.isNotEmpty) {
      unawaited(_refresh(user.id));
      return cached;
    }
    return _refresh(user.id);
  }

  Future<List<DriverJob>> _refresh(String userId) async {
    final trips = await DriverRepository(
      ref.read(supabaseProvider),
    ).trips();
    await ref.read(cacheServiceProvider).putJson(
      userId,
      'driver_trips',
      trips.map(_toJson).toList(growable: false),
    );
    return trips;
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
    final raw = cache.getJson(userId, 'driver_trips');
    if (raw is! List) return const <DriverJob>[];
    final trips = <DriverJob>[];
    for (final item in raw) {
      if (item is! Map) continue;
      final map = item.cast<String, dynamic>();
      trips.add(
        DriverJob(
          id: map['id'] as String? ?? '',
          pickup: map['pickup'] as String? ?? '',
          destination: map['destination'] as String? ?? '',
          distanceKm: (map['distance_km'] as num?)?.toDouble() ?? 0,
          estimatedFareTzs: (map['fare'] as num?)?.toInt() ?? 0,
          cargoClass: map['cargo'] as String? ?? 'Cargo',
          customerName: map['customer'] as String? ?? 'Customer',
          pickupDistanceKm: 0,
          status: map['status'] as String?,
          completedAt: DateTime.tryParse('${map['completed_at'] ?? ''}'),
        ),
      );
    }
    return trips;
  }

  Map<String, dynamic> _toJson(DriverJob trip) => {
    'id': trip.id,
    'pickup': trip.pickup,
    'destination': trip.destination,
    'distance_km': trip.distanceKm,
    'fare': trip.estimatedFareTzs,
    'cargo': trip.cargoClass,
    'customer': trip.customerName,
    'status': trip.status,
    'completed_at': trip.completedAt?.toIso8601String(),
  };
}

final driverTripsProvider =
    AsyncNotifierProvider<DriverTripsNotifier, List<DriverJob>>(
      DriverTripsNotifier.new,
    );

final filteredTripsProvider = Provider<AsyncValue<List<DriverJob>>>((ref) {
  final filter = ref.watch(tripsFilterProvider);
  final trips = ref.watch(driverTripsProvider);
  return trips.whenData((items) {
    final now = DateTime.now();
    return switch (filter) {
      'Today' => items
          .where(
            (t) =>
                t.completedAt != null &&
                t.completedAt!.year == now.year &&
                t.completedAt!.month == now.month &&
                t.completedAt!.day == now.day,
          )
          .toList(growable: false),
      'This Week' => items
          .where(
            (t) =>
                t.completedAt != null &&
                now.difference(t.completedAt!).inDays < 7,
          )
          .toList(growable: false),
      'This Month' => items
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
