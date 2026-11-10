import 'package:flutter/foundation.dart';

import '../utils/geo.dart';

/// Where a [UserLocation] came from.
enum UserLocationSource {
  /// A fresh device GPS fix.
  gps,

  /// The platform's last known fix, used when a fresh fix times out.
  lastKnown,
}

/// A device location with the metadata needed to judge whether it is safe to
/// use for a courier pickup/delivery point.
@immutable
class UserLocation {
  const UserLocation({
    required this.latitude,
    required this.longitude,
    required this.accuracyMeters,
    required this.timestamp,
    required this.source,
    this.isMocked = false,
  });

  final double latitude;
  final double longitude;
  final double accuracyMeters;
  final DateTime timestamp;
  final UserLocationSource source;
  final bool isMocked;

  GeoPoint get point => GeoPoint(latitude, longitude);

  bool get hasAccuracy => accuracyMeters > 0;

  /// Above 100 m a GPS fix is too imprecise to be treated as a courier point
  /// without asking the customer to confirm or refine it.
  bool get isPoorAccuracy => hasAccuracy && accuracyMeters > 100;

  bool get isFairAccuracy =>
      hasAccuracy && accuracyMeters > 50 && accuracyMeters <= 100;

  bool get isStale =>
      DateTime.now().difference(timestamp) > const Duration(minutes: 5);

  bool get isLastKnown => source == UserLocationSource.lastKnown;

  String get accuracyLabel =>
      hasAccuracy ? '±${accuracyMeters.round()} m' : 'Accuracy unavailable';

  String get ageLabel {
    final age = DateTime.now().difference(timestamp);
    if (age.inSeconds < 45) return 'just now';
    if (age.inMinutes < 1) return '${age.inSeconds}s ago';
    if (age.inMinutes < 60) return '${age.inMinutes} min ago';
    if (age.inHours < 24) return '${age.inHours} h ago';
    return '${age.inDays} d ago';
  }

  @override
  String toString() =>
      'UserLocation($latitude, $longitude, accuracy=$accuracyMeters, $source)';
}

/// Lifecycle of the current-location lookup.
enum LocationStatus {
  idle,
  loading,
  ready,
  permissionDenied,
  permissionDeniedForever,
  serviceDisabled,
  restricted,
  timeout,
  unavailable,
}

/// State exposed by the current-location provider.
@immutable
class LocationState {
  const LocationState({
    this.status = LocationStatus.idle,
    this.location,
    this.message,
    this.isRefreshing = false,
  });

  final LocationStatus status;
  final UserLocation? location;

  /// User-safe explanation. Never contains provider keys or raw payloads.
  final String? message;
  final bool isRefreshing;

  bool get hasLocation => location != null;

  bool get isLoading => status == LocationStatus.loading;

  bool get isDenied =>
      status == LocationStatus.permissionDenied ||
      status == LocationStatus.permissionDeniedForever;

  bool get needsSettings =>
      status == LocationStatus.permissionDeniedForever ||
      status == LocationStatus.serviceDisabled;

  bool get canRequestPermission => status == LocationStatus.permissionDenied;

  LocationState copyWith({
    LocationStatus? status,
    UserLocation? location,
    String? message,
    bool? isRefreshing,
    bool clearLocation = false,
    bool clearMessage = false,
  }) {
    return LocationState(
      status: status ?? this.status,
      location: clearLocation ? null : (location ?? this.location),
      message: clearMessage ? null : (message ?? this.message),
      isRefreshing: isRefreshing ?? this.isRefreshing,
    );
  }

  @override
  String toString() =>
      'LocationState($status, hasLocation=$hasLocation, message=$message)';
}
