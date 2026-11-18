import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:safeshift_customer/features/ride/data/ride_repository.dart';
import 'package:safeshift_customer/shared/models/ride_place.dart';
import 'package:safeshift_shared/safeshift_shared.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _Client extends Mock implements SupabaseClient {}

class _Functions extends Mock implements FunctionsClient {}

void main() {
  test('quotes use the server route and preserve the parcel details', () async {
    final client = _Client();
    final functions = _Functions();
    when(() => client.functions).thenReturn(functions);
    when(() => functions.invoke('quote-calculate', body: any(named: 'body')))
        .thenAnswer(
          (_) async => const FunctionResponse(
            status: 201,
            data: <String, dynamic>{
              'data': <String, dynamic>{
                'quote_id': 'quote-1',
                'breakdown': <String, dynamic>{
                  'final': <String, dynamic>{
                    'total': 18000,
                    'subtotal': 16000,
                    'vat': 2000,
                    'currency_code': 'TZS',
                  },
                  'calculation': <String, dynamic>{
                    'distance_km': 12.5,
                    'duration_min': 34,
                    'base_fare': 7000,
                    'distance_charge': 8000,
                    'time_charge': 1000,
                  },
                },
              },
              'error': null,
            },
          ),
        );

    final quote = await RideRepository(client).requestQuote(
      pickup: const RidePlace(
        id: 'a',
        name: 'Kariakoo',
        district: 'Dar es Salaam',
        latitude: -6.818,
        longitude: 39.270,
      ),
      destination: const RidePlace(
        id: 'b',
        name: 'Mbezi',
        district: 'Dar es Salaam',
        latitude: -6.75,
        longitude: 39.28,
      ),
      vehicle: const VehicleTypeOption(
        id: 'vehicle-1',
        code: 'pickup',
        name: 'Pickup',
      ),
      cargoDescription: 'Two sealed boxes',
      valueTzs: 250000,
    );

    final body =
        verify(
              () => functions.invoke(
                'quote-calculate',
                body: captureAny(named: 'body'),
              ),
            ).captured.single
            as Map<String, dynamic>;
    expect(body['distance_km'], isNull);
    expect(body['duration_min'], isNull);
    expect(body['cargo_description'], 'Two sealed boxes');
    expect(body['declared_value_tzs'], 250000);
    expect(body['pickup'], <String, dynamic>{
      'lat': -6.818,
      'lng': 39.270,
      'address': 'Kariakoo',
    });
    expect(quote.quoteId, 'quote-1');
    expect(quote.total, 18000);
    expect(quote.distanceKm, 12.5);
    expect(quote.durationMin, 34);
  });
}
