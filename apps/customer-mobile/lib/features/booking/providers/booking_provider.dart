import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/mock/mock_cargo_categories.dart';
import '../../../shared/mock/mock_locations.dart';
import '../../../shared/mock/mock_vehicle_classes.dart';

class BookingDraft {
  const BookingDraft({
    required this.pickup,
    required this.destination,
    required this.cargoCategory,
    required this.vehicleClass,
    required this.scheduledTime,
  });

  final MockLocation pickup;
  final MockLocation destination;
  final MockCargoCategory? cargoCategory;
  final MockVehicleClass vehicleClass;
  final DateTime? scheduledTime;
}

class BookingDraftNotifier extends Notifier<BookingDraft?> {
  @override
  BookingDraft? build() => null;

  void save(BookingDraft draft) => state = draft;
  void clear() => state = null;
}

final bookingProvider = NotifierProvider<BookingDraftNotifier, BookingDraft?>(
  BookingDraftNotifier.new,
);
