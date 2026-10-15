import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safeshift_customer/features/booking/providers/matching_provider.dart';
import 'package:safeshift_customer/shared/mock/mock_drivers.dart';

void main() {
  test('matching returns the first mock driver after its delay', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final pendingMatch = container.read(matchingProvider.notifier).findDriver();
    expect(container.read(matchingProvider).isSearching, isTrue);
    await pendingMatch;
    expect(container.read(matchingProvider).driver, same(mockDrivers.first));
    expect(container.read(matchingProvider).isSearching, isFalse);
  });
}
