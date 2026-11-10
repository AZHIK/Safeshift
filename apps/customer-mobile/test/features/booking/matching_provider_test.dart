import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safeshift_customer/features/booking/providers/matching_provider.dart';

void main() {
  test('matching provider reflects ride state without mock data', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(matchingProvider).isSearching, isFalse);
    expect(container.read(matchingProvider).driver, isNull);
    await container.read(matchingProvider.notifier).findDriver();
    expect(container.read(matchingProvider).driver, isNull);
  });
}
