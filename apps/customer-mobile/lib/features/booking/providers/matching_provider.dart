import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ride/providers/ride_provider.dart';
import '../../tracking/domain/entities/driver.dart';

class MatchingState {
  const MatchingState({this.isSearching = false, this.driver});
  final bool isSearching;
  final Driver? driver;
}

/// Legacy matching provider backed by real ride state (no mock data).
class MatchingNotifier extends Notifier<MatchingState> {
  @override
  MatchingState build() {
    final ride = ref.watch(rideProvider);
    return MatchingState(
      isSearching: ride.stage == RideStage.searching,
      driver: ride.driver,
    );
  }

  Future<void> findDriver() async {
    // Real matching is handled by RideProvider/dispatch.
  }

  void reset() {
    ref.read(rideProvider.notifier).reset();
  }
}

final matchingProvider = NotifierProvider<MatchingNotifier, MatchingState>(
  MatchingNotifier.new,
);
