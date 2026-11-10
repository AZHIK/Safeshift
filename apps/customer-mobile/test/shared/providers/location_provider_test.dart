import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:safeshift_customer/shared/models/user_location.dart';
import 'package:safeshift_customer/shared/providers/location_provider.dart';
import 'package:safeshift_customer/shared/services/location_service.dart';

class _FakeLocationService extends LocationService {
  _FakeLocationService({
    this.serviceEnabled = true,
    this.permission = LocationPermission.whileInUse,
    this.position,
    this.failure,
    this.lastKnown,
  });

  bool serviceEnabled;
  LocationPermission permission;
  Position? position;
  LocationFailure? failure;
  Position? lastKnown;

  int currentPositionCalls = 0;
  int requestPermissionCalls = 0;

  @override
  Future<bool> isServiceEnabled() async => serviceEnabled;

  @override
  Future<LocationPermission> checkPermission() async => permission;

  @override
  Future<LocationPermission> requestPermission() async {
    requestPermissionCalls++;
    return permission;
  }

  @override
  Future<Position?> getLastKnownPosition() async => lastKnown;

  @override
  Future<Position> getCurrentPosition({
    Duration timeout = const Duration(seconds: 12),
  }) async {
    currentPositionCalls++;
    final error = failure;
    if (error != null) throw error;
    return position!;
  }
}

Position _position({double accuracy = 15}) {
  return Position(
    latitude: -6.8,
    longitude: 39.2,
    timestamp: DateTime.now(),
    accuracy: accuracy,
    altitude: 0,
    altitudeAccuracy: 0,
    heading: 0,
    headingAccuracy: 0,
    speed: 0,
    speedAccuracy: 0,
  );
}

ProviderContainer _container(_FakeLocationService service) {
  final container = ProviderContainer(
    overrides: [locationServiceProvider.overrideWithValue(service)],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('returns a fresh GPS fix and reuses the cached fix', () async {
    final service = _FakeLocationService(position: _position());
    final container = _container(service);
    final notifier = container.read(currentLocationProvider.notifier);

    final first = await notifier.ensureLocation();

    expect(first, isNotNull);
    expect(first!.accuracyMeters, 15);
    expect(first.source, UserLocationSource.gps);
    expect(
      container.read(currentLocationProvider).status,
      LocationStatus.ready,
    );

    final second = await notifier.ensureLocation();

    expect(second, same(first));
    expect(service.currentPositionCalls, 1);
  });

  test('falls back to the last known fix when a fresh fix times out', () async {
    final service = _FakeLocationService(
      failure: const LocationFailure(LocationFailureType.timeout, 'Timed out'),
      lastKnown: _position(accuracy: 120),
    );
    final container = _container(service);
    final notifier = container.read(currentLocationProvider.notifier);

    final result = await notifier.ensureLocation();

    expect(result, isNotNull);
    expect(result!.source, UserLocationSource.lastKnown);
    expect(result.isPoorAccuracy, isTrue);
    expect(
      container.read(currentLocationProvider).status,
      LocationStatus.ready,
    );
  });

  test('reports disabled location services', () async {
    final service = _FakeLocationService(serviceEnabled: false);
    final container = _container(service);

    final result = await container
        .read(currentLocationProvider.notifier)
        .ensureLocation();

    expect(result, isNull);
    expect(
      container.read(currentLocationProvider).status,
      LocationStatus.serviceDisabled,
    );
    expect(service.currentPositionCalls, 0);
  });

  test('reports permanently denied permission without retrying GPS', () async {
    final service = _FakeLocationService(
      permission: LocationPermission.deniedForever,
    );
    final container = _container(service);

    final result = await container
        .read(currentLocationProvider.notifier)
        .ensureLocation();

    expect(result, isNull);
    expect(
      container.read(currentLocationProvider).status,
      LocationStatus.permissionDeniedForever,
    );
    expect(service.currentPositionCalls, 0);
  });

  test('asks for permission at most once after a denial', () async {
    final service = _FakeLocationService(permission: LocationPermission.denied);
    final container = _container(service);
    final notifier = container.read(currentLocationProvider.notifier);

    await notifier.ensureLocation();
    await notifier.ensureLocation();

    expect(service.requestPermissionCalls, 1);
    expect(
      container.read(currentLocationProvider).status,
      LocationStatus.permissionDenied,
    );
  });

  group('UserLocation quality', () {
    UserLocation location({double accuracy = 20, DateTime? timestamp}) {
      return UserLocation(
        latitude: -6.8,
        longitude: 39.2,
        accuracyMeters: accuracy,
        timestamp: timestamp ?? DateTime.now(),
        source: UserLocationSource.gps,
      );
    }

    test('classifies good, fair, and poor accuracy', () {
      expect(location(accuracy: 20).isPoorAccuracy, isFalse);
      expect(location(accuracy: 20).isFairAccuracy, isFalse);
      expect(location(accuracy: 75).isFairAccuracy, isTrue);
      expect(location(accuracy: 120).isPoorAccuracy, isTrue);
    });

    test('marks older fixes as stale', () {
      final stale = location(
        timestamp: DateTime.now().subtract(const Duration(minutes: 6)),
      );
      expect(stale.isStale, isTrue);
    });
  });
}
