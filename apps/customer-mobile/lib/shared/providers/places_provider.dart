import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/env_config.dart';
import '../../core/network/supabase_client.dart';
import '../repositories/places_repository.dart';
import '../services/places_api.dart';

/// Google Places/Geocoding client backed by the configured client key.
final placesApiProvider = Provider<PlacesApi>((ref) {
  ref.keepAlive();
  return GooglePlacesApi(apiKey: EnvConfig.googleMapsApiKey);
});

/// Shared place repository. Keeping it alive preserves the in-memory
/// autocomplete/details/reverse-geocode caches between sheet openings.
final placesRepositoryProvider = Provider<PlacesRepository>((ref) {
  ref.keepAlive();
  return PlacesRepository(
    ref.watch(supabaseProvider),
    placesApi: ref.watch(placesApiProvider),
  );
});
