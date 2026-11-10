import 'package:dio/dio.dart';

import '../models/place_suggestion.dart';
import '../models/ride_place.dart';
import '../utils/geo.dart';

/// User-safe categories for place-provider failures.
enum PlacesErrorType {
  notConfigured,
  network,
  timeout,
  rateLimited,
  invalidRequest,
  notFound,
  server,
  unknown,
  cancelled,
}

/// A sanitized place-provider error.
///
/// Raw provider payloads and request URLs are deliberately not exposed because
/// they can contain the API key.
class PlacesApiException implements Exception {
  const PlacesApiException(
    this.type,
    this.message, {
    this.statusCode,
    this.providerStatus,
  });

  final PlacesErrorType type;

  /// User-facing message.
  final String message;
  final int? statusCode;

  /// Provider status such as `REQUEST_DENIED` or `OVER_QUERY_LIMIT`.
  final String? providerStatus;

  bool get isCancellation => type == PlacesErrorType.cancelled;

  bool get isConfigurationError =>
      type == PlacesErrorType.notConfigured ||
      (type == PlacesErrorType.invalidRequest &&
          providerStatus == 'REQUEST_DENIED');

  @override
  String toString() => 'PlacesApiException($type)';
}

/// Provider-agnostic contract used by [PlacesRepository].
abstract interface class PlacesApi {
  bool get isConfigured;

  Future<List<PlaceSuggestion>> autocomplete({
    required String input,
    required String sessionToken,
    GeoPoint? origin,
    bool worldwide = false,
    String language = 'en',
    CancelToken? cancelToken,
  });

  Future<RidePlace> placeDetails({
    required String placeId,
    required String sessionToken,
    String? fallbackName,
    String language = 'en',
    CancelToken? cancelToken,
  });

  Future<RidePlace> reverseGeocode({
    required double latitude,
    required double longitude,
    RidePlaceSource source = RidePlaceSource.map,
    String language = 'en',
    CancelToken? cancelToken,
  });
}

/// Google Places/Geocoding REST client.
///
/// The API key is a client key injected through `--dart-define`. It is never
/// logged, and every [DioException] is converted into a sanitized
/// [PlacesApiException] before leaving this class.
class GooglePlacesApi implements PlacesApi {
  GooglePlacesApi({
    required String apiKey,
    Dio? dio,
    String baseUrl = 'https://maps.googleapis.com',
  }) : _apiKey = apiKey.trim(),
       _dio = dio ?? _defaultDio(baseUrl);

  final String _apiKey;
  final Dio _dio;

  static Dio _defaultDio(String baseUrl) {
    return Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 8),
        sendTimeout: const Duration(seconds: 8),
        receiveTimeout: const Duration(seconds: 12),
        responseType: ResponseType.json,
        headers: const <String, dynamic>{'Accept': 'application/json'},
      ),
    );
  }

  @override
  bool get isConfigured => _apiKey.isNotEmpty;

  @override
  Future<List<PlaceSuggestion>> autocomplete({
    required String input,
    required String sessionToken,
    GeoPoint? origin,
    bool worldwide = false,
    String language = 'en',
    CancelToken? cancelToken,
  }) async {
    _ensureConfigured();
    final query = input.trim();
    if (query.length < 2) return const <PlaceSuggestion>[];

    final params = <String, dynamic>{
      'input': query,
      'language': language,
      'sessiontoken': sessionToken,
    };

    if (origin != null && origin.isValid) {
      // `origin` enables distance_meters, while `location` + `radius` applies
      // a soft proximity bias. `strictbounds` is intentionally not set so the
      // customer can still find places in other cities.
      params['origin'] = '${origin.latitude},${origin.longitude}';
      params['location'] = '${origin.latitude},${origin.longitude}';
      params['radius'] = 50000;
    }

    if (!worldwide) {
      // Tanzania is the default context. This is a country filter, not a
      // small-radius restriction, so Dodoma, Mbeya, Arusha, Mwanza, etc.
      // remain discoverable. The UI can switch to worldwide search.
      params['components'] = 'country:tz';
      params['region'] = 'tz';
    }

    final data = await _get(
      '/maps/api/place/autocomplete/json',
      params,
      cancelToken: cancelToken,
    );

    final status = _status(data);
    if (status == 'ZERO_RESULTS') return const <PlaceSuggestion>[];
    _ensureOk(status, providerStatus: status);

    final predictions = (data['predictions'] as List?) ?? const <dynamic>[];
    final suggestions = <PlaceSuggestion>[];
    for (final raw in predictions) {
      if (raw is! Map) continue;
      final map = raw.cast<String, dynamic>();
      final structured =
          (map['structured_formatting'] as Map?)?.cast<String, dynamic>() ??
          const <String, dynamic>{};
      final description = (map['description'] as String? ?? '').trim();
      var primary = (structured['main_text'] as String? ?? '').trim();
      var secondary = (structured['secondary_text'] as String? ?? '').trim();
      final placeId = (map['place_id'] as String? ?? '').trim();
      if (placeId.isEmpty) continue;

      // Defensive fallback for responses without structured_formatting: split
      // the description so the row still has real context instead of repeating
      // the place name.
      if (primary.isEmpty && description.isNotEmpty) {
        final comma = description.indexOf(',');
        if (comma > 0) {
          primary = description.substring(0, comma).trim();
          secondary = description.substring(comma + 1).trim();
        } else {
          primary = description;
        }
      }

      suggestions.add(
        PlaceSuggestion(
          placeId: placeId,
          primaryText: primary,
          secondaryText: secondary,
          description: description,
          types: _stringList(map['types']),
          distanceMeters: (map['distance_meters'] as num?)?.toDouble(),
        ),
      );
    }
    return suggestions;
  }

  @override
  Future<RidePlace> placeDetails({
    required String placeId,
    required String sessionToken,
    String? fallbackName,
    String language = 'en',
    CancelToken? cancelToken,
  }) async {
    _ensureConfigured();
    final id = placeId.trim();
    if (id.isEmpty) {
      throw const PlacesApiException(
        PlacesErrorType.invalidRequest,
        'That place could not be identified. Please choose another result.',
      );
    }

    final data = await _get('/maps/api/place/details/json', <String, dynamic>{
      'place_id': id,
      'fields':
          'place_id,name,formatted_address,geometry,address_components,types',
      'language': language,
      'sessiontoken': sessionToken,
    }, cancelToken: cancelToken);

    final status = _status(data);
    if (status == 'NOT_FOUND' || status == 'ZERO_RESULTS') {
      throw const PlacesApiException(
        PlacesErrorType.notFound,
        'That place could not be found. Try another result.',
      );
    }
    _ensureOk(status, providerStatus: status);

    final result = (data['result'] as Map?)?.cast<String, dynamic>();
    if (result == null) {
      throw const PlacesApiException(
        PlacesErrorType.notFound,
        'That place could not be found. Try another result.',
      );
    }

    return _placeFromResult(
      result,
      source: RidePlaceSource.provider,
      fallbackName: fallbackName,
    );
  }

  @override
  Future<RidePlace> reverseGeocode({
    required double latitude,
    required double longitude,
    RidePlaceSource source = RidePlaceSource.map,
    String language = 'en',
    CancelToken? cancelToken,
  }) async {
    _ensureConfigured();
    final point = GeoPoint(latitude, longitude);
    if (!point.isValid) {
      throw const PlacesApiException(
        PlacesErrorType.invalidRequest,
        'Those coordinates are not valid.',
      );
    }

    final data = await _get('/maps/api/geocode/json', <String, dynamic>{
      'latlng': '${point.latitude},${point.longitude}',
      'language': language,
    }, cancelToken: cancelToken);

    final status = _status(data);
    if (status == 'ZERO_RESULTS') {
      throw const PlacesApiException(
        PlacesErrorType.notFound,
        'No address was found for that point. Try a nearby location.',
      );
    }
    _ensureOk(status, providerStatus: status);

    final results = (data['results'] as List?) ?? const <dynamic>[];
    final result = _bestReverseGeocodeResult(results);
    if (result == null) {
      throw const PlacesApiException(
        PlacesErrorType.notFound,
        'No address was found for that point. Try a nearby location.',
      );
    }

    return _placeFromResult(
      result,
      source: source,
      fallbackName: 'Pinned location',
    );
  }

  Future<Map<String, dynamic>> _get(
    String path,
    Map<String, dynamic> query, {
    CancelToken? cancelToken,
  }) async {
    _ensureConfigured();
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        path,
        queryParameters: <String, dynamic>{...query, 'key': _apiKey},
        cancelToken: cancelToken,
        options: Options(responseType: ResponseType.json),
      );
      final data = response.data;
      if (data == null) {
        throw const PlacesApiException(
          PlacesErrorType.server,
          'Place search returned an empty response. Please try again.',
        );
      }
      return data;
    } on DioException catch (error) {
      throw _mapDioException(error);
    } on PlacesApiException {
      rethrow;
    } catch (_) {
      throw const PlacesApiException(
        PlacesErrorType.unknown,
        'Something went wrong while searching. Please try again.',
      );
    }
  }

  PlacesApiException _mapDioException(DioException error) {
    switch (error.type) {
      case DioExceptionType.cancel:
        return const PlacesApiException(
          PlacesErrorType.cancelled,
          'Search cancelled.',
        );
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
        return const PlacesApiException(
          PlacesErrorType.timeout,
          'Place search timed out. Please try again.',
        );
      case DioExceptionType.connectionError:
      case DioExceptionType.badCertificate:
      case DioExceptionType.unknown:
        return const PlacesApiException(
          PlacesErrorType.network,
          'You appear to be offline. Check your connection and try again.',
        );
      case DioExceptionType.badResponse:
        final statusCode = error.response?.statusCode;
        if (statusCode == 429) {
          return const PlacesApiException(
            PlacesErrorType.rateLimited,
            'Too many searches right now. Please wait a moment and try again.',
            statusCode: 429,
          );
        }
        if (statusCode == 401 || statusCode == 403) {
          return const PlacesApiException(
            PlacesErrorType.invalidRequest,
            'Place search is not available. Check the Google Maps configuration.',
            providerStatus: 'REQUEST_DENIED',
          );
        }
        if (statusCode != null && statusCode >= 500) {
          return PlacesApiException(
            PlacesErrorType.server,
            'Place search is unavailable right now. Please try again.',
            statusCode: statusCode,
          );
        }
        return PlacesApiException(
          PlacesErrorType.invalidRequest,
          'Place search could not complete that request. Try a different place.',
          statusCode: statusCode,
        );
    }
  }

  void _ensureConfigured() {
    if (!isConfigured) {
      throw const PlacesApiException(
        PlacesErrorType.notConfigured,
        'Place search is not configured. Add a Google Maps API key to enable it.',
      );
    }
  }

  String _status(Map<String, dynamic> data) {
    return (data['status'] as String? ?? '').trim().toUpperCase();
  }

  void _ensureOk(String status, {String? providerStatus}) {
    switch (status) {
      case 'OK':
      case 'ZERO_RESULTS':
        return;
      case 'OVER_QUERY_LIMIT':
      case 'OVER_DAILY_LIMIT':
        throw const PlacesApiException(
          PlacesErrorType.rateLimited,
          'Too many searches right now. Please wait a moment and try again.',
          providerStatus: 'OVER_QUERY_LIMIT',
        );
      case 'REQUEST_DENIED':
        throw const PlacesApiException(
          PlacesErrorType.invalidRequest,
          'Place search is not available. Check the Google Maps configuration.',
          providerStatus: 'REQUEST_DENIED',
        );
      case 'INVALID_REQUEST':
        throw const PlacesApiException(
          PlacesErrorType.invalidRequest,
          'Place search could not complete that request. Try a different place.',
          providerStatus: 'INVALID_REQUEST',
        );
      case 'NOT_FOUND':
        throw const PlacesApiException(
          PlacesErrorType.notFound,
          'That place could not be found. Try another result.',
          providerStatus: 'NOT_FOUND',
        );
      case 'UNKNOWN_ERROR':
        throw const PlacesApiException(
          PlacesErrorType.server,
          'Place search is unavailable right now. Please try again.',
          providerStatus: 'UNKNOWN_ERROR',
        );
      default:
        throw PlacesApiException(
          PlacesErrorType.unknown,
          'Something went wrong while searching. Please try again.',
          providerStatus: providerStatus ?? status,
        );
    }
  }

  RidePlace _placeFromResult(
    Map<String, dynamic> result, {
    required RidePlaceSource source,
    String? fallbackName,
  }) {
    final geometry = (result['geometry'] as Map?)?.cast<String, dynamic>();
    final location = (geometry?['location'] as Map?)?.cast<String, dynamic>();
    final latitude = (location?['lat'] as num?)?.toDouble();
    final longitude = (location?['lng'] as num?)?.toDouble();
    if (latitude == null || longitude == null) {
      throw const PlacesApiException(
        PlacesErrorType.invalidRequest,
        'That place has no usable coordinates. Try another result.',
      );
    }
    final point = GeoPoint(latitude, longitude);
    if (!point.isValid) {
      throw const PlacesApiException(
        PlacesErrorType.invalidRequest,
        'That place has invalid coordinates. Try another result.',
      );
    }

    final components = _AddressComponents.from(result['address_components']);
    final formattedAddress = (result['formatted_address'] as String? ?? '')
        .trim();
    final providerName = (result['name'] as String? ?? '').trim();
    final placeId = (result['place_id'] as String? ?? '').trim();
    final name = _displayName(
      providerName: providerName,
      components: components,
      formattedAddress: formattedAddress,
      fallbackName: fallbackName,
    );

    return RidePlace(
      id: placeId.isNotEmpty
          ? placeId
          : '${latitude.toStringAsFixed(6)},${longitude.toStringAsFixed(6)}',
      placeId: placeId.isNotEmpty ? placeId : null,
      name: name,
      district: _districtLabel(components, formattedAddress),
      latitude: latitude,
      longitude: longitude,
      formattedAddress: formattedAddress.isEmpty ? null : formattedAddress,
      street: components.street,
      neighborhood: components.neighborhood,
      ward: components.ward,
      city: components.city,
      region: components.region,
      country: components.country,
      postalCode: components.postalCode,
      source: source,
      types: _stringList(result['types']),
      capturedAt: DateTime.now(),
    );
  }

  String _displayName({
    required String providerName,
    required _AddressComponents components,
    required String formattedAddress,
    String? fallbackName,
  }) {
    if (providerName.isNotEmpty) return providerName;

    final street = components.street;
    if (street != null && street.isNotEmpty) {
      final neighborhood = components.neighborhood;
      if (neighborhood != null &&
          neighborhood.isNotEmpty &&
          !street.toLowerCase().contains(neighborhood.toLowerCase())) {
        return '$street, $neighborhood';
      }
      return street;
    }

    final neighborhood = components.neighborhood;
    if (neighborhood != null && neighborhood.isNotEmpty) return neighborhood;

    final city = components.city;
    if (city != null && city.isNotEmpty) return city;

    if (formattedAddress.isNotEmpty) {
      final first = formattedAddress.split(',').first.trim();
      if (first.isNotEmpty) return first;
    }

    final fallback = fallbackName?.trim() ?? '';
    return fallback.isNotEmpty ? fallback : 'Selected location';
  }

  String _districtLabel(
    _AddressComponents components,
    String formattedAddress,
  ) {
    final parts = <String>[];
    void add(String? value) {
      final text = value?.trim() ?? '';
      if (text.isEmpty) return;
      if (parts.isNotEmpty && parts.last.toLowerCase() == text.toLowerCase()) {
        return;
      }
      parts.add(text);
    }

    add(components.neighborhood);
    add(components.city);
    if (parts.isEmpty) {
      add(components.ward);
      add(components.region);
    }
    if (parts.isNotEmpty) return parts.join(', ');

    final segments = formattedAddress
        .split(',')
        .map((segment) => segment.trim())
        .where((segment) => segment.isNotEmpty)
        .toList(growable: false);
    if (segments.length >= 2) {
      return segments.sublist(segments.length - 2).join(', ');
    }
    return formattedAddress;
  }

  Map<String, dynamic>? _bestReverseGeocodeResult(List<dynamic> results) {
    Map<String, dynamic>? plusCodeFallback;
    Map<String, dynamic>? firstUsable;
    for (final raw in results) {
      if (raw is! Map) continue;
      final map = raw.cast<String, dynamic>();
      final types = _stringList(map['types']).toSet();
      final isPlusCode = types.length == 1 && types.contains('plus_code');
      if (isPlusCode) {
        plusCodeFallback ??= map;
        continue;
      }
      firstUsable ??= map;
      if (types.any(
        const <String>{
          'street_address',
          'premise',
          'subpremise',
          'point_of_interest',
          'establishment',
          'route',
        }.contains,
      )) {
        return map;
      }
    }
    return firstUsable ?? plusCodeFallback;
  }

  List<String> _stringList(Object? value) {
    if (value is! List) return const <String>[];
    return value
        .whereType<String>()
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }
}

class _AddressComponents {
  const _AddressComponents({
    this.street,
    this.neighborhood,
    this.ward,
    this.city,
    this.region,
    this.country,
    this.postalCode,
  });

  factory _AddressComponents.from(Object? raw) {
    final byType = <String, String>{};
    if (raw is List) {
      for (final item in raw) {
        if (item is! Map) continue;
        final map = item.cast<String, dynamic>();
        final longName =
            (map['long_name'] as String? ?? map['short_name'] as String? ?? '')
                .trim();
        if (longName.isEmpty) continue;
        final types =
            (map['types'] as List?)
                ?.whereType<String>()
                .map((type) => type.trim())
                .where((type) => type.isNotEmpty) ??
            const <String>[];
        for (final type in types) {
          byType.putIfAbsent(type, () => longName);
        }
      }
    }

    String? pick(List<String> keys) {
      for (final key in keys) {
        final value = byType[key]?.trim();
        if (value != null && value.isNotEmpty) return value;
      }
      return null;
    }

    final streetNumber = pick(const <String>['street_number']);
    final route = pick(const <String>['route']);
    final street = <String>[?streetNumber, ?route].join(' ').trim();

    return _AddressComponents(
      street: street.isEmpty ? null : street,
      neighborhood: pick(const <String>[
        'neighborhood',
        'sublocality_level_1',
        'sublocality',
        'sublocality_level_2',
      ]),
      ward: pick(const <String>[
        'administrative_area_level_3',
        'sublocality_level_2',
      ]),
      city: pick(const <String>[
        'locality',
        'postal_town',
        'administrative_area_level_2',
      ]),
      region: pick(const <String>['administrative_area_level_1']),
      country: pick(const <String>['country']),
      postalCode: pick(const <String>['postal_code']),
    );
  }

  final String? street;
  final String? neighborhood;
  final String? ward;
  final String? city;
  final String? region;
  final String? country;
  final String? postalCode;
}
