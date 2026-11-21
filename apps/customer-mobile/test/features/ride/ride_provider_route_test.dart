import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:mocktail/mocktail.dart';
import 'package:safeshift_customer/core/network/supabase_client.dart';
import 'package:safeshift_shared/safeshift_shared.dart';
import 'package:safeshift_customer/features/auth/domain/entities/auth_state.dart';
import 'package:safeshift_customer/features/auth/providers/auth_provider.dart';
import 'package:safeshift_customer/features/ride/data/ride_repository.dart';
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
    when(() => functions.invoke('maps-route', body: any(named: 'body')))
        .thenAnswer(
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

  test('tracking routes follow the driver on each leg and end at handover', () {
    final ride = RideState(
      pickup: _pickup,
      destination: _destination,
      jobStatus: 'heading_to_pickup',
      driverLatitude: -6.81,
      driverLongitude: 39.26,
    );
    expect(ride.trackingLeg, (
      origin: const LatLng(-6.81, 39.26),
      target: LatLng(_pickup.latitude, _pickup.longitude),
    ));
    final inTransit = ride.copyWith(
      jobStatus: 'in_transit',
      driverLatitude: -6.80,
    );
    expect(inTransit.trackingLeg, (
      origin: const LatLng(-6.80, 39.26),
      target: LatLng(_destination.latitude, _destination.longitude),
    ));
    expect(ride.copyWith(clearDriverLocation: true).trackingLeg, isNull);
    expect(
      inTransit.copyWith(jobStatus: 'arrived_destination').trackingLeg,
      isNull,
    );
    expect(
      inTransit
          .copyWith(jobStatus: 'delivered', clearDriverLocation: true)
          .driverLatitude,
      isNull,
    );
  });

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

  test(
    'the route request carries the pickup and destination coordinates',
    () async {
      final functions = _MockFunctionsClient();
      final container = buildContainer(functions);
      final notifier = container.read(rideProvider.notifier);

      notifier.setPickup(_pickup);
      notifier.setDestination(_destination);
      await Future<void>.delayed(const Duration(milliseconds: 800));

      final captured =
          verify(
                () => functions.invoke(
                  'maps-route',
                  body: captureAny(named: 'body'),
                ),
              ).captured.single
              as Map<String, dynamic>;

      expect(captured['mode'], 'driving');
      expect((captured['origin'] as Map)['lat'], -6.818);
      expect((captured['origin'] as Map)['lng'], 39.270);
      expect((captured['destination'] as Map)['lat'], -6.76075);
      expect((captured['destination'] as Map)['lng'], 39.27623);
    },
  );

  group('vehicle availability', () {
    const bike = VehicleTypeOption(id: 'bike', code: 'bike', name: 'Bike');
    const van = VehicleTypeOption(id: 'van', code: 'van', name: 'Van');
    const truck = VehicleTypeOption(id: 'truck', code: 'truck', name: 'Truck');
    const catalogue = [bike, van, truck];

    Future<RideNotifier> routed(ProviderContainer container) async {
      final notifier = container.read(rideProvider.notifier);
      notifier.setPickup(_pickup);
      notifier.setDestination(_destination);
      notifier.ensureVehicleSelected(catalogue); // auto-picks the van
      return notifier;
    }

    test('moves an auto-picked vehicle to the best available one', () async {
      final container = buildContainer(_MockFunctionsClient());
      final notifier = await routed(container);
      expect(container.read(rideProvider).vehicleClass?.id, 'van');

      notifier.applyVehicleAvailability(const {
        'truck': VehicleAvailability(VehicleAvailabilityStatus.available),
        'bike': VehicleAvailability(VehicleAvailabilityStatus.limited),
      }, catalogue);

      expect(container.read(rideProvider).vehicleClass?.id, 'truck');
      expect(notifier.availabilityFor('van')?.isNone, isTrue);
    });

    test('keeps a vehicle the customer picked themselves', () async {
      final container = buildContainer(_MockFunctionsClient());
      final notifier = await routed(container);
      notifier.selectVehicle(bike);

      notifier.applyVehicleAvailability(const {
        'truck': VehicleAvailability(VehicleAvailabilityStatus.available),
      }, catalogue);

      expect(container.read(rideProvider).vehicleClass?.id, 'bike');
    });

    test('unknown availability changes nothing', () async {
      final container = buildContainer(_MockFunctionsClient());
      final notifier = await routed(container);

      notifier.applyVehicleAvailability(null, catalogue);

      expect(container.read(rideProvider).vehicleClass?.id, 'van');
      expect(notifier.availabilityFor('van'), isNull);
    });

    test('prefers the smallest vehicle among equally available ones', () async {
      final container = buildContainer(_MockFunctionsClient());
      final notifier = await routed(container);

      notifier.applyVehicleAvailability(const {
        'bike': VehicleAvailability(VehicleAvailabilityStatus.available),
        'truck': VehicleAvailability(VehicleAvailabilityStatus.available),
      }, catalogue);

      expect(container.read(rideProvider).vehicleClass?.id, 'bike');
    });
  });

  test('cancelling a request clears the whole request form', () async {
    final functions = _MockFunctionsClient();
    final container = buildContainer(functions);
    final notifier = container.read(rideProvider.notifier);

    notifier.setPickup(_pickup);
    notifier.setDestination(_destination);
    notifier.ensureVehicleSelected(const [
      VehicleTypeOption(
        id: 'van',
        code: 'van',
        name: 'Van',
        capacityKgMax: 1000,
      ),
    ]);
    expect(container.read(rideProvider).hasRoute, isTrue);

    await notifier.cancelSearch();

    final state = container.read(rideProvider);
    expect(state.stage, RideStage.idle);
    expect(state.pickup, isNull);
    expect(state.destination, isNull);
    expect(state.vehicleClass, isNull);
    expect(state.routePoints, isEmpty);
    expect(state.quoteId, isNull);
    expect(state.jobId, isNull);
  });

  test('a failed route surfaces an error and clears the polyline', () async {
    final functions = _MockFunctionsClient();
    final container = buildContainer(functions);

    when(() => functions.invoke('maps-route', body: any(named: 'body')))
        .thenThrow(
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
