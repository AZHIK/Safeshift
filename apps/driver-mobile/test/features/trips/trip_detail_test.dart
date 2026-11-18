import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:safeshift_driver/core/cache/cache_service.dart';
import 'package:safeshift_driver/features/auth/domain/entities/auth_state.dart';
import 'package:safeshift_driver/features/auth/domain/entities/user.dart';
import 'package:safeshift_driver/features/auth/providers/auth_provider.dart';
import 'package:safeshift_driver/features/home/data/driver_repository.dart';
import 'package:safeshift_driver/features/home/domain/entities/driver_job.dart';
import 'package:safeshift_driver/features/trips/providers/trips_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supa;

class _MockSupabaseClient extends Mock implements supa.SupabaseClient {}

class _MockRpcBuilder extends Mock
    implements supa.PostgrestFilterBuilder<List<dynamic>> {}

class _MockDriverRepository extends Mock implements DriverRepository {}

class _MockCacheService extends Mock implements CacheService {}

class _FakeAuthNotifier extends AuthNotifier {
  _FakeAuthNotifier(this.initialState);

  final AuthState initialState;

  @override
  AuthState build() => initialState;
}

const _user = User(
  id: 'driver-1',
  phone: '+255700000000',
  fullName: 'Driver One',
  role: 'driver',
);

const _cachedTripJson = <String, dynamic>{
  'id': 'job-old',
  'pickup': 'Kariakoo',
  'destination': 'Mikocheni',
  'distance_km': 8.4,
  'fare': 21000,
  'cargo': 'General cargo',
  'customer': 'Amina',
  'status': 'completed',
  'completed_at': '2026-01-02T09:30:00Z',
};

const _rpcTripRow = <String, dynamic>{
  'job_id': 'job-old',
  'status': 'completed',
  'pickup_address': 'Kariakoo',
  'destination_address': 'Mikocheni',
  'final_amount': 21000,
  'distance_km': 8.4,
  'customer_name': 'Amina',
  'cargo_type': 'General cargo',
};

void main() {
  setUpAll(() {
    registerFallbackValue(<String, dynamic>{});
  });

  group('DriverRepository.trip', () {
    test('passes the requested job id to the lookup RPC', () async {
      final client = _MockSupabaseClient();
      final builder = _MockRpcBuilder();
      when(
        () => client.rpc<List<dynamic>>(
          'driver_trip_detail',
          params: any(named: 'params'),
        ),
      ).thenAnswer((_) => builder);
      when(() => builder.then<dynamic>(any(), onError: any(named: 'onError')))
          .thenAnswer((invocation) {
            final onValue = invocation.positionalArguments.first as Function;
            final rows = <dynamic>[_rpcTripRow];
            onValue(rows);
            return Future<dynamic>.value(rows);
          });

      final trip = await DriverRepository(client).trip('job-old');

      expect(trip?.id, 'job-old');
      expect(trip?.estimatedFareTzs, 21000);
      final params =
          verify(
                () => client.rpc<List<dynamic>>(
                  'driver_trip_detail',
                  params: captureAny(named: 'params'),
                ),
              ).captured.single
              as Map<String, dynamic>;
      expect(params['p_job_id'], 'job-old');
    });

    test('returns null when the server has no matching trip', () async {
      final client = _MockSupabaseClient();
      final builder = _MockRpcBuilder();
      when(
        () => client.rpc<List<dynamic>>(
          'driver_trip_detail',
          params: any(named: 'params'),
        ),
      ).thenAnswer((_) => builder);
      when(() => builder.then<dynamic>(any(), onError: any(named: 'onError')))
          .thenAnswer((invocation) {
            final onValue = invocation.positionalArguments.first as Function;
            onValue(<dynamic>[]);
            return Future<dynamic>.value(<dynamic>[]);
          });

      expect(await DriverRepository(client).trip('missing'), isNull);
    });
  });

  group('driverTripDetailProvider', () {
    ProviderContainer containerWith({
      required _MockDriverRepository repository,
      required _MockCacheService cache,
    }) {
      final container = ProviderContainer(
        overrides: [
          authProvider.overrideWith(
            () => _FakeAuthNotifier(
              const AuthState(
                status: AuthStatus.authenticated,
                currentUser: _user,
              ),
            ),
          ),
          driverRepositoryProvider.overrideWithValue(repository),
          cacheServiceProvider.overrideWithValue(cache),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    test('returns the server trip and caches it for offline detail', () async {
      final repository = _MockDriverRepository();
      final cache = _MockCacheService();
      const trip = DriverJob(
        id: 'job-old',
        pickup: 'Kariakoo',
        destination: 'Mikocheni',
        distanceKm: 8.4,
        estimatedFareTzs: 21000,
        cargoClass: 'General cargo',
        customerName: 'Amina',
        pickupDistanceKm: 0,
        status: 'completed',
      );
      when(() => repository.trip('job-old')).thenAnswer((_) async => trip);
      when(() => cache.putJson(any(), any(), any(), id: any(named: 'id')))
          .thenAnswer((_) async {});

      final result = await containerWith(
        repository: repository,
        cache: cache,
      ).read(driverTripDetailProvider('job-old').future);

      expect(result?.id, 'job-old');
      verify(
        () => cache.putJson('driver-1', 'driver_trip', any(), id: 'job-old'),
      ).called(1);
    });

    test('falls back to the cached trip when the lookup fails', () async {
      final repository = _MockDriverRepository();
      final cache = _MockCacheService();
      when(() => repository.trip('job-old')).thenThrow(Exception('offline'));
      when(() => cache.getJson('driver-1', 'driver_trip', id: 'job-old'))
          .thenReturn(_cachedTripJson);

      final result = await containerWith(
        repository: repository,
        cache: cache,
      ).read(driverTripDetailProvider('job-old').future);

      expect(result?.id, 'job-old');
      expect(result?.destination, 'Mikocheni');
    });

    test('returns null for a trip the server does not recognise', () async {
      final repository = _MockDriverRepository();
      final cache = _MockCacheService();
      when(() => repository.trip('foreign')).thenAnswer((_) async => null);

      final result = await containerWith(
        repository: repository,
        cache: cache,
      ).read(driverTripDetailProvider('foreign').future);

      expect(result, isNull);
      verifyNever(
        () => cache.putJson(any(), any(), any(), id: any(named: 'id')),
      );
    });
  });
}
