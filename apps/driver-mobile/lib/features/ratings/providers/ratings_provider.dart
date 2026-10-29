import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/cache/cache_service.dart';
import '../../../core/network/supabase_client.dart';
import '../../auth/providers/auth_provider.dart';
import '../../home/data/driver_repository.dart';

class RatingsNotifier extends AsyncNotifier<List<DriverRatingSnapshot>> {
  @override
  Future<List<DriverRatingSnapshot>> build() async {
    final user = ref.watch(authProvider).currentUser;
    if (user == null) return const <DriverRatingSnapshot>[];
    final cache = ref.read(cacheServiceProvider);
    final cached = _readCache(cache, user.id);
    if (cached.isNotEmpty) {
      unawaited(_refresh(user.id));
      return cached;
    }
    return _refresh(user.id);
  }

  Future<List<DriverRatingSnapshot>> _refresh(String userId) async {
    final ratings = await DriverRepository(
      ref.read(supabaseProvider),
    ).ratings();
    await ref.read(cacheServiceProvider).putJson(
      userId,
      'driver_ratings',
      ratings
          .map(
            (rating) => {
              'id': rating.id,
              'score': rating.score,
              'rater_name': rating.raterName,
              'comment': rating.comment,
              'created_at': rating.createdAt?.toIso8601String(),
              'job_id': rating.jobId,
            },
          )
          .toList(growable: false),
    );
    return ratings;
  }

  Future<void> refresh() async {
    final user = ref.read(authProvider).currentUser;
    if (user == null) {
      state = const AsyncData(<DriverRatingSnapshot>[]);
      return;
    }
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _refresh(user.id));
  }

  List<DriverRatingSnapshot> _readCache(CacheService cache, String userId) {
    final raw = cache.getJson(userId, 'driver_ratings');
    if (raw is! List) return const <DriverRatingSnapshot>[];
    final ratings = <DriverRatingSnapshot>[];
    for (final item in raw) {
      if (item is! Map) continue;
      final map = item.cast<String, dynamic>();
      ratings.add(
        DriverRatingSnapshot(
          id: map['id'] as String? ?? '',
          score: (map['score'] as num?)?.toInt() ?? 0,
          raterName: map['rater_name'] as String? ?? 'Customer',
          comment: map['comment'] as String?,
          createdAt: DateTime.tryParse('${map['created_at'] ?? ''}'),
          jobId: map['job_id'] as String?,
        ),
      );
    }
    return ratings;
  }
}

final ratingsStateProvider =
    AsyncNotifierProvider<RatingsNotifier, List<DriverRatingSnapshot>>(
      RatingsNotifier.new,
    );

double averageRating(List<DriverRatingSnapshot> ratings) {
  if (ratings.isEmpty) return 0;
  final sum = ratings.fold<int>(0, (acc, rating) => acc + rating.score);
  return sum / ratings.length;
}
