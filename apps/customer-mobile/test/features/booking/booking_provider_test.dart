import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safeshift_customer/features/booking/providers/booking_provider.dart';
import 'package:safeshift_customer/features/booking/providers/quote_provider.dart';
import 'package:safeshift_customer/shared/mock/mock_cargo_categories.dart';
import 'package:safeshift_customer/shared/mock/mock_locations.dart';
import 'package:safeshift_customer/shared/mock/mock_vehicle_classes.dart';

void main() {
  test('booking draft starts empty and quote follows selected vehicle', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(bookingProvider), isNull);
    final draft = BookingDraft(
      pickup: mockLocations.first,
      destination: mockLocations[1],
      cargoCategory: mockCargoCategories.first,
      vehicleClass: mockVehicleClasses[1],
      scheduledTime: null,
    );
    container.read(bookingProvider.notifier).save(draft);

    expect(container.read(bookingProvider), same(draft));
    expect(container.read(quoteProvider)?.vehicleClassId, 'pickup');
  });
}
