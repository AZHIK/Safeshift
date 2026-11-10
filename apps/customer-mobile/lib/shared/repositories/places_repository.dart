import 'package:dio/dio.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/env_config.dart';
import '../models/place_suggestion.dart';
import '../models/ride_place.dart';
import '../services/places_api.dart';
import '../utils/geo.dart';
import '../utils/place_ranking.dart';

/// Single access point for saved addresses and provider place search.
///
/// Both pickup and delivery flows share this repository, so autocomplete,
/// Place Details, and reverse geocoding are implemented once. Results are
/// cached in memory to avoid duplicate provider calls during a session.
class PlacesRepository {
  PlacesRepository(this._client, {PlacesApi? placesApi})
    : _placesApi =
          placesApi ?? GooglePlacesApi(apiKey: EnvConfig.googleMapsApiKey);

  final SupabaseClient _client;
  final PlacesApi _placesApi;

  final Map<String, _CacheEntry<List<PlaceSuggestion>>> _autocompleteCache =
      <String, _CacheEntry<List<PlaceSuggestion>>>{};
  final Map<String, _CacheEntry<RidePlace>> _detailsCache =
      <String, _CacheEntry<RidePlace>>{};
  final Map<String, _CacheEntry<RidePlace>> _reverseCache =
      <String, _CacheEntry<RidePlace>>{};

  static const Duration _autocompleteTtl = Duration(minutes: 5);
  static const Duration _detailsTtl = Duration(hours: 24);
  static const Duration _reverseTtl = Duration(hours: 1);
  static const int _maxCacheEntries = 100;

  /// Whether a client-side Google Places key is available.
  bool get isProviderConfigured => _placesApi.isConfigured;

  Future<List<RidePlace>> getSavedPlaces(String profileId) async {
    try {
      final rows = await _client.rpc<List<dynamic>>('customer_saved_places');
      final places = rows
          .map(
            (row) => _placeFromRpc(
              (row as Map).cast<String, dynamic>(),
              source: RidePlaceSource.saved,
            ),
          )
          .whereType<RidePlace>()
          .toList(growable: false);
      if (places.isNotEmpty || rows.isNotEmpty) return places;
    } catch (_) {
      // Fall back to direct table access when the RPC is unavailable.
    }

    final rows = await _client
        .from('saved_addresses')
        .select(
          'id, address_id, label, is_default, '
          'addresses(id, line_1, line_2, landmark, location, '
          'neighborhoods(name), cities(name))',
        )
        .eq('profile_id', profileId)
        .order('is_default', ascending: false)
        .order('created_at', ascending: false);

    final places = <RidePlace>[];
    for (final row in rows) {
      final place = _savedPlaceFromRow(row);
      if (place != null) places.add(place);
    }
    return places;
  }

  /// Location-aware autocomplete.
  ///
  /// The [origin] is a soft proximity reference. It is never used as the
  /// customer's selected pickup/delivery point.
  Future<List<PlaceSuggestion>> autocompletePlaces({
    required String query,
    required String sessionToken,
    GeoPoint? origin,
    bool worldwide = false,
    String language = 'en',
    CancelToken? cancelToken,
  }) async {
    final normalized = query.trim();
    if (normalized.length < 2) return const <PlaceSuggestion>[];

    final cacheKey =
        '${normalized.toLowerCase()}|${_referenceKey(origin)}|'
        '$worldwide|$language';
    final cached = _read(_autocompleteCache, cacheKey, _autocompleteTtl);
    if (cached != null) return cached;

    final suggestions = await _placesApi.autocomplete(
      input: normalized,
      sessionToken: sessionToken,
      origin: origin,
      worldwide: worldwide,
      language: language,
      cancelToken: cancelToken,
    );
    final ranked = rankAndDedupeSuggestions(suggestions, query: normalized);
    _write(_autocompleteCache, cacheKey, ranked);
    return ranked;
  }

  /// Resolves a provider suggestion to verified coordinates and a structured
  /// address. Repeated selections of the same place reuse the cached details.
  Future<RidePlace> getPlaceDetails({
    required String placeId,
    required String sessionToken,
    String? fallbackName,
    String language = 'en',
    CancelToken? cancelToken,
  }) async {
    final id = placeId.trim();
    final cacheKey = '$id|$language';
    final cached = _read(_detailsCache, cacheKey, _detailsTtl);
    if (cached != null) return cached;

    final place = await _placesApi.placeDetails(
      placeId: id,
      sessionToken: sessionToken,
      fallbackName: fallbackName,
      language: language,
      cancelToken: cancelToken,
    );
    _write(_detailsCache, cacheKey, place);
    return place;
  }

  /// Converts GPS or map coordinates into a readable address while preserving
  /// the exact requested coordinates.
  Future<RidePlace> reverseGeocode({
    required double latitude,
    required double longitude,
    RidePlaceSource source = RidePlaceSource.gps,
    String language = 'en',
    CancelToken? cancelToken,
  }) async {
    final cacheKey =
        '${latitude.toStringAsFixed(4)},${longitude.toStringAsFixed(4)}|'
        '$language';
    final cached = _read(_reverseCache, cacheKey, _reverseTtl);
    if (cached != null) {
      return cached.copyWith(
        latitude: latitude,
        longitude: longitude,
        source: source,
        capturedAt: DateTime.now(),
      );
    }

    final place = await _placesApi.reverseGeocode(
      latitude: latitude,
      longitude: longitude,
      source: source,
      language: language,
      cancelToken: cancelToken,
    );
    _write(_reverseCache, cacheKey, place);
    return place;
  }

  /// Searches saved/user addresses and, when supported by the backend, a safe
  /// public catalog (e.g. neighborhoods). Prefer the `customer_search_places`
  /// RPC; it avoids PostGIS parsing issues and RLS surprises.
  ///
  /// This is also the offline/degraded fallback when the Places provider is
  /// unavailable.
  Future<List<RidePlace>> searchPlaces(String profileId, String query) async {
    final q = query.trim();
    try {
      final rows = await _client.rpc<List<dynamic>>(
        'customer_search_places',
        params: <String, dynamic>{'p_query': q, 'p_limit': 20},
      );
      return rows
          .map(
            (row) => _placeFromRpc(
              (row as Map).cast<String, dynamic>(),
              source: _catalogSource(row['source']),
            ),
          )
          .whereType<RidePlace>()
          .toList(growable: false);
    } catch (_) {
      // Fall back for environments without migration 0128.
    }
    return _searchMyAddressesFallback(profileId, q);
  }

  @Deprecated('Use searchPlaces; kept for compatibility.')
  Future<List<RidePlace>> searchMyAddresses(String profileId, String query) =>
      searchPlaces(profileId, query);

  Future<List<RidePlace>> _searchMyAddressesFallback(
    String profileId,
    String query,
  ) async {
    if (query.isEmpty) return getSavedPlaces(profileId);

    // Search addresses created by the user (RLS allows own rows).
    final rows = await _client
        .from('addresses')
        .select(
          'id, line_1, line_2, landmark, location, neighborhoods(name), cities(name)',
        )
        .eq('created_by', profileId)
        .or(
          'line_1.ilike.%$query%,landmark.ilike.%$query%,line_2.ilike.%$query%',
        )
        .limit(20);

    final places = <RidePlace>[];
    for (final row in rows) {
      final place = _addressPlaceFromRow(row);
      if (place != null) places.add(place);
    }
    return places;
  }

  RidePlaceSource _catalogSource(Object? value) {
    final source = value is String ? value.trim().toLowerCase() : '';
    return source == 'neighborhood'
        ? RidePlaceSource.catalog
        : RidePlaceSource.saved;
  }

  RidePlace? _placeFromRpc(
    Map<String, dynamic> row, {
    required RidePlaceSource source,
  }) {
    final lat = (row['latitude'] as num?)?.toDouble();
    final lng = (row['longitude'] as num?)?.toDouble();
    if (lat == null || lng == null) return null;
    final name = (row['name'] as String?)?.trim();
    if (name == null || name.isEmpty) return null;
    // `place_id` in these RPCs is a local saved-address/neighborhood
    // identifier, not a provider (Google) place ID. Keep it as the local id
    // and never send it to Place Details.
    final id = '${row['place_id'] ?? row['address_id'] ?? name}';
    return RidePlace(
      id: id,
      addressId: row['address_id'] as String?,
      label: row['label'] as String?,
      name: name,
      district: (row['district'] as String?)?.trim() ?? '',
      latitude: lat,
      longitude: lng,
      source: source,
    );
  }

  RidePlace? _savedPlaceFromRow(Map<String, dynamic> row) {
    final address = row['addresses'];
    if (address is! Map) return null;
    final addr = address.cast<String, dynamic>();
    final point = parseGeoPoint(addr['location']);
    if (point == null) return null;
    final label = row['label'] as String?;
    final line1 = addr['line_1'] as String? ?? 'Saved place';
    final district = _district(addr);
    return RidePlace(
      id: row['id'] as String,
      addressId: (row['address_id'] ?? addr['id']) as String?,
      label: label,
      name: label?.isNotEmpty == true ? label! : line1,
      district: district.isNotEmpty
          ? district
          : (addr['landmark'] as String? ?? ''),
      latitude: point.latitude,
      longitude: point.longitude,
      source: RidePlaceSource.saved,
    );
  }

  RidePlace? _addressPlaceFromRow(Map<String, dynamic> row) {
    final point = parseGeoPoint(row['location']);
    if (point == null) return null;
    final line1 = row['line_1'] as String? ?? 'Address';
    final district = _district(row);
    return RidePlace(
      id: row['id'] as String,
      addressId: row['id'] as String?,
      name: line1,
      district: district.isNotEmpty
          ? district
          : (row['landmark'] as String? ?? ''),
      latitude: point.latitude,
      longitude: point.longitude,
      source: RidePlaceSource.saved,
    );
  }

  String _district(Map<String, dynamic> row) {
    final neighborhood = row['neighborhoods'];
    if (neighborhood is Map) {
      final name = neighborhood['name'];
      if (name is String && name.isNotEmpty) return name;
    }
    final city = row['cities'];
    if (city is Map) {
      final name = city['name'];
      if (name is String && name.isNotEmpty) return name;
    }
    return '';
  }

  String _referenceKey(GeoPoint? origin) {
    if (origin == null || !origin.isValid) return 'none';
    return '${origin.latitude.toStringAsFixed(3)},'
        '${origin.longitude.toStringAsFixed(3)}';
  }

  T? _read<T>(Map<String, _CacheEntry<T>> cache, String key, Duration ttl) {
    final entry = cache[key];
    if (entry == null) return null;
    if (DateTime.now().difference(entry.storedAt) > ttl) {
      cache.remove(key);
      return null;
    }
    return entry.value;
  }

  void _write<T>(Map<String, _CacheEntry<T>> cache, String key, T value) {
    // Move updated keys to the end so eviction removes the least recently
    // written entry, not a key that was just refreshed.
    cache.remove(key);
    if (cache.length >= _maxCacheEntries) {
      // Dart maps preserve insertion order, so the first key is the oldest.
      cache.remove(cache.keys.first);
    }
    cache[key] = _CacheEntry<T>(value, DateTime.now());
  }
}

class _CacheEntry<T> {
  const _CacheEntry(this.value, this.storedAt);

  final T value;
  final DateTime storedAt;
}
