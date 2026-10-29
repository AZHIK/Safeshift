import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/cache/cache_service.dart';
import '../../../core/network/supabase_client.dart';
import '../../auth/providers/auth_provider.dart';
import '../../booking/domain/entities/job.dart';
import '../../ride/data/ride_repository.dart';

class HistoryFilterNotifier extends Notifier<String> {
  @override
  String build() => 'All';

  void select(String filter) => state = filter;
}

final historyFilterProvider = NotifierProvider<HistoryFilterNotifier, String>(
  HistoryFilterNotifier.new,
);

/// Cache-first customer history.
///
/// The cached list renders immediately when offline; a background refresh
/// replaces it when the network is available. Nothing is fabricated locally.
class HistoryNotifier extends AsyncNotifier<List<Job>> {
  @override
  Future<List<Job>> build() async {
    final user = ref.watch(authProvider).currentUser;
    if (user == null) return const <Job>[];

    final cache = ref.read(cacheServiceProvider);
    final cached = _readCache(cache, user.id);
    if (cached.isNotEmpty) {
      unawaited(_refresh(user.id));
      return cached;
    }
    return _refresh(user.id);
  }

  Future<List<Job>> _refresh(String userId) async {
    final repo = RideRepository(ref.read(supabaseProvider));
    final snapshots = await repo.getJobs();
    final jobs = snapshots.map(_toJob).toList(growable: false);
    await ref.read(cacheServiceProvider).putJson(
      userId,
      'customer_jobs',
      snapshots.map(_toJson).toList(growable: false),
    );
    return jobs;
  }

  Future<void> refresh() async {
    final user = ref.read(authProvider).currentUser;
    if (user == null) {
      state = const AsyncData(<Job>[]);
      return;
    }
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _refresh(user.id));
  }

  List<Job> _readCache(CacheService cache, String userId) {
    final raw = cache.getJson(userId, 'customer_jobs');
    if (raw is! List) return const <Job>[];
    final jobs = <Job>[];
    for (final item in raw) {
      if (item is! Map) continue;
      try {
        jobs.add(_fromJson(item.cast<String, dynamic>()));
      } catch (_) {
        // Ignore a corrupt cache entry; the network refresh will replace it.
      }
    }
    return jobs;
  }

  Job _toJob(CustomerJobSnapshot snapshot) => Job(
    id: snapshot.id,
    status: snapshot.status,
    pickupAddress: snapshot.pickupAddress,
    destinationAddress: snapshot.destinationAddress,
    quoteAmount: snapshot.amount,
    createdAt: snapshot.createdAt,
    driverId: snapshot.driverId,
    vehicleClassId: snapshot.vehicleType,
    paymentMethod: snapshot.paymentMethod,
  );

  Map<String, dynamic> _toJson(CustomerJobSnapshot snapshot) =>
      <String, dynamic>{
        'job_id': snapshot.id,
        'status': snapshot.status,
        'pickup_address': snapshot.pickupAddress,
        'destination_address': snapshot.destinationAddress,
        'final_amount': snapshot.amount,
        'created_at': snapshot.createdAt?.toIso8601String(),
        'driver_id': snapshot.driverId,
        'vehicle_type': snapshot.vehicleType,
        'payment_method': snapshot.paymentMethod,
      };

  Job _fromJson(Map<String, dynamic> row) => Job(
    id: row['job_id'] as String,
    status: row['status'] as String? ?? 'requested',
    pickupAddress: row['pickup_address'] as String? ?? '',
    destinationAddress: row['destination_address'] as String? ?? '',
    quoteAmount: (row['final_amount'] as num?)?.toDouble() ?? 0,
    createdAt: DateTime.tryParse('${row['created_at'] ?? ''}'),
    driverId: row['driver_id'] as String?,
    vehicleClassId: row['vehicle_type'] as String?,
    paymentMethod: row['payment_method'] as String?,
  );
}

final historyProvider = AsyncNotifierProvider<HistoryNotifier, List<Job>>(
  HistoryNotifier.new,
);

final filteredHistoryProvider = Provider<AsyncValue<List<Job>>>((ref) {
  final filter = ref.watch(historyFilterProvider);
  final jobs = ref.watch(historyProvider);
  return jobs.whenData((items) {
    if (filter == 'All') return items;
    final status = switch (filter) {
      'Completed' => 'completed',
      'Cancelled' => 'cancelled',
      'In Progress' => 'in_progress',
      _ => '',
    };
    if (filter == 'In Progress') {
      return items
          .where(
            (job) => !<String>{
              'completed',
              'cancelled',
              'delivered',
            }.contains(job.status),
          )
          .toList(growable: false);
    }
    return items
        .where((job) => job.status == status)
        .toList(growable: false);
  });
});

final historyDetailProvider = FutureProvider.family<CustomerJobSnapshot?, String>(
  (ref, jobId) {
    return RideRepository(ref.watch(supabaseProvider)).getJob(jobId);
  },
);
