import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safeshift_customer/features/delivery/providers/delivery_provider.dart';

void main() {
  test('delivery confirmation moves from code entry to receipt', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(deliveryProvider).phase, DeliveryPhase.verify);
    await container.read(deliveryProvider.notifier).confirmDelivery();
    expect(container.read(deliveryProvider).phase, DeliveryPhase.receipt);
    expect(container.read(deliveryProvider).isLoading, isFalse);
  });
}
