// Earnings dashboard state (mock).
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../shared/mock/mock_earnings.dart';

part 'earnings_provider.g.dart';

@riverpod
class EarningsSegment extends _$EarningsSegment {
  @override
  String build() {
    ref.keepAlive();
    return 'Today';
  }

  void setSegment(String value) => state = value;

  int totalFor(String segment) => switch (segment) {
    'Week' => MockEarnings.weekTzs,
    'Month' => MockEarnings.monthTzs,
    _ => MockEarnings.todayTzs,
  };

  int tripsFor(String segment) => switch (segment) {
    'Week' => MockEarnings.weekTrips,
    'Month' => MockEarnings.monthTrips,
    _ => MockEarnings.todayTrips,
  };

  int currentTotal() => totalFor(state);
  int currentTrips() => tripsFor(state);
}
