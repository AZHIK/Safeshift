import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:safeshift_customer/core/network/supabase_client.dart';
import 'package:safeshift_customer/features/auth/domain/entities/auth_state.dart';
import 'package:safeshift_customer/features/auth/providers/auth_provider.dart';
import 'package:safeshift_customer/features/ride/providers/ride_provider.dart';
import 'package:safeshift_customer/shared/models/ride_place.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;

class _MockSupabaseClient extends Mock implements SupabaseClient {}

class _MockFunctionsClient extends Mock implements FunctionsClient {}

class _FakeAuthNotifier extends AuthNotifier {
  _FakeAuthNotifier() : super(appRole: 'customer');

  @override
  AuthState build() => const AuthState(isInitialized: true);
}

const _pickup = RidePlace(
  id: 'pickup',
  name: 'Kariakoo Market',
  district: 'Dar es Salaam',
  latitude: -6.818,
  longitude: 39.270,
);

const _destination = RidePlace(
  id: 'destination',
  name: 'Sinaketi',
  district: 'Dar es Salaam',
  latitude: -6.76075,
  longitude: 39.27623,
);

/// A real Google encoded polyline for a Dar es Salaam driving route.
const _encodedPolyline =
    'jsmh@qzhnFQCyAYA?eAMc@Ea@EOCw@CkBGc@AG?[Cc@Cc@A_@CoAOmDw@OGSK]QA?UOi@]]Y]Y_AeAw@'
    '_AY_@GGUYKKe@i@e@k@w@}@GIe@k@w@_AMOy@aAEEaAiAWYCEUWEEQSY]UUs@q@ECSSg@a@QKWQaAo@'
    'WOOM{@k@y@i@IGq@c@WOkBoAw@i@_@W]UoA{@_Am@y@k@uBsAu@g@_@WOKZe@X_@Ze@PUFIDG@?DEJIDElAkB';

void main() {
  ProviderContainer buildContainer(FunctionsClient functions) {
    final client = _MockSupabaseClient();
    final container = ProviderContainer(
      overrides: [
        authProvider.overrideWith(_FakeAuthNotifier.new),
        supabaseProvider.overrideWithValue(client),
      ],
    );
    addTearDown(container.dispose);

    when(() => client.functions).thenReturn(functions);
    when(
      () => functions.invoke(
        'maps-route',
        body: any(named: 'body'),
      ),
    ).thenAnswer(
      (_) async => const FunctionResponse(
        status: 200,
        data: <String, dynamic>{
          'data': <String, dynamic>{
            'distance_km': 11.86,
            'duration_min': 30.77,
            'encoded_polyline': _encodedPolyline,
            'route_label': 'DEFAULT_ROUTE',
            'traffic_aware': true,
            'cached': false,
          },
          'error': null,
        },
      ),
    );
    return container;
  }

  test('selecting pickup and destination computes the road route', () async {
    final functions = _MockFunctionsClient();
    final container = buildContainer(functions);
    final notifier = container.read(rideProvider.notifier);

    notifier.setPickup(_pickup);
    notifier.setDestination(_destination);

    // The route call is debounced by 400ms.
    await Future<void>.delayed(const Duration(milliseconds: 800));

    final state = container.read(rideProvider);
    expect(state.routeError, isNull, reason: 'route call failed');
    expect(state.routePoints, isNotEmpty);
    expect(state.routePoints.length, greaterThan(50));
    expect(state.routePoints.first.latitude, closeTo(-6.79238, 1e-4));
    expect(state.distanceKm, 11.86);
    expect(state.durationMin, 30);
  });

  test('the route request carries the pickup and destination coordinates', () async {
    final functions = _MockFunctionsClient();
    final container = buildContainer(functions);
    final notifier = container.read(rideProvider.notifier);

    notifier.setPickup(_pickup);
    notifier.setDestination(_destination);
    await Future<void>.delayed(const Duration(milliseconds: 800));

    final captured = verify(
      () => functions.invoke(
        'maps-route',
        body: captureAny(named: 'body'),
      ),
    ).captured.single as Map<String, dynamic>;

    expect(captured['mode'], 'driving');
    expect((captured['origin'] as Map)['lat'], -6.818);
    expect((captured['origin'] as Map)['lng'], 39.270);
    expect((captured['destination'] as Map)['lat'], -6.76075);
    expect((captured['destination'] as Map)['lng'], 39.27623);
  });

  test('a failed route surfaces an error and clears the polyline', () async {
    final functions = _MockFunctionsClient();
    final container = buildContainer(functions);

    when(
      () => functions.invoke(
        'maps-route',
        body: any(named: 'body'),
      ),
    ).thenThrow(
      const FunctionException(
        status: 502,
        details: {'provider_error': 'google_maps rejected the request'},
      ),
    );

    final notifier = container.read(rideProvider.notifier);
    notifier.setPickup(_pickup);
    notifier.setDestination(_destination);
    await Future<void>.delayed(const Duration(milliseconds: 800));

    final state = container.read(rideProvider);
    expect(state.routeError, isNotNull);
    expect(state.routePoints, isEmpty);
  });
}
