import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/supabase_client.dart';
import '../../auth/providers/auth_provider.dart';
import '../../ride/data/ride_repository.dart';
import '../domain/entities/quote.dart';
import 'booking_provider.dart';

/// Fetches a real quote from the backend for the current booking draft.
final quoteProvider = FutureProvider.autoDispose<Quote?>((ref) async {
  final draft = ref.watch(bookingProvider);
  final user = ref.watch(authProvider).currentUser;
  if (draft == null || user == null) return null;

  final snapshot = await RideRepository(ref.watch(supabaseProvider)).requestQuote(
    customerId: user.id,
    pickup: draft.pickup,
    destination: draft.destination,
    vehicle: draft.vehicleClass,
    cargo: draft.cargoCategory,
  );

  return Quote(
    baseFee: snapshot.baseFee,
    distanceFee: snapshot.distanceFee,
    timeFee: snapshot.timeFee,
    cargoHandlingFee: 0,
    vat: snapshot.vat,
    total: snapshot.total,
    vehicleClassId: draft.vehicleClass.id,
  );
});
