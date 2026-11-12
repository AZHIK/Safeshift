import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:safeshift_driver/features/home/data/driver_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _MockSupabaseClient extends Mock implements SupabaseClient {}

class _MockRpcBuilder extends Mock implements PostgrestFilterBuilder<void> {}

void main() {
  group('DriverRepository.selectCurrentVehicle', () {
    test('keeps the vehicle the driver already operates', () {
      expect(
        DriverRepository.selectCurrentVehicle(
          currentVehicleId: 'vehicle-9',
          readyVehicleIds: const <String>['vehicle-1', 'vehicle-2'],
        ),
        'vehicle-9',
      );
    });

    test('picks a ready vehicle when none is assigned yet', () {
      expect(
        DriverRepository.selectCurrentVehicle(
          currentVehicleId: null,
          readyVehicleIds: const <String>['vehicle-1', 'vehicle-2'],
        ),
        'vehicle-1',
      );
    });

    test('returns null when the driver has no verified vehicle', () {
      expect(
        DriverRepository.selectCurrentVehicle(
          currentVehicleId: null,
          readyVehicleIds: const <String>[],
        ),
        isNull,
      );
    });
  });

  group('DriverRepository.setCurrentVehicle', () {
    test('calls the server RPC with the vehicle id', () async {
      final client = _MockSupabaseClient();
      final builder = _MockRpcBuilder();
      when(
        () => client.rpc<void>(
          'driver_set_current_vehicle',
          params: any(named: 'params'),
        ),
      ).thenAnswer((_) => builder);
      // The postgrest builder is Future-like: awaiting it calls `then`, so the
      // stub has to invoke the callback for the await to complete.
      when(
        () => builder.then<dynamic>(any(), onError: any(named: 'onError')),
      ).thenAnswer((invocation) {
        final onValue = invocation.positionalArguments.first as Function;
        onValue(null);
        return Future<dynamic>.value(null);
      });

      await DriverRepository(client).setCurrentVehicle('vehicle-7');

      final captured = verify(
        () => client.rpc<void>(
          'driver_set_current_vehicle',
          params: captureAny(named: 'params'),
        ),
      ).captured.single as Map<String, dynamic>;
      expect(captured['p_vehicle_id'], 'vehicle-7');
    });
  });
}
