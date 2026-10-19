// Trips history filter state (mock).
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../shared/mock/mock_trips.dart';

part 'trips_provider.g.dart';

@riverpod
class TripsFilter extends _$TripsFilter {
  @override
  String build() {
    ref.keepAlive();
    return 'All';
  }

  void setFilter(String value) => state = value;

  List<CompletedTrip> filteredTrips() {
    final now = DateTime.now();
    return switch (state) {
      'Today' => mockTrips
          .where(
            (t) =>
                t.date.year == now.year &&
                t.date.month == now.month &&
                t.date.day == now.day,
          )
          .toList(),
      'This Week' => mockTrips
          .where((t) => now.difference(t.date).inDays < 7)
          .toList(),
      'This Month' => mockTrips
          .where(
            (t) => t.date.year == now.year && t.date.month == now.month,
          )
          .toList(),
      _ => mockTrips,
    };
  }
}
