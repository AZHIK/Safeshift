import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../tracking/domain/entities/driver.dart';
import '../../../shared/mock/mock_drivers.dart';

class MatchingState {
  const MatchingState({this.isSearching = false, this.driver});
  final bool isSearching;
  final Driver? driver;
}

class MatchingNotifier extends Notifier<MatchingState> {
  @override
  MatchingState build() => const MatchingState();

  Future<void> findDriver() async {
    if (state.isSearching || state.driver != null) return;
    state = const MatchingState(isSearching: true);
    await Future<void>.delayed(const Duration(seconds: 3));
    state = MatchingState(driver: mockDrivers.first);
  }

  void reset() => state = const MatchingState();
}

final matchingProvider = NotifierProvider<MatchingNotifier, MatchingState>(
  MatchingNotifier.new,
);
