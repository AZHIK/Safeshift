import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'package:safeshift_shared/safeshift_shared.dart'
    show GeoPoint, RerouteRule, polylineLengthMeters, remainingRoute;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/network/supabase_client.dart';
import '../../../../shared/utils/polyline.dart';
import '../domain/entities/driver_job.dart';
import '../domain/entities/driver_status.dart';
import '../domain/entities/home_state.dart';
import '../providers/home_provider.dart';

/// A road route from the `maps-route` edge function, already decoded to points.
class DriverRoute {
  const DriverRoute(this.points, {this.distanceKm = 0, this.durationMin = 0});

  final List<LatLng> points;
  final double distanceKm;
  final int durationMin;
}

/// Shares a route across nearby GPS fixes while sending the original
/// coordinates to Google. The booked endpoint always keeps its full precision.
class DriverRouteLeg {
  const DriverRouteLeg(this.origin, this.destination);

  final LatLng origin;
  final LatLng destination;

  static DriverRouteLeg? forJob(
    DriverStatus status,
    DriverJob? job,
    LatLng? driver,
  ) {
    if (job == null) return null;
    final pickup = job.pickupLat != null && job.pickupLng != null
        ? LatLng(job.pickupLat!, job.pickupLng!)
        : null;
    final dropoff = job.destinationLat != null && job.destinationLng != null
        ? LatLng(job.destinationLat!, job.destinationLng!)
        : null;
    final (origin, target) = switch (status) {
      DriverStatus.headingToPickup => (driver, pickup),
      DriverStatus.inTransit => (driver, dropoff),
      DriverStatus.incomingJob ||
      DriverStatus.arrivedAtPickup ||
      DriverStatus.cargoVerified ||
      DriverStatus.loading => (pickup, dropoff),
      _ => (null, null),
    };
    return origin == null || target == null
        ? null
        : DriverRouteLeg(origin, target);
  }

  (int, int) get _originCell =>
      ((origin.latitude * 1000).round(), (origin.longitude * 1000).round());

  @override
  bool operator ==(Object other) =>
      other is DriverRouteLeg &&
      _originCell == other._originCell &&
      destination == other.destination;

  @override
  int get hashCode => Object.hash(_originCell, destination);
}

/// Fetches the road route for [leg] from the `maps-route` edge function.
Future<DriverRoute> fetchDriverRoute(
  SupabaseClient client,
  DriverRouteLeg leg,
) async {
  final response = await client.functions.invoke(
    'maps-route',
    body: <String, dynamic>{
      'origin': {'lat': leg.origin.latitude, 'lng': leg.origin.longitude},
      'destination': {
        'lat': leg.destination.latitude,
        'lng': leg.destination.longitude,
      },
      'mode': 'driving',
    },
  );
  final payload = response.data;
  final data = payload is Map ? payload['data'] : null;
  if (data is! Map) throw const FormatException('Missing route data');
  final points = decodePolyline(data['encoded_polyline'] as String?);
  if (points.length < 2) {
    throw const FormatException('Missing road geometry');
  }
  return DriverRoute(
    points,
    distanceKm: (data['distance_km'] as num).toDouble(),
    durationMin: (data['duration_min'] as num).round(),
  );
}

LatLng _toLatLng(GeoPoint p) => LatLng(p.lat, p.lng);
GeoPoint _toGeo(LatLng p) => (lat: p.latitude, lng: p.longitude);

/// What the map and the trip sheets show for the leg in progress.
class LiveRouteView {
  const LiveRouteView({
    required this.points,
    required this.distanceKm,
    required this.durationMin,
    this.isLoading = false,
    this.hasError = false,
  });

  /// Remaining road geometry (already trimmed to the driver's position).
  final List<LatLng> points;
  final double distanceKm;
  final int durationMin;
  final bool isLoading;
  final bool hasError;
}

/// Keeps one route per leg and trims it locally as the driver advances.
///
/// The route is fetched again only when the destination of the leg changes,
/// the driver strays more than 80 m from it, or it is older than 5 minutes
/// (so the ETA reflects traffic). That replaces a Maps request every ~110 m.
class LiveRouteNotifier extends Notifier<LiveRouteView?> {
  static const _rule = RerouteRule();
  static const _minRetryGap = Duration(seconds: 20);

  DriverRoute? _route;
  DateTime? _fetchedAt;
  DateTime? _lastAttempt;
  LatLng? _target;
  bool _originIsDriver = false;
  bool _fetching = false;
  bool _failed = false;

  @override
  LiveRouteView? build() {
    ref.listen<HomeState>(homeProvider, (_, next) => _update(next));
    return _view(ref.read(homeProvider));
  }

  void _update(HomeState home) {
    final view = _view(home);
    if (ref.mounted) state = view;
  }

  LiveRouteView? _view(HomeState home) {
    final job = home.activeJob ?? home.incomingJob;
    final driver = home.driverLat != null && home.driverLng != null
        ? LatLng(home.driverLat!, home.driverLng!)
        : null;
    final leg = DriverRouteLeg.forJob(home.driverStatus, job, driver);
    if (leg == null) {
      _route = null;
      _target = null;
      return null;
    }
    final originIsDriver =
        home.driverStatus == DriverStatus.headingToPickup ||
        home.driverStatus == DriverStatus.inTransit;

    final legChanged =
        _target != leg.destination || _originIsDriver != originIsDriver;
    if (legChanged) {
      _route = null;
      _fetchedAt = null;
      _failed = false;
      _target = leg.destination;
      _originIsDriver = originIsDriver;
    }

    final route = _route;
    final needsFetch =
        route == null ||
        (originIsDriver &&
            driver != null &&
            _rule.needsReroute(
              route: route.points.map(_toGeo).toList(),
              position: _toGeo(driver),
              fetchedAt: _fetchedAt!,
            ));
    if (needsFetch) _fetch(leg, force: legChanged);

    if (route == null) {
      return LiveRouteView(
        points: const <LatLng>[],
        distanceKm: 0,
        durationMin: 0,
        isLoading: !_failed,
        hasError: _failed,
      );
    }

    if (!originIsDriver || driver == null) {
      return LiveRouteView(
        points: route.points,
        distanceKm: route.distanceKm,
        durationMin: route.durationMin,
      );
    }

    final remaining = remainingRoute(
      route.points.map(_toGeo).toList(),
      _toGeo(driver),
    );
    final remainingKm = polylineLengthMeters(remaining) / 1000;
    final totalKm = route.distanceKm <= 0 ? remainingKm : route.distanceKm;
    final minutes = totalKm <= 0
        ? 0
        : (route.durationMin * (remainingKm / totalKm)).ceil();
    return LiveRouteView(
      points: <LatLng>[driver, ...remaining.skip(1).map(_toLatLng)],
      distanceKm: remainingKm,
      durationMin: minutes,
    );
  }

  void _fetch(DriverRouteLeg leg, {required bool force}) {
    if (_fetching) return;
    final now = DateTime.now();
    final last = _lastAttempt;
    if (!force && last != null && now.difference(last) < _minRetryGap) return;
    _fetching = true;
    _lastAttempt = now;
    final target = leg.destination;
    unawaited(() async {
      try {
        final route = await fetchDriverRoute(ref.read(supabaseProvider), leg);
        if (!ref.mounted || _target != target) return;
        _route = route;
        _fetchedAt = DateTime.now();
        _failed = false;
      } catch (_) {
        if (!ref.mounted || _target != target) return;
        _failed = _route == null;
      } finally {
        _fetching = false;
      }
      if (ref.mounted) state = _view(ref.read(homeProvider));
    }());
  }
}

final liveRouteProvider = NotifierProvider<LiveRouteNotifier, LiveRouteView?>(
  LiveRouteNotifier.new,
);
