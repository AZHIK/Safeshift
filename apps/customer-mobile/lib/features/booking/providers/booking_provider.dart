import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:safeshift_shared/safeshift_shared.dart';

import '../../../shared/models/ride_place.dart';

class BookingDraft {
  const BookingDraft({
    required this.pickup,
    required this.destination,
    required this.cargoCategory,
    required this.vehicleClass,
    required this.scheduledTime,
  });

  final RidePlace pickup;
  final RidePlace destination;
  final CargoTypeOption? cargoCategory;
  final VehicleTypeOption vehicleClass;
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
