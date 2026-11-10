import 'dart:async';

import 'package:geolocator/geolocator.dart';

import '../models/user_location.dart';

/// Typed location failures so the UI can offer the right recovery action.
enum LocationFailureType {
  permissionDenied,
  permissionDeniedForever,
  restricted,
  serviceDisabled,
  timeout,
  unavailable,
}

class LocationFailure implements Exception {
  const LocationFailure(this.type, this.message);

  final LocationFailureType type;

  /// User-safe message. Never contains raw platform or provider details.
  final String message;

  @override
  String toString() => 'LocationFailure($type)';
}

/// Thin wrapper around `geolocator`.
///
/// Keeping platform calls here makes the permission/GPS logic reusable and
/// testable, and prevents screens from calling the plugin directly.
class LocationService {
  const LocationService();

  Future<bool> isServiceEnabled() => Geolocator.isLocationServiceEnabled();

  Future<LocationPermission> checkPermission() => Geolocator.checkPermission();

  Future<LocationPermission> requestPermission() =>
      Geolocator.requestPermission();

  /// Returns the platform's last known fix, if one is available.
  ///
  /// This is used only as a fallback when a fresh GPS fix times out. It is
  /// never silently selected as the customer's pickup/delivery point.
  Future<Position?> getLastKnownPosition() async {
    try {
      return await Geolocator.getLastKnownPosition();
    } catch (_) {
      return null;
    }
  }

  Future<Position> getCurrentPosition({
    Duration timeout = const Duration(seconds: 12),
  }) async {
    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: timeout,
        ),
      );
    } on TimeoutException {
      throw const LocationFailure(
        LocationFailureType.timeout,
        'Getting your location timed out. You can try again or search manually.',
      );
    } on LocationServiceDisabledException {
      throw const LocationFailure(
        LocationFailureType.serviceDisabled,
        'Location services are turned off. Turn them on to use your current location.',
      );
    } on PermissionDeniedException {
      throw const LocationFailure(
        LocationFailureType.permissionDenied,
        'Location permission was denied. You can still search for a place.',
      );
    } catch (_) {
      throw const LocationFailure(
        LocationFailureType.unavailable,
        'Your location is unavailable right now. Try again or search manually.',
      );
    }
  }

  UserLocation toUserLocation(
    Position position, {
    UserLocationSource source = UserLocationSource.gps,
  }) {
    return UserLocation(
      latitude: position.latitude,
      longitude: position.longitude,
      accuracyMeters: position.accuracy,
      timestamp: position.timestamp,
      source: source,
      isMocked: position.isMocked,
    );
  }

  Future<bool> openAppSettings() => Geolocator.openAppSettings();

  Future<bool> openLocationSettings() => Geolocator.openLocationSettings();
}
