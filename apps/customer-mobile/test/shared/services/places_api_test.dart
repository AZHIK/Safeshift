import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safeshift_customer/shared/models/ride_place.dart';
import 'package:safeshift_customer/shared/services/places_api.dart';
import 'package:safeshift_customer/shared/utils/geo.dart';

class _FakeHttpAdapter implements HttpClientAdapter {
  _FakeHttpAdapter(this.handler);

  final Future<ResponseBody> Function(RequestOptions options) handler;
  RequestOptions? lastRequest;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastRequest = options;
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _json(Object body, {int statusCode = 200}) {
  return ResponseBody.fromString(
    jsonEncode(body),
    statusCode,
    headers: <String, List<String>>{
      Headers.contentTypeHeader: <String>[Headers.jsonContentType],
    },
  );
}

GooglePlacesApi _api(_FakeHttpAdapter adapter, {String key = 'test-key'}) {
  final dio = Dio(BaseOptions(baseUrl: 'https://maps.googleapis.com'));
  dio.httpClientAdapter = adapter;
  return GooglePlacesApi(apiKey: key, dio: dio);
}

void main() {
  test(
    'autocomplete sends proximity bias, Tanzania filter, and session token',
    () async {
      final adapter = _FakeHttpAdapter(
        (_) async => _json(<String, dynamic>{
          'status': 'OK',
          'predictions': <dynamic>[
            <String, dynamic>{
              'description':
                  'Mlimani City Shopping Mall, Sam Nujoma Road, '
                  'Dar es Salaam, Tanzania',
              'place_id': 'place-1',
              'structured_formatting': <String, dynamic>{
                'main_text': 'Mlimani City Shopping Mall',
                'secondary_text': 'Sam Nujoma Road, Dar es Salaam, Tanzania',
              },
              'types': <String>['shopping_mall'],
              'distance_meters': 1254,
            },
          ],
        }),
      );
      final api = _api(adapter);

      final results = await api.autocomplete(
        input: 'Mlimani',
        sessionToken: 'session-1',
        origin: const GeoPoint(-6.7715, 39.231),
      );

      expect(results, hasLength(1));
      expect(results.single.placeId, 'place-1');
      expect(results.single.distanceMeters, 1254);

      final query = adapter.lastRequest!.uri.queryParameters;
      expect(query['origin'], '-6.7715,39.231');
      expect(query['location'], '-6.7715,39.231');
      expect(query['radius'], '50000');
      expect(query['components'], 'country:tz');
      expect(query['region'], 'tz');
      expect(query['sessiontoken'], 'session-1');
      expect(query.containsKey('strictbounds'), isFalse);
    },
  );

  test('worldwide search drops the Tanzania country filter', () async {
    final adapter = _FakeHttpAdapter(
      (_) async => _json(<String, dynamic>{'status': 'ZERO_RESULTS'}),
    );
    final api = _api(adapter);

    await api.autocomplete(
      input: 'London',
      sessionToken: 'session-2',
      origin: const GeoPoint(-6.7715, 39.231),
      worldwide: true,
    );

    final query = adapter.lastRequest!.uri.queryParameters;
    expect(query.containsKey('components'), isFalse);
    expect(query.containsKey('region'), isFalse);
  });

  test(
    'place details parses structured address components and coordinates',
    () async {
      final adapter = _FakeHttpAdapter(
        (_) async => _json(<String, dynamic>{
          'status': 'OK',
          'result': <String, dynamic>{
            'place_id': 'place-1',
            'name': 'Mlimani City Shopping Mall',
            'formatted_address': 'Sam Nujoma Rd, Dar es Salaam, Tanzania',
            'geometry': <String, dynamic>{
              'location': <String, dynamic>{
                'lat': -6.7722783,
                'lng': 39.2196699,
              },
            },
            'address_components': <dynamic>[
              <String, dynamic>{
                'long_name': 'Sam Nujoma Road',
                'short_name': 'Sam Nujoma Rd',
                'types': <String>['route'],
              },
              <String, dynamic>{
                'long_name': 'Dar es Salaam',
                'short_name': 'DSM',
                'types': <String>['locality', 'political'],
              },
              <String, dynamic>{
                'long_name': 'Kinondoni',
                'short_name': 'Kinondoni',
                'types': <String>['administrative_area_level_2', 'political'],
              },
              <String, dynamic>{
                'long_name': 'Dar es Salam',
                'short_name': 'Dar es Salam',
                'types': <String>['administrative_area_level_1', 'political'],
              },
              <String, dynamic>{
                'long_name': 'Tanzania',
                'short_name': 'TZ',
                'types': <String>['country', 'political'],
              },
            ],
            'types': <String>['shopping_mall'],
          },
        }),
      );
      final api = _api(adapter);

      final place = await api.placeDetails(
        placeId: 'place-1',
        sessionToken: 'session-3',
      );

      expect(place.placeId, 'place-1');
      expect(place.name, 'Mlimani City Shopping Mall');
      expect(place.latitude, closeTo(-6.7722783, 1e-9));
      expect(place.longitude, closeTo(39.2196699, 1e-9));
      expect(place.street, 'Sam Nujoma Road');
      expect(place.city, 'Dar es Salaam');
      expect(place.region, 'Dar es Salam');
      expect(place.country, 'Tanzania');
      expect(place.source, RidePlaceSource.provider);
      expect(place.isProviderVerified, isTrue);
    },
  );

  test('reverse geocoding prefers a route result over a plus code', () async {
    final adapter = _FakeHttpAdapter(
      (_) async => _json(<String, dynamic>{
        'status': 'OK',
        'results': <dynamic>[
          <String, dynamic>{
            'formatted_address': '66HJ+896, Dar es Salaam, Tanzania',
            'types': <String>['plus_code'],
            'geometry': <String, dynamic>{
              'location': <String, dynamic>{'lat': -6.77, 'lng': 39.23},
            },
            'address_components': <dynamic>[],
          },
          <String, dynamic>{
            'formatted_address': 'TRA Road, Mwenge, Dar es Salaam, Tanzania',
            'types': <String>['route'],
            'geometry': <String, dynamic>{
              'location': <String, dynamic>{'lat': -6.7715, 'lng': 39.231},
            },
            'address_components': <dynamic>[
              <String, dynamic>{
                'long_name': 'TRA Road',
                'short_name': 'TRA Rd',
                'types': <String>['route'],
              },
              <String, dynamic>{
                'long_name': 'Mwenge',
                'short_name': 'Mwenge',
                'types': <String>[
                  'sublocality',
                  'sublocality_level_1',
                  'political',
                ],
              },
              <String, dynamic>{
                'long_name': 'Dar es Salaam',
                'short_name': 'DSM',
                'types': <String>['locality', 'political'],
              },
              <String, dynamic>{
                'long_name': 'Tanzania',
                'short_name': 'TZ',
                'types': <String>['country', 'political'],
              },
            ],
          },
        ],
      }),
    );
    final api = _api(adapter);

    final place = await api.reverseGeocode(
      latitude: -6.7715,
      longitude: 39.231,
      source: RidePlaceSource.gps,
    );

    expect(place.name, contains('TRA Road'));
    expect(place.neighborhood, 'Mwenge');
    expect(place.city, 'Dar es Salaam');
    expect(place.source, RidePlaceSource.gps);
  });

  test('provider errors are sanitized and never expose the API key', () async {
    final adapter = _FakeHttpAdapter(
      (_) async => _json(<String, dynamic>{
        'status': 'REQUEST_DENIED',
        'error_message': 'The provided API key is invalid: test-key',
      }),
    );
    final api = _api(adapter);

    try {
      await api.autocomplete(input: 'Mlimani', sessionToken: 'session-4');
      fail('Expected a PlacesApiException');
    } on PlacesApiException catch (error) {
      expect(error.isConfigurationError, isTrue);
      expect(error.message, isNot(contains('test-key')));
      expect(error.toString(), isNot(contains('test-key')));
    }
  });

  test('HTTP 429 maps to a rate-limit error', () async {
    final adapter = _FakeHttpAdapter(
      (_) async => _json(<String, dynamic>{'error': 'quota'}, statusCode: 429),
    );
    final api = _api(adapter);

    await expectLater(
      api.autocomplete(input: 'Mlimani', sessionToken: 'session-5'),
      throwsA(
        isA<PlacesApiException>().having(
          (error) => error.type,
          'type',
          PlacesErrorType.rateLimited,
        ),
      ),
    );
  });

  test('missing API key fails without making a network request', () async {
    var called = false;
    final adapter = _FakeHttpAdapter((_) async {
      called = true;
      return _json(<String, dynamic>{'status': 'OK'});
    });
    final api = _api(adapter, key: '');

    await expectLater(
      api.autocomplete(input: 'Mlimani', sessionToken: 'session-6'),
      throwsA(
        isA<PlacesApiException>().having(
          (error) => error.type,
          'type',
          PlacesErrorType.notConfigured,
        ),
      ),
    );
    expect(called, isFalse);
  });
}
