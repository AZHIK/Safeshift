import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/cache/cache_service.dart';
import '../../../core/network/supabase_client.dart';
import '../../auth/providers/auth_provider.dart';
import '../../home/data/driver_repository.dart';

class EarningsSegment extends Notifier<String> {
  @override
  String build() => 'Today';

  void setSegment(String value) => state = value;
}

final earningsSegmentProvider = NotifierProvider<EarningsSegment, String>(
  EarningsSegment.new,
);

class EarningsNotifier extends AsyncNotifier<DriverEarningsSnapshot> {
  @override
  Future<DriverEarningsSnapshot> build() async {
    final user = ref.watch(authProvider).currentUser;
    if (user == null) return DriverEarningsSnapshot.empty;

    final cache = ref.read(cacheServiceProvider);
    final cached = _readCache(cache, user.id);
    if (cached != null) {
      unawaited(_refresh(user.id));
      return cached;
    }
    return _refresh(user.id);
  }

  Future<DriverEarningsSnapshot> _refresh(String userId) async {
    final snapshot = await DriverRepository(
      ref.read(supabaseProvider),
    ).earnings();
    await ref.read(cacheServiceProvider).putJson(
      userId,
      'driver_earnings',
      _toJson(snapshot),
    );
    return snapshot;
  }

  Future<void> refresh() async {
    final user = ref.read(authProvider).currentUser;
    if (user == null) {
      state = const AsyncData(DriverEarningsSnapshot.empty);
      return;
    }
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _refresh(user.id));
  }

  DriverEarningsSnapshot? _readCache(CacheService cache, String userId) {
    final raw = cache.getJson(userId, 'driver_earnings');
    if (raw is! Map) return null;
    final map = raw.cast<String, dynamic>();
    int money(Object? value) => (value as num?)?.toInt() ?? 0;
    final days = <DailyEarning>[];
    final rawDays = map['last_7_days'];
    if (rawDays is List) {
      for (final item in rawDays) {
        if (item is! Map) continue;
        days.add(
          DailyEarning(
            day: item['day'] as String? ?? '',
            date: DateTime.tryParse('${item['date'] ?? ''}'),
            amount: money(item['amount']),
          ),
        );
      }
    }
    return DriverEarningsSnapshot(
      todayAmount: money(map['today_amount']),
      todayTrips: money(map['today_trips']),
      weekAmount: money(map['week_amount']),
      weekTrips: money(map['week_trips']),
      monthAmount: money(map['month_amount']),
      monthTrips: money(map['month_trips']),
      last7Days: days,
    );
  }

  Map<String, dynamic> _toJson(DriverEarningsSnapshot snapshot) => {
    'today_amount': snapshot.todayAmount,
    'today_trips': snapshot.todayTrips,
    'week_amount': snapshot.weekAmount,
    'week_trips': snapshot.weekTrips,
    'month_amount': snapshot.monthAmount,
    'month_trips': snapshot.monthTrips,
    'last_7_days': snapshot.last7Days
        .map(
          (day) => {
            'day': day.day,
            'date': day.date?.toIso8601String(),
            'amount': day.amount,
          },
        )
        .toList(),
  };
}

final earningsProvider =
    AsyncNotifierProvider<EarningsNotifier, DriverEarningsSnapshot>(
      EarningsNotifier.new,
    );

int earningsTotalFor(DriverEarningsSnapshot data, String segment) =>
    switch (segment) {
      'Week' => data.weekAmount,
      'Month' => data.monthAmount,
      _ => data.todayAmount,
    };

int earningsTripsFor(DriverEarningsSnapshot data, String segment) =>
    switch (segment) {
      'Week' => data.weekTrips,
      'Month' => data.monthTrips,
      _ => data.todayTrips,
    };
