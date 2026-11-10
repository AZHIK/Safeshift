import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/config/api_config.dart';
import '../../../../core/network/supabase_client.dart';
import '../../../../core/network/supabase_init.dart';

/// Result of a road route computation returned by the `maps-route` edge
/// function (Google Routes API `Compute Routes`).
class RouteResult {
  const RouteResult({
    required this.distanceKm,
    required this.durationMin,
    required this.encodedPolyline,
    this.routeLabel,
    this.trafficAware = false,
  });

  final double distanceKm;
  final int durationMin;
  final String encodedPolyline;
  final String? routeLabel;
  final bool trafficAware;
}

/// Routing errors surfaced to the rider without exposing provider internals.
enum RouteErrorType {
  notConfigured,
  network,
  timeout,
  invalidRequest,
  notFound,
  rateLimited,
  noRoute,
  server,
  unknown,
}

class RouteException implements Exception {
  const RouteException(this.type, this.message, {this.statusCode});

  final RouteErrorType type;
  final String message;
  final int? statusCode;

  bool get isConfigurationError => type == RouteErrorType.notConfigured;
  bool get isRateLimited => type == RouteErrorType.rateLimited;
  bool get isNoRoute => type == RouteErrorType.noRoute;
  bool get isNetwork => type == RouteErrorType.network;

  @override
  String toString() => 'RouteException($type)';
}

/// Computes actual road routes between two points via the `maps-route` Supabase
/// Edge Function, which wraps Google Routes API `Compute Routes` server-side.
///
/// Provider credentials never reach the client: the function holds the Google
/// Maps API key in Supabase Vault and attaches the user's Supabase JWT itself.
class RouteService {
  RouteService({SupabaseClient? client}) : _client = client ?? SupabaseInit.client;

  final SupabaseClient _client;

  /// Returns a [RouteResult] describing the driving route from [origin] to
  /// [destination]. Throws [RouteException] on failure.
  Future<RouteResult> computeRoute({
    required double originLat,
    required double originLng,
    required double destinationLat,
    required double destinationLng,
  }) async {
    if (!_isValidCoordinate(originLat, originLng)) {
      throw const RouteException(
        RouteErrorType.invalidRequest,
        'Invalid pickup coordinates.',
      );
    }
    if (!_isValidCoordinate(destinationLat, destinationLng)) {
      throw const RouteException(
        RouteErrorType.invalidRequest,
        'Invalid destination coordinates.',
      );
    }

    final body = <String, dynamic>{
      'origin': {'lat': originLat, 'lng': originLng},
      'destination': {'lat': destinationLat, 'lng': destinationLng},
      'mode': 'driving',
    };

    final FunctionResponse response;
    try {
      response = await _client.functions.invoke(
        ApiConfig.mapsRoute,
        body: body,
      );
    } on FunctionException catch (error) {
      throw mapRouteFunctionException(error);
    } on Exception {
      throw const RouteException(
        RouteErrorType.network,
        'You appear to be offline. Check your connection and try again.',
      );
    }

    // `functions.invoke` wraps the decoded body in a `FunctionResponse`. The
    // Edge Function envelope ({ data, error }) lives in `.data`; the wrapper
    // itself is not a Map.
    final payload = response.data;
    if (payload is! Map) {
      throw const RouteException(
        RouteErrorType.server,
        'The routing service returned an invalid response.',
      );
    }

    final error = payload['error'];
    if (error != null && error is Map) {
      final code = (error['code'] as String? ?? '').toLowerCase();
      if (code == 'provider_unavailable' || code == 'provider_error') {
        // The provider message ("google_maps rejected the request") and the
        // error details are for operators, not riders. Keep them out of the UI.
        _debugProviderError(error);
        throw const RouteException(
          RouteErrorType.server,
          'The routing service is unavailable right now. Please try again.',
        );
      }
      if (code == 'rate_limited') {
        throw const RouteException(
          RouteErrorType.rateLimited,
          'Too many route requests. Please wait and try again.',
        );
      }
      if (code == 'validation_error') {
        throw const RouteException(
          RouteErrorType.invalidRequest,
          'Could not calculate a route for these locations.',
        );
      }
      throw const RouteException(
        RouteErrorType.server,
        'The routing service could not complete that request.',
      );
    }

    final data = payload['data'];
    if (data == null || data is! Map) {
      throw const RouteException(
        RouteErrorType.server,
        'The routing service returned no route data.',
      );
    }

    final distanceKm = (data['distance_km'] as num?)?.toDouble();
    final durationMin = (data['duration_min'] as num?)?.toInt();
    final encodedPolyline = data['encoded_polyline'] as String?;

    if (distanceKm == null || distanceKm <= 0) {
      throw const RouteException(
        RouteErrorType.noRoute,
        'No driving route was found between these locations.',
      );
    }
    if (durationMin == null || durationMin <= 0) {
      throw const RouteException(
        RouteErrorType.noRoute,
        'No driving route was found between these locations.',
      );
    }
    if (encodedPolyline == null || encodedPolyline.isEmpty) {
      throw const RouteException(
        RouteErrorType.noRoute,
        'The route could not be resolved. Try a nearby location.',
      );
    }

    return RouteResult(
      distanceKm: distanceKm,
      durationMin: durationMin,
      encodedPolyline: encodedPolyline,
      routeLabel: data['route_label'] as String?,
      trafficAware: data['traffic_aware'] as bool? ?? false,
    );
  }

  bool _isValidCoordinate(double lat, double lng) =>
      lat.isFinite &&
      lng.isFinite &&
      lat >= -90 &&
      lat <= 90 &&
      lng >= -180 &&
      lng <= 180;

  /// Prints the provider-side detail of a failed routing call.
  ///
  /// The Edge Function returns the actionable provider status and message in
  /// `error.details` (for example `INVALID_ARGUMENT` or `API_KEY_INVALID`).
  /// Riders never see it, but it is the only clue when the route silently
  /// fails to draw.
  void _debugProviderError(Map<Object?, Object?> error) {
    if (!kDebugMode) return;
    final details = error['details'];
    debugPrint(
      'SafeShift route provider error: '
      '${error['message']} ${details is Map ? details : ''}',
    );
  }

  /// Translates a failed Edge Function invocation into a rider-safe error.
  ///
  /// The HTTP status is the only signal available here. A 404 means the
  /// `maps-route` function is not deployed on the project, which is a
  /// deployment problem rather than a rider problem.
  @visibleForTesting
  static RouteException mapRouteFunctionException(FunctionException error) {
    final status = error.status;
    if (status == 401 || status == 403) {
      return const RouteException(
        RouteErrorType.invalidRequest,
        'Routing is not available. Check the Google Maps configuration.',
      );
    }
    if (status == 404) {
      // The `maps-route` Edge Function is not deployed on this project.
      return const RouteException(
        RouteErrorType.notConfigured,
        'Routing is not available right now. Please try again shortly.',
      );
    }
    if (status == 429) {
      return const RouteException(
        RouteErrorType.rateLimited,
        'Too many route requests. Please wait and try again.',
        statusCode: 429,
      );
    }
    if (status == 502) {
      return const RouteException(
        RouteErrorType.server,
        'The routing service is unavailable right now. Please try again.',
      );
    }
    if (status >= 500) {
      return const RouteException(
        RouteErrorType.server,
        'The routing service is unavailable right now. Please try again.',
      );
    }
    return const RouteException(
      RouteErrorType.unknown,
      'Something went wrong while calculating the route. Please try again.',
    );
  }
}

/// Provides a shared, keep-alive route service instance.
///
/// The Supabase client comes from [supabaseProvider] rather than the
/// `SupabaseInit` global, so the routing flow follows the same rule as every
/// other feature and stays testable.
final routeServiceProvider = Provider<RouteService>((ref) {
  ref.keepAlive();
  return RouteService(client: ref.watch(supabaseProvider));
});
