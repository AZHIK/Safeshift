import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safeshift_driver/features/earnings/providers/earnings_provider.dart';
import 'package:safeshift_driver/shared/mock/mock_earnings.dart';

void main() {
  group('EarningsProvider totals', () {
    test('defaults to Today with the mock daily total', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(earningsSegmentProvider), 'Today');
      expect(
        container.read(earningsSegmentProvider.notifier).currentTotal(),
        MockEarnings.todayTzs,
      );
      expect(
        container.read(earningsSegmentProvider.notifier).currentTrips(),
        MockEarnings.todayTrips,
      );
    });

    test('week and month segments return their mock totals', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(earningsSegmentProvider.notifier);

      notifier.setSegment('Week');
      expect(container.read(earningsSegmentProvider), 'Week');
      expect(notifier.currentTotal(), MockEarnings.weekTzs);
      expect(notifier.currentTrips(), MockEarnings.weekTrips);

      notifier.setSegment('Month');
      expect(container.read(earningsSegmentProvider), 'Month');
      expect(notifier.currentTotal(), MockEarnings.monthTzs);
      expect(notifier.currentTrips(), MockEarnings.monthTrips);
    });

    test('last-7-days chart data sums consistently', () {
      final sum = MockEarnings.last7Days.fold<int>(
        0,
        (acc, day) => acc + day.amountTzs,
      );
      expect(MockEarnings.last7Days, hasLength(7));
      expect(sum, greaterThan(0));
      expect(MockEarnings.todayTzs, greaterThan(0));
      expect(MockEarnings.monthTzs, greaterThanOrEqualTo(MockEarnings.weekTzs));
    });
  });
}
