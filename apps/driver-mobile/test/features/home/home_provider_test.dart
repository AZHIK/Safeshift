import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:safeshift_driver/core/config/mock_mode.dart';
import 'package:safeshift_driver/features/home/data/driver_route_service.dart';
import 'package:safeshift_driver/features/home/domain/entities/driver_job.dart';
import 'package:safeshift_driver/features/home/domain/entities/driver_status.dart';
import 'package:safeshift_driver/features/home/providers/home_provider.dart';

Future<void> _waitUntil(
  bool Function() condition, {
  Duration timeout = const Duration(seconds: 30),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) {
      throw StateError('Timed out waiting for condition');
    }
    await Future<void>.delayed(const Duration(milliseconds: 200));
  }
}

void main() {
  test('both driving legs use the live GPS fix and exact booked endpoint', () {
    const job = DriverJob(
      id: 'trip',
      pickup: 'A',
      destination: 'B',
      distanceKm: 5,
      estimatedFareTzs: 5000,
      cargoClass: 'Box',
      customerName: 'Customer',
      pickupDistanceKm: 1,
      pickupLat: -6.81234,
      pickupLng: 39.20123,
      destinationLat: -6.82345,
      destinationLng: 39.21234,
    );
    const driver = LatLng(-6.80012, 39.28012);
    final pickup = DriverRouteLeg.forJob(
      DriverStatus.headingToPickup,
      job,
      driver,
    )!;
    final transit = DriverRouteLeg.forJob(DriverStatus.inTransit, job, driver)!;
    expect(pickup.origin, driver);
    expect(pickup.destination, LatLng(job.pickupLat!, job.pickupLng!));
    expect(transit.origin, driver);
    expect(
      transit.destination,
      LatLng(job.destinationLat!, job.destinationLng!),
    );
    expect(
      DriverRouteLeg.forJob(DriverStatus.headingToPickup, job, null),
      isNull,
    );
    expect(DriverRouteLeg.forJob(DriverStatus.delivered, job, driver), isNull);
    expect(
      DriverRouteLeg.forJob(
        DriverStatus.headingToPickup,
        job,
        const LatLng(-6.80013, 39.28013),
      ),
      pickup,
    );
  });

  group('HomeNotifier state transitions', () {
    test('full job flow stays on one screen through every stage', () async {
      final container = ProviderContainer(
        overrides: [mockEnabledProvider.overrideWithValue(true)],
      );
      addTearDown(container.dispose);
      final notifier = container.read(homeProvider.notifier);

      expect(container.read(homeProvider).driverStatus, DriverStatus.offline);
      expect(container.read(homeProvider).driverStatus.showBottomNav, isTrue);

      notifier.goOnline();
      expect(
        container.read(homeProvider).driverStatus,
        DriverStatus.onlineIdle,
      );

      await _waitUntil(
        () =>
            container.read(homeProvider).driverStatus ==
            DriverStatus.onlineSearching,
      );

      await _waitUntil(
        () =>
            container.read(homeProvider).driverStatus ==
            DriverStatus.incomingJob,
      );
      expect(container.read(homeProvider).incomingJob, isNotNull);

      notifier.acceptJob();
      expect(
        container.read(homeProvider).driverStatus,
        DriverStatus.headingToPickup,
      );
      expect(container.read(homeProvider).activeJob, isNotNull);
      expect(container.read(homeProvider).driverStatus.hasActiveJob, isTrue);
      expect(container.read(homeProvider).driverStatus.showBottomNav, isFalse);

      notifier.advanceStage();
      expect(
        container.read(homeProvider).driverStatus,
        DriverStatus.arrivedAtPickup,
      );
      notifier.advanceStage();
      expect(
        container.read(homeProvider).driverStatus,
        DriverStatus.cargoVerified,
      );
      notifier.advanceStage();
      expect(container.read(homeProvider).driverStatus, DriverStatus.loading);
      notifier.advanceStage();
      expect(container.read(homeProvider).driverStatus, DriverStatus.inTransit);
      notifier.advanceStage();
      expect(
        container.read(homeProvider).driverStatus,
        DriverStatus.arrivedAtDestination,
      );
      notifier.advanceStage();
      expect(container.read(homeProvider).driverStatus, DriverStatus.delivered);
      notifier.advanceStage();
      expect(
        container.read(homeProvider).driverStatus,
        DriverStatus.tripCompleted,
      );

      notifier.goBackOnline();
      expect(
        container.read(homeProvider).driverStatus,
        DriverStatus.onlineIdle,
      );
      expect(container.read(homeProvider).driverStatus.showBottomNav, isTrue);
    }, timeout: const Timeout(Duration(seconds: 90)));

    test('decline returns to searching', () async {
      final container = ProviderContainer(
        overrides: [mockEnabledProvider.overrideWithValue(true)],
      );
      addTearDown(container.dispose);
      final notifier = container.read(homeProvider.notifier);

      notifier.goOnline();
      await _waitUntil(
        () =>
            container.read(homeProvider).driverStatus ==
            DriverStatus.incomingJob,
      );

      notifier.declineJob();
      expect(
        container.read(homeProvider).driverStatus,
        DriverStatus.onlineSearching,
      );
      expect(container.read(homeProvider).incomingJob, isNull);
    }, timeout: const Timeout(Duration(seconds: 60)));

    test('goOffline cancels everything', () async {
      final container = ProviderContainer(
        overrides: [mockEnabledProvider.overrideWithValue(true)],
      );
      addTearDown(container.dispose);
      final notifier = container.read(homeProvider.notifier);

      notifier.goOnline();
      expect(
        container.read(homeProvider).driverStatus,
        DriverStatus.onlineIdle,
      );
      notifier.goOffline();
      expect(container.read(homeProvider).driverStatus, DriverStatus.offline);
      await Future<void>.delayed(const Duration(seconds: 3));
      expect(container.read(homeProvider).driverStatus, DriverStatus.offline);
    });
  });
}
