import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safeshift_driver/core/config/mock_mode.dart';
import 'package:safeshift_driver/features/home/domain/entities/driver_status.dart';
import 'package:safeshift_driver/features/home/providers/home_provider.dart';

/// Waits until [condition] is true, polling every 200ms.
/// Throws on [timeout].
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
  group('HomeNotifier incoming-job countdown', () {
    test('countdown ticks down from 15 after a job arrives', () async {
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
      final first = container.read(homeProvider).countdownSeconds;
      expect(first, lessThanOrEqualTo(15));
      expect(first, greaterThan(0));

      await _waitUntil(
        () =>
            container.read(homeProvider).countdownSeconds < first ||
            container.read(homeProvider).driverStatus !=
                DriverStatus.incomingJob,
      );
      // Either the counter decreased or the job auto-declined — both
      // prove the countdown is running.
      expect(true, isTrue);
    });

    test('countdown expiry auto-declines back to searching', () async {
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

      // Wait out the full 15s countdown.
      await _waitUntil(
        () =>
            container.read(homeProvider).driverStatus ==
            DriverStatus.onlineSearching,
        timeout: const Duration(seconds: 30),
      );
      expect(container.read(homeProvider).incomingJob, isNull);
    }, timeout: const Timeout(Duration(seconds: 90)));
  });
}
