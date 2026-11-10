import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../models/user_location.dart';
import '../services/location_service.dart';

final locationServiceProvider = Provider<LocationService>((ref) {
  ref.keepAlive();
  return const LocationService();
});

/// Current device location with permission/GPS recovery states.
///
/// A successful fix is cached for two minutes so opening the pickup sheet and
/// then the delivery sheet does not trigger two GPS requests. Call
/// [CurrentLocationNotifier.refresh] when the customer explicitly asks for a
/// fresh position.
final currentLocationProvider =
    NotifierProvider<CurrentLocationNotifier, LocationState>(
      CurrentLocationNotifier.new,
    );

class CurrentLocationNotifier extends Notifier<LocationState> {
  static const Duration _cacheTtl = Duration(minutes: 2);

  bool _permissionRequested = false;

  @override
  LocationState build() => const LocationState();

  Future<UserLocation?> ensureLocation({
    bool forceRefresh = false,
    bool requestPermission = true,
  }) async {
    final cached = state.location;
    if (!forceRefresh &&
        cached != null &&
        !cached.isStale &&
        DateTime.now().difference(cached.timestamp) < _cacheTtl) {
      return cached;
    }
    return _load(
      forceRefresh: forceRefresh,
      requestPermission: requestPermission,
    );
  }

  Future<UserLocation?> refresh() =>
      _load(forceRefresh: true, requestPermission: true);

  Future<UserLocation?> _load({
    required bool forceRefresh,
    required bool requestPermission,
  }) async {
    if (state.isLoading && !forceRefresh) return state.location;

    state = LocationState(
      status: LocationStatus.loading,
      location: state.location,
      isRefreshing: state.hasLocation,
    );

    final service = ref.read(locationServiceProvider);
    try {
      final enabled = await service.isServiceEnabled();
      if (!enabled) {
        state = const LocationState(
          status: LocationStatus.serviceDisabled,
          message:
              'Location services are off. Turn them on in device settings, '
              'or search for a place manually.',
        );
        return null;
      }

      var permission = await service.checkPermission();
      if (permission == LocationPermission.denied &&
          requestPermission &&
          !_permissionRequested) {
        _permissionRequested = true;
        permission = await service.requestPermission();
      }

      switch (permission) {
        case LocationPermission.denied:
          state = const LocationState(
            status: LocationStatus.permissionDenied,
            message:
                'Location permission is needed to show nearby places. '
                'You can still search manually.',
          );
          return null;
        case LocationPermission.deniedForever:
          state = const LocationState(
            status: LocationStatus.permissionDeniedForever,
            message:
                'Location permission is off. Open app settings to enable it, '
                'or search for a place manually.',
          );
          return null;
        case LocationPermission.unableToDetermine:
          state = const LocationState(
            status: LocationStatus.restricted,
            message:
                'Location access is restricted on this device. '
                'You can still search manually.',
          );
          return null;
        case LocationPermission.whileInUse:
        case LocationPermission.always:
          break;
      }

      UserLocation? location;
      try {
        final position = await service.getCurrentPosition();
        location = service.toUserLocation(position);
      } on LocationFailure catch (failure) {
        // A timed-out GPS fix is not a dead end: fall back to the platform's
        // last known position and let the UI mark it as stale.
        if (failure.type == LocationFailureType.timeout ||
            failure.type == LocationFailureType.unavailable) {
          final lastKnown = await service.getLastKnownPosition();
          if (lastKnown != null) {
            location = service.toUserLocation(
              lastKnown,
              source: UserLocationSource.lastKnown,
            );
          }
        }
        if (location == null) {
          state = LocationState(
            status: _statusFor(failure.type),
            message: failure.message,
          );
          return null;
        }
      }

      state = LocationState(status: LocationStatus.ready, location: location);
      return location;
    } catch (_) {
      state = const LocationState(
        status: LocationStatus.unavailable,
        message:
            'Your location is unavailable right now. Try again or search '
            'for a place manually.',
      );
      return null;
    }
  }

  Future<bool> openAppSettings() =>
      ref.read(locationServiceProvider).openAppSettings();

  Future<bool> openLocationSettings() =>
      ref.read(locationServiceProvider).openLocationSettings();

  /// Clears the cached fix, for example after the app returns from settings.
  void reset() {
    _permissionRequested = false;
    state = const LocationState();
  }

  LocationStatus _statusFor(LocationFailureType type) {
    switch (type) {
      case LocationFailureType.permissionDenied:
        return LocationStatus.permissionDenied;
      case LocationFailureType.permissionDeniedForever:
        return LocationStatus.permissionDeniedForever;
      case LocationFailureType.restricted:
        return LocationStatus.restricted;
      case LocationFailureType.serviceDisabled:
        return LocationStatus.serviceDisabled;
      case LocationFailureType.timeout:
        return LocationStatus.timeout;
      case LocationFailureType.unavailable:
        return LocationStatus.unavailable;
    }
  }
}
