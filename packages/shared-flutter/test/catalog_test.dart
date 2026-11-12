import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:safeshift_shared/safeshift_shared.dart';
import 'package:supabase/supabase.dart';

/// Builds a Supabase client whose REST calls are answered locally.
///
/// Every request is recorded so the test can assert on the query the
/// catalogue actually sent to PostgREST.
SupabaseClient _client({
  required List<Map<String, dynamic>> vehicleTypes,
  required List<Map<String, dynamic>> cargoTypes,
  String? profileCountryId,
  List<Uri>? requests,
}) {
  return SupabaseClient(
    'https://project.supabase.co',
    'anon-key',
    httpClient: MockClient((request) async {
      requests?.add(request.url);
      final path = request.url.path;
      final Object body;
      if (path.endsWith('/vehicle_types')) {
        body = vehicleTypes;
      } else if (path.endsWith('/cargo_types')) {
        body = cargoTypes;
      } else if (path.endsWith('/profiles')) {
        body = <Map<String, dynamic>>[
          <String, dynamic>{'default_country_id': profileCountryId},
        ];
      } else {
        body = <Map<String, dynamic>>[];
      }
      return http.Response(
        jsonEncode(body),
        200,
        request: request,
        headers: <String, String>{'content-type': 'application/json'},
      );
    }),
  );
}

void main() {
  group('CatalogIcons', () {
    const base = 'https://project.supabase.co';

    test('resolves a bucket-relative path against the project URL', () {
      expect(
        CatalogIcons.resolve('vehicle/pickup.svg', base),
        'https://project.supabase.co/storage/v1/object/public/'
        'catalog-icons/vehicle/pickup.svg',
      );
    });

    test('keeps an absolute URL untouched', () {
      expect(
        CatalogIcons.resolve('https://cdn.example.com/truck.svg', base),
        'https://cdn.example.com/truck.svg',
      );
    });

    test('returns null when the row has no icon', () {
      expect(CatalogIcons.resolve(null, base), isNull);
      expect(CatalogIcons.resolve('   ', base), isNull);
    });

    test('detects SVG icons', () {
      expect(CatalogIcons.isSvg('https://x/y/pickup.svg'), isTrue);
      expect(CatalogIcons.isSvg('https://x/y/pickup.png'), isFalse);
    });
  });

  group('VehicleTypeOption', () {
    test('labels the capacity in tonnes above 1000 kg', () {
      expect(
        const VehicleTypeOption(
          id: '1',
          code: 'large',
          name: 'Large',
          capacityKgMax: 10000,
        ).capacityLabel,
        'Up to 10 tonnes',
      );
    });

    test('labels the capacity in kilograms below 1000 kg', () {
      expect(
        const VehicleTypeOption(
          id: '1',
          code: 'van',
          name: 'Van',
          capacityKgMax: 1500,
        ).capacityLabel,
        'Up to 1 tonne',
      );
    });
  });

  group('CatalogRepository.getVehicleTypes', () {
    test('scopes the query to the country and maps the rows', () async {
      final requests = <Uri>[];
      final client = _client(
        vehicleTypes: <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'vt-1',
            'code': 'pickup',
            'name': 'Pickup',
            'description': 'Open-bed pickup',
            'icon_url': 'vehicle/pickup.svg',
            'capacity_kg_min': 1000,
            'capacity_kg_max': 2000,
            'display_order': 20,
            'requires_special_licence': false,
            'number_of_wheels': 4,
          },
        ],
        cargoTypes: const <Map<String, dynamic>>[],
        requests: requests,
      );

      final types = await CatalogRepository(client).getVehicleTypes(
        countryId: 'tz',
      );

      expect(types, hasLength(1));
      expect(types.single.code, 'pickup');
      expect(types.single.name, 'Pickup');
      expect(types.single.iconUrl, 'vehicle/pickup.svg');
      expect(types.single.capacityKgMax, 2000);
      expect(types.single.capacityLabel, 'Up to 2 tonnes');

      final url = requests.single;
      expect(url.path, endsWith('/vehicle_types'));
      expect(url.queryParameters['or'], '(country_id.is.null,country_id.eq.tz)');
    });

    test('returns every active row when no country scope is given', () async {
      final requests = <Uri>[];
      final client = _client(
        vehicleTypes: const <Map<String, dynamic>>[],
        cargoTypes: const <Map<String, dynamic>>[],
        requests: requests,
      );

      await CatalogRepository(client).getVehicleTypes(countryId: '');

      final url = requests.single;
      expect(url.queryParameters.containsKey('or'), isFalse);
      expect(url.queryParameters['is_active'], 'eq.true');
    });
  });

  group('CatalogRepository.getCargoTypes', () {
    test('maps the catalogue row, including the icon and flags', () async {
      final requests = <Uri>[];
      final client = _client(
        vehicleTypes: const <Map<String, dynamic>>[],
        cargoTypes: <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'ct-1',
            'code': 'furniture',
            'name': 'Furniture',
            'description': null,
            'icon_url': 'cargo/furniture.svg',
            'display_order': 20,
            'category_id': 'cat-1',
            'requires_special_handling': false,
            'requires_declared_value': true,
            'requires_insurance': false,
            'max_value_tzs': 5000000,
            'allowed_vehicle_type_codes': <String>['pickup'],
            'prohibited_vehicle_type_codes': <String>[],
          },
        ],
        requests: requests,
      );

      final types = await CatalogRepository(client).getCargoTypes(
        countryId: 'tz',
      );

      expect(types, hasLength(1));
      expect(types.single.name, 'Furniture');
      expect(types.single.iconUrl, 'cargo/furniture.svg');
      expect(types.single.requiresDeclaredValue, isTrue);
      expect(types.single.allowedVehicleTypeCodes, <String>['pickup']);
      expect(types.single.maxValueTzs, 5000000);
      expect(types.single.needsAttention, isTrue);
    });
  });
}
