import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:safeshift_shared/safeshift_shared.dart';

import '../../../core/network/supabase_client.dart';

/// Vehicle categories the driver can pick from.
///
/// The list is read from `public.vehicle_types`, scoped to the driver's
/// country, so it never drifts from the catalogue the pricing and dispatch
/// rules use.
final vehicleTypesProvider = FutureProvider<List<VehicleTypeOption>>((ref) {
  return CatalogRepository(ref.watch(supabaseProvider)).getVehicleTypes();
});

/// Cargo types the driver can be shown.
///
/// Read from `public.cargo_types`, scoped to the driver's country.
final cargoTypesProvider = FutureProvider<List<CargoTypeOption>>((ref) {
  return CatalogRepository(ref.watch(supabaseProvider)).getCargoTypes();
});

/// Vehicle categories for an explicit country.
///
/// Used by the onboarding form, where the driver picks the country they
/// operate in before the catalogue is known. Pass an empty string to get
/// every active row.
final vehicleTypesForCountryProvider =
    FutureProvider.family<List<VehicleTypeOption>, String>((ref, countryId) {
  return CatalogRepository(ref.watch(supabaseProvider)).getVehicleTypes(
    countryId: countryId,
  );
});
