import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safeshift_driver/features/earnings/providers/earnings_provider.dart';
import 'package:safeshift_driver/features/home/data/driver_repository.dart';

void main() {
  const snapshot = DriverEarningsSnapshot(
    todayAmount: 42000,
    todayTrips: 3,
    weekAmount: 210000,
    weekTrips: 14,
    monthAmount: 840000,
    monthTrips: 56,
    last7Days: <DailyEarning>[],
  );

  group('Earnings segment', () {
    test('defaults to Today and selects totals from backend data', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(earningsSegmentProvider), 'Today');
      expect(earningsTotalFor(snapshot, 'Today'), 42000);
      expect(earningsTripsFor(snapshot, 'Today'), 3);
    });

    test('week and month segments select their own totals', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(earningsSegmentProvider.notifier);

      notifier.setSegment('Week');
      expect(container.read(earningsSegmentProvider), 'Week');
      expect(earningsTotalFor(snapshot, 'Week'), 210000);
      expect(earningsTripsFor(snapshot, 'Week'), 14);

      notifier.setSegment('Month');
      expect(container.read(earningsSegmentProvider), 'Month');
      expect(earningsTotalFor(snapshot, 'Month'), 840000);
      expect(earningsTripsFor(snapshot, 'Month'), 56);
    });

    test('unknown segments fall back to today', () {
      expect(earningsTotalFor(snapshot, 'Unknown'), 42000);
      expect(earningsTripsFor(snapshot, 'Unknown'), 3);
    });
  });
}
