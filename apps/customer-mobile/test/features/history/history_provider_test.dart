import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safeshift_customer/features/history/providers/history_provider.dart';

void main() {
  test('history shows ten mock jobs and filters by status', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(historyProvider), hasLength(10));
    container.read(historyFilterProvider.notifier).select('Completed');
    expect(container.read(historyProvider), hasLength(6));
    container.read(historyFilterProvider.notifier).select('Cancelled');
    expect(container.read(historyProvider), hasLength(2));
    container.read(historyFilterProvider.notifier).select('In Progress');
    expect(container.read(historyProvider), hasLength(2));
  });
}
