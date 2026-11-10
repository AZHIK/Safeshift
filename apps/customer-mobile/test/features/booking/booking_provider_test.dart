import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safeshift_customer/features/booking/providers/booking_provider.dart';
import 'package:safeshift_customer/shared/models/catalog_option.dart';
import 'package:safeshift_customer/shared/models/ride_place.dart';

void main() {
  test('booking draft starts empty and can be saved', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(bookingProvider), isNull);
    const draft = BookingDraft(
      pickup: RidePlace(
        id: 'pickup',
        name: 'Pickup',
        district: 'Dar es Salaam',
        latitude: -6.8,
        longitude: 39.2,
      ),
      destination: RidePlace(
        id: 'destination',
        name: 'Destination',
        district: 'Dar es Salaam',
        latitude: -6.79,
        longitude: 39.25,
      ),
      cargoCategory: CargoTypeOption(
        id: 'cargo',
        code: 'household_goods',
        name: 'Household',
        description: '',
        displayOrder: 1,
      ),
      vehicleClass: VehicleTypeOption(
        id: 'vehicle',
        code: 'pickup',
        name: 'Pickup',
        description: '',
        capacityKgMin: 500,
        capacityKgMax: 1000,
        displayOrder: 1,
      ),
      scheduledTime: null,
    );
    container.read(bookingProvider.notifier).save(draft);

    expect(container.read(bookingProvider), same(draft));
  });
}
