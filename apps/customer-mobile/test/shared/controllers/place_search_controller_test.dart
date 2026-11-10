import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:safeshift_customer/shared/controllers/place_search_controller.dart';
import 'package:safeshift_customer/shared/models/place_suggestion.dart';
import 'package:safeshift_customer/shared/models/ride_place.dart';
import 'package:safeshift_customer/shared/models/user_location.dart';
import 'package:safeshift_customer/shared/repositories/places_repository.dart';
import 'package:safeshift_customer/shared/services/places_api.dart';
import 'package:safeshift_customer/shared/utils/geo.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _MockSupabaseClient extends Mock implements SupabaseClient {}

class _FakePlacesApi implements PlacesApi {
  _FakePlacesApi({
    this.autocompleteResults = const <PlaceSuggestion>[],
    this.detailsResult,
    this.reverseResult,
  });

  List<PlaceSuggestion> autocompleteResults;
  RidePlace? detailsResult;
  RidePlace? reverseResult;
  Object? autocompleteError;
  Object? detailsError;
  Object? reverseError;

  int autocompleteCalls = 0;
  int detailsCalls = 0;
  int reverseCalls = 0;
  String? lastInput;
  GeoPoint? lastOrigin;
  bool? lastWorldwide;
  String? lastSessionToken;

  @override
  bool get isConfigured => true;

  @override
  Future<List<PlaceSuggestion>> autocomplete({
    required String input,
    required String sessionToken,
    GeoPoint? origin,
    bool worldwide = false,
    String language = 'en',
    CancelToken? cancelToken,
  }) async {
    autocompleteCalls++;
    lastInput = input;
    lastOrigin = origin;
    lastWorldwide = worldwide;
    lastSessionToken = sessionToken;
    final error = autocompleteError;
    if (error != null) throw error;
    return autocompleteResults;
  }

  @override
  Future<RidePlace> placeDetails({
    required String placeId,
    required String sessionToken,
    String? fallbackName,
    String language = 'en',
    CancelToken? cancelToken,
  }) async {
    detailsCalls++;
    final error = detailsError;
    if (error != null) throw error;
    return detailsResult!;
  }

  @override
  Future<RidePlace> reverseGeocode({
    required double latitude,
    required double longitude,
    RidePlaceSource source = RidePlaceSource.map,
    String language = 'en',
    CancelToken? cancelToken,
  }) async {
    reverseCalls++;
    final error = reverseError;
    if (error != null) throw error;
    return reverseResult!;
  }
}

PlacesRepository _repository(_FakePlacesApi api) {
  return PlacesRepository(_MockSupabaseClient(), placesApi: api);
}

PlaceSuggestion _suggestion(String id, String title, String subtitle) {
  return PlaceSuggestion(
    placeId: id,
    primaryText: title,
    secondaryText: subtitle,
    description: '$title, $subtitle',
  );
}

void main() {
  test('debounces, ranks, and resolves a provider suggestion', () async {
    final api = _FakePlacesApi(
      autocompleteResults: <PlaceSuggestion>[
        _suggestion(
          'place-1',
          'Mlimani City Shopping Mall',
          'Sam Nujoma Road, Dar es Salaam, Tanzania',
        ),
      ],
      detailsResult: const RidePlace(
        id: 'place-1',
        placeId: 'place-1',
        name: 'Mlimani City Shopping Mall',
        district: 'Dar es Salaam',
        latitude: -6.7722783,
        longitude: 39.2196699,
        source: RidePlaceSource.provider,
      ),
    );
    final controller = PlaceSearchController(
      repository: _repository(api),
      debounceDuration: const Duration(milliseconds: 10),
    );
    addTearDown(controller.dispose);

    controller.updateQuery('Mlimani');
    await Future<void>.delayed(const Duration(milliseconds: 60));

    expect(api.autocompleteCalls, 1);
    expect(controller.suggestions, hasLength(1));

    final place = await controller.selectSuggestion(
      controller.suggestions.first,
    );

    expect(place?.placeId, 'place-1');
    expect(place?.source, RidePlaceSource.provider);
    expect(api.detailsCalls, 1);
    expect(controller.resolvingPlaceId, isNull);
  });

  test('pickup and delivery controllers keep independent selections', () async {
    final pickupApi = _FakePlacesApi(
      autocompleteResults: <PlaceSuggestion>[
        _suggestion('pickup', 'Kariakoo Market', 'Dar es Salaam, Tanzania'),
      ],
      detailsResult: const RidePlace(
        id: 'pickup',
        placeId: 'pickup',
        name: 'Kariakoo Market',
        district: 'Dar es Salaam',
        latitude: -6.818,
        longitude: 39.281,
        source: RidePlaceSource.provider,
      ),
    );
    final deliveryApi = _FakePlacesApi(
      autocompleteResults: <PlaceSuggestion>[
        _suggestion('delivery', 'Morogoro Town', 'Morogoro, Tanzania'),
      ],
      detailsResult: const RidePlace(
        id: 'delivery',
        placeId: 'delivery',
        name: 'Morogoro Town',
        district: 'Morogoro',
        latitude: -6.8278,
        longitude: 37.6591,
        source: RidePlaceSource.provider,
      ),
    );

    final pickup = PlaceSearchController(
      repository: _repository(pickupApi),
      debounceDuration: const Duration(milliseconds: 10),
    );
    final delivery = PlaceSearchController(
      repository: _repository(deliveryApi),
      debounceDuration: const Duration(milliseconds: 10),
    );
    addTearDown(pickup.dispose);
    addTearDown(delivery.dispose);

    pickup.updateQuery('Kariakoo');
    delivery.updateQuery('Morogoro');
    await Future<void>.delayed(const Duration(milliseconds: 60));

    final pickupPlace = await pickup.selectSuggestion(pickup.suggestions.first);
    final deliveryPlace = await delivery.selectSuggestion(
      delivery.suggestions.first,
    );

    expect(pickupPlace?.name, 'Kariakoo Market');
    expect(deliveryPlace?.name, 'Morogoro Town');
    expect(pickupPlace?.latitude, isNot(deliveryPlace?.latitude));
    expect(pickup.sessionToken, isNot(delivery.sessionToken));
  });

  test(
    'network failure clears stale results and exposes a retryable error',
    () async {
      final api = _FakePlacesApi()
        ..autocompleteError = const PlacesApiException(
          PlacesErrorType.network,
          'You appear to be offline. Check your connection and try again.',
        );
      final controller = PlaceSearchController(
        repository: _repository(api),
        debounceDuration: const Duration(milliseconds: 10),
      );
      addTearDown(controller.dispose);

      controller.updateQuery('Mlimani');
      await Future<void>.delayed(const Duration(milliseconds: 60));

      expect(controller.suggestions, isEmpty);
      expect(controller.errorMessage, contains('offline'));
      expect(controller.isSearching, isFalse);
    },
  );

  test(
    'a locally resolved saved suggestion does not call Place Details',
    () async {
      final api = _FakePlacesApi();
      final controller = PlaceSearchController(repository: _repository(api));
      addTearDown(controller.dispose);

      const saved = RidePlace(
        id: 'saved-1',
        name: 'Home',
        district: 'Mikocheni, Dar es Salaam',
        latitude: -6.7715,
        longitude: 39.231,
        source: RidePlaceSource.saved,
        label: 'Home',
      );
      final suggestion = PlaceSuggestion.fromRidePlace(saved);

      final result = await controller.selectSuggestion(suggestion);

      expect(result, same(saved));
      expect(api.detailsCalls, 0);
    },
  );

  test(
    'reverse-geocode failure falls back to explicit GPS coordinates',
    () async {
      final api = _FakePlacesApi()
        ..reverseError = const PlacesApiException(
          PlacesErrorType.network,
          'You appear to be offline. Check your connection and try again.',
        );
      final controller = PlaceSearchController(repository: _repository(api));
      addTearDown(controller.dispose);

      final result = await controller.resolveCurrentLocation(
        UserLocation(
          latitude: -6.8,
          longitude: 39.2,
          accuracyMeters: 25,
          timestamp: DateTime.now(),
          source: UserLocationSource.gps,
        ),
      );

      expect(result, isNotNull);
      expect(result!.source, RidePlaceSource.gps);
      expect(result.latitude, -6.8);
      expect(result.longitude, 39.2);
      expect(result.accuracyMeters, 25);
      expect(result.name, 'Current location');
      expect(controller.errorMessage, contains('GPS coordinates'));
    },
  );

  test(
    'repository caches autocomplete, details, and reverse geocoding',
    () async {
      final api = _FakePlacesApi(
        autocompleteResults: <PlaceSuggestion>[
          _suggestion('place-1', 'Mlimani City', 'Dar es Salaam, Tanzania'),
        ],
        detailsResult: const RidePlace(
          id: 'place-1',
          placeId: 'place-1',
          name: 'Mlimani City',
          district: 'Dar es Salaam',
          latitude: -6.772,
          longitude: 39.219,
          source: RidePlaceSource.provider,
        ),
        reverseResult: const RidePlace(
          id: 'reverse',
          name: 'TRA Road',
          district: 'Mwenge, Dar es Salaam',
          latitude: -6.7715,
          longitude: 39.231,
          source: RidePlaceSource.map,
        ),
      );
      final repository = _repository(api);
      const origin = GeoPoint(-6.7715, 39.231);

      await repository.autocompletePlaces(
        query: 'Mlimani',
        sessionToken: 'session-1',
        origin: origin,
      );
      await repository.autocompletePlaces(
        query: 'Mlimani',
        sessionToken: 'session-2',
        origin: origin,
      );
      expect(api.autocompleteCalls, 1);

      await repository.getPlaceDetails(
        placeId: 'place-1',
        sessionToken: 'session-1',
      );
      await repository.getPlaceDetails(
        placeId: 'place-1',
        sessionToken: 'session-2',
      );
      expect(api.detailsCalls, 1);

      await repository.reverseGeocode(
        latitude: -6.77123,
        longitude: 39.23123,
        source: RidePlaceSource.gps,
      );
      final secondReverse = await repository.reverseGeocode(
        latitude: -6.77124,
        longitude: 39.23124,
        source: RidePlaceSource.gps,
      );
      expect(api.reverseCalls, 1);
      // Cached address data must not snap the exact requested coordinates.
      expect(secondReverse.latitude, -6.77124);
      expect(secondReverse.longitude, 39.23124);
    },
  );
}
