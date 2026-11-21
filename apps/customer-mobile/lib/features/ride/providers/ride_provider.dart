import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import 'package:safeshift_shared/safeshift_shared.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/error_handler.dart';
import '../../../core/network/supabase_client.dart';
import '../../../shared/mock/mock_payment_methods.dart';
import '../../../shared/models/ride_place.dart';
import '../../../shared/providers/places_provider.dart';
import '../../../shared/utils/polyline.dart';
import '../../auth/providers/auth_provider.dart';
import '../../tracking/domain/entities/driver.dart';
import '../data/ride_repository.dart';
import '../data/route_service.dart';

/// Single-screen Bolt-style flow. Everything happens on RideScreen,
/// the bottom sheet just morphs through these stages.
enum RideStage {
  /// Map + "Where to?" + saved places.
  idle,

  /// Pickup + destination chosen, route preview on map.
  route,

  /// Vehicle carousel visible.
  vehicle,

  /// Quote + confirm visible.
  confirm,

  /// Searching for driver (radar).
  searching,

  /// Driver assigned + live tracking.
  tracking,

  /// Delivered / receipt.
  done,
}

class RideState {
  RideState({
    this.stage = RideStage.idle,
    this.pickup,
    this.destination,
    this.vehicleClass,
    this.cargo,
    this.scheduledAt,
    this.driver,
    this.etaMin = 7,
    this.distanceKm = 0,
    this.durationMin = 0,
    this.parcelDescription,
    this.parcelWeightKg,
    this.parcelValueTzs,
    this.parcelPhotoPaths = const <String>[],
    this.cargoPhotoPaths = const <String>[],
    MockPaymentMethod? paymentMethod,
    this.quoteId,
    this.jobId,
    this.jobStatus,
    this.pickupAddress,
    this.destinationAddress,
    this.quoteTotal,
    this.quoteSubtotal,
    this.quoteVat,
    this.deliveryOtp,
    this.errorMessage,
    this.routeError,
    this.acceptedAt,
    this.cancellationReason,
    this.cancellationFee,
    this.dispatchAttempts = 0,
    this.driverLocationFresh = false,
    this.driverLocationUpdatedAt,
    this.isQuoting = false,
    this.isSubmitting = false,
    this.isRouting = false,
    this.isUploadingPhotos = false,
    this.routePoints = const <LatLng>[],
    this.driverLatitude,
    this.driverLongitude,
    this.alternativeVehicles = const <AlternativeVehicle>[],
    this.pickupFreeWaitEndsAt,
    this.recipientName,
    this.recipientPhone,
    this.driverHeading,
    this.liveEtaMin,
    this.liveRemainingKm,
  }) : paymentMethod = paymentMethod ?? mockPaymentMethods.first;

  final RideStage stage;
  final RidePlace? pickup;
  final RidePlace? destination;
  final VehicleTypeOption? vehicleClass;
  final CargoTypeOption? cargo;

  /// Requested pickup time. `null` means "now".
  final DateTime? scheduledAt;

  final Driver? driver;
  final int etaMin;
  final double distanceKm;
  final int durationMin;
  // Parcel details (filled via dialog, stays on the single screen).
  final String? parcelDescription;
  final double? parcelWeightKg;
  final int? parcelValueTzs;

  /// Local filesystem paths chosen in the parcel dialog.
  final List<String> parcelPhotoPaths;

  /// Object paths inside `job-evidence` after the photos are uploaded.
  final List<String> cargoPhotoPaths;

  final MockPaymentMethod paymentMethod;

  // Backend identifiers and live values.
  final String? quoteId;
  final String? jobId;
  final String? jobStatus;
  final String? pickupAddress;
  final String? destinationAddress;
  final double? quoteTotal;
  final double? quoteSubtotal;
  final double? quoteVat;
  final String? deliveryOtp;
  final String? errorMessage;

  /// User-facing message when road-route calculation fails.
  final String? routeError;

  final DateTime? acceptedAt;
  final String? cancellationReason;
  final double? cancellationFee;
  final int dispatchAttempts;

  /// Whether the driver's last GPS fix is recent enough to trust.
  final bool driverLocationFresh;
  final DateTime? driverLocationUpdatedAt;

  final bool isQuoting;
  final bool isSubmitting;
  final bool isUploadingPhotos;

  /// True while a road route is being calculated for the current endpoints.
  final bool isRouting;

  /// Decoded road-following polyline between pickup and destination.
  final List<LatLng> routePoints;
  final double? driverLatitude;
  final double? driverLongitude;

  /// Other vehicle classes that can carry this load and have free drivers
  /// nearby. Filled only when dispatch found no driver with the booked class.
  final List<AlternativeVehicle> alternativeVehicles;

  /// When the driver's free waiting time at the pickup ends. Set only while
  /// the job is in `arrived`.
  final DateTime? pickupFreeWaitEndsAt;

  /// Person receiving the goods when it is not the customer. They get the
  /// tracking link and the delivery code by SMS.
  final String? recipientName;
  final String? recipientPhone;
  bool get hasRecipient => (recipientPhone ?? '').isNotEmpty;

  /// Driver's direction of travel (0–359), from the live broadcast.
  final double? driverHeading;

  /// Minutes and km left on the leg in progress, from the locally trimmed
  /// route. Null outside a driving leg.
  final int? liveEtaMin;
  final double? liveRemainingKm;

  /// Coordinates sent to the road-routing service for this job status.
  ({LatLng origin, LatLng target})? get trackingLeg {
    final start = pickup;
    final end = destination;
    if (start == null ||
        end == null ||
        !start.hasCoordinates ||
        !end.hasCoordinates) {
      return null;
    }
    final pickupPoint = LatLng(start.latitude, start.longitude);
    final destinationPoint = LatLng(end.latitude, end.longitude);
    switch (jobStatus) {
      case 'accepted':
      case 'heading_to_pickup':
      case 'in_transit':
        final lat = driverLatitude;
        final lng = driverLongitude;
        if (lat == null || lng == null) return null;
        return (
          origin: LatLng(lat, lng),
          target: jobStatus == 'in_transit' ? destinationPoint : pickupPoint,
        );
      case 'requested':
      case 'quoted':
      case 'matched':
      case 'arrived':
      case 'cargo_verified':
      case 'loading':
        return (origin: pickupPoint, target: destinationPoint);
      default:
        return null;
    }
  }

  bool get hasRoute => pickup != null && destination != null;
  bool get isScheduled => scheduledAt != null;
  bool get hasParcelDetails =>
      (parcelDescription?.trim().isNotEmpty ?? false) ||
      parcelWeightKg != null ||
      parcelValueTzs != null ||
      parcelPhotoPaths.isNotEmpty;

  /// True only when the parcel details the driver needs (value + photo) are
  /// complete. Vehicles and quotes must not be shown before this.
  bool get hasRequiredParcelDetails =>
      parcelValueTzs != null &&
      parcelValueTzs! > 0 &&
      parcelPhotoPaths.isNotEmpty;

  /// Human label for the schedule pill. "Now" until a time is chosen.
  String get scheduledLabel {
    final at = scheduledAt;
    if (at == null) return 'Now';
    final local = at.toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(local.year, local.month, local.day);
    final days = day.difference(today).inDays;
    final time = DateFormat('h:mm a').format(local);
    if (days == 0) return 'Today $time';
    if (days == 1) return 'Tomorrow $time';
    return DateFormat('EEE d MMM, h:mm a').format(local);
  }

  RideState copyWith({
    RideStage? stage,
    RidePlace? pickup,
    RidePlace? destination,
    VehicleTypeOption? vehicleClass,
    CargoTypeOption? cargo,
    DateTime? scheduledAt,
    Driver? driver,
    int? etaMin,
    double? distanceKm,
    int? durationMin,
    String? parcelDescription,
    double? parcelWeightKg,
    int? parcelValueTzs,
    List<String>? parcelPhotoPaths,
    List<String>? cargoPhotoPaths,
    MockPaymentMethod? paymentMethod,
    String? quoteId,
    String? jobId,
    String? jobStatus,
    String? pickupAddress,
    String? destinationAddress,
    double? quoteTotal,
    double? quoteSubtotal,
    double? quoteVat,
    String? deliveryOtp,
    String? errorMessage,
    String? routeError,
    DateTime? acceptedAt,
    String? cancellationReason,
    double? cancellationFee,
    int? dispatchAttempts,
    bool? driverLocationFresh,
    DateTime? driverLocationUpdatedAt,
    bool? isQuoting,
    bool? isSubmitting,
    bool? isUploadingPhotos,
    bool? isRouting,
    double? driverLatitude,
    double? driverLongitude,
    List<LatLng>? routePoints,
    List<AlternativeVehicle>? alternativeVehicles,
    bool clearAlternatives = false,
    DateTime? pickupFreeWaitEndsAt,
    bool clearPickupWait = false,
    String? recipientName,
    String? recipientPhone,
    bool clearRecipient = false,
    double? driverHeading,
    int? liveEtaMin,
    double? liveRemainingKm,
    bool clearLiveEta = false,
    bool clearDriver = false,
    bool clearDriverLocation = false,
    bool clearParcel = false,
    bool clearQuote = false,
    bool clearJob = false,
    bool clearOtp = false,
    bool clearError = false,
    bool clearRouteError = false,
    bool clearCargo = false,
    bool clearSchedule = false,
    bool clearVehicle = false,
  }) {
    return RideState(
      stage: stage ?? this.stage,
      pickup: pickup ?? this.pickup,
      destination: destination ?? this.destination,
      vehicleClass: clearVehicle ? null : (vehicleClass ?? this.vehicleClass),
      cargo: clearCargo ? null : (cargo ?? this.cargo),
      scheduledAt: clearSchedule ? null : (scheduledAt ?? this.scheduledAt),
      driver: clearDriver ? null : (driver ?? this.driver),
      etaMin: etaMin ?? this.etaMin,
      distanceKm: distanceKm ?? this.distanceKm,
      durationMin: durationMin ?? this.durationMin,
      parcelDescription: clearParcel
          ? null
          : (parcelDescription ?? this.parcelDescription),
      parcelWeightKg: clearParcel
          ? null
          : (parcelWeightKg ?? this.parcelWeightKg),
      parcelValueTzs: clearParcel
          ? null
          : (parcelValueTzs ?? this.parcelValueTzs),
      parcelPhotoPaths: clearParcel
          ? const <String>[]
          : (parcelPhotoPaths ?? this.parcelPhotoPaths),
      cargoPhotoPaths: clearParcel
          ? const <String>[]
          : (cargoPhotoPaths ?? this.cargoPhotoPaths),
      paymentMethod: paymentMethod ?? this.paymentMethod,
      quoteId: clearQuote ? null : (quoteId ?? this.quoteId),
      jobId: clearJob ? null : (jobId ?? this.jobId),
      jobStatus: clearJob ? null : (jobStatus ?? this.jobStatus),
      pickupAddress: clearJob ? null : (pickupAddress ?? this.pickupAddress),
      destinationAddress: clearJob
          ? null
          : (destinationAddress ?? this.destinationAddress),
      quoteTotal: clearQuote ? null : (quoteTotal ?? this.quoteTotal),
      quoteSubtotal: clearQuote ? null : (quoteSubtotal ?? this.quoteSubtotal),
      quoteVat: clearQuote ? null : (quoteVat ?? this.quoteVat),
      deliveryOtp: clearOtp ? null : (deliveryOtp ?? this.deliveryOtp),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      routeError: clearRouteError ? null : (routeError ?? this.routeError),
      acceptedAt: clearJob ? null : (acceptedAt ?? this.acceptedAt),
      cancellationReason: clearJob
          ? null
          : (cancellationReason ?? this.cancellationReason),
      cancellationFee: clearJob
          ? null
          : (cancellationFee ?? this.cancellationFee),
      dispatchAttempts: clearJob
          ? 0
          : (dispatchAttempts ?? this.dispatchAttempts),
      driverLocationFresh: clearDriver || clearDriverLocation
          ? false
          : (driverLocationFresh ?? this.driverLocationFresh),
      driverLocationUpdatedAt: clearDriver || clearDriverLocation
          ? null
          : (driverLocationUpdatedAt ?? this.driverLocationUpdatedAt),
      isQuoting: isQuoting ?? this.isQuoting,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      isUploadingPhotos: isUploadingPhotos ?? this.isUploadingPhotos,
      isRouting: isRouting ?? this.isRouting,
      routePoints: routePoints ?? this.routePoints,
      driverLatitude: clearDriver || clearDriverLocation
          ? null
          : (driverLatitude ?? this.driverLatitude),
      driverLongitude: clearDriver || clearDriverLocation
          ? null
          : (driverLongitude ?? this.driverLongitude),
      alternativeVehicles: clearAlternatives || clearJob
          ? const <AlternativeVehicle>[]
          : (alternativeVehicles ?? this.alternativeVehicles),
      pickupFreeWaitEndsAt: clearPickupWait || clearJob
          ? null
          : (pickupFreeWaitEndsAt ?? this.pickupFreeWaitEndsAt),
      recipientName: clearRecipient
          ? null
          : (recipientName ?? this.recipientName),
      recipientPhone: clearRecipient
          ? null
          : (recipientPhone ?? this.recipientPhone),
      driverHeading: clearDriver || clearDriverLocation
          ? null
          : (driverHeading ?? this.driverHeading),
      liveEtaMin: clearLiveEta || clearDriver || clearJob
          ? null
          : (liveEtaMin ?? this.liveEtaMin),
      liveRemainingKm: clearLiveEta || clearDriver || clearJob
          ? null
          : (liveRemainingKm ?? this.liveRemainingKm),
    );
  }
}

/// A vehicle class the customer can switch to while searching.
class AlternativeVehicle {
  const AlternativeVehicle({required this.vehicle, required this.driverCount});

  final VehicleTypeOption vehicle;

  /// Free, online drivers with this class near the pickup.
  final int driverCount;
}

/// Server reason when no online driver has the booked vehicle class.
const _noDriverOfClassReason =
    'no online driver has a vehicle of the requested class';

final _tzs = NumberFormat('#,##0');

class RideNotifier extends Notifier<RideState> {
  int _quoteGen = 0;
  int _routeGen = 0;
  int _refreshGeneration = 0;
  Timer? _routeTimer;
  RealtimeChannel? _channel;
  RealtimeChannel? _locationChannel;
  Timer? _poll;
  String? _otpIssuedFor;
  String? _pickupWaitFor;
  String? _recipientLoadedFor;
  DateTime? _lastAutoDispatch;

  /// Catalogue ids of the job being tracked, used to restore the vehicle and
  /// cargo selection after a cold-start resume.
  String? _jobVehicleTypeId;
  String? _jobCargoTypeId;
  String? _jobPaymentMethod;
  Future<void>? _catalogRestore;
  String? _catalogRestoreFor;

  /// Parcel photos already in storage under a previous job, to copy into the
  /// next job when the local files are no longer available.
  List<String> _carryOverPhotoPaths = const <String>[];

  static const Duration _autoDispatchCooldown = Duration(seconds: 50);

  RideRepository get _repo => RideRepository(ref.read(supabaseProvider));
  RouteService get _routeService => ref.read(routeServiceProvider);

  @override
  RideState build() {
    ref.onDispose(_cleanup);
    return RideState();
  }

  /// Latest vehicle availability near the pickup; null when unknown (not
  /// loaded or failed), in which case booking is never blocked.
  Map<String, VehicleAvailability>? _availability;

  /// True once the customer tapped a vehicle themselves. Until then the app
  /// may move the selection to a vehicle that has drivers nearby.
  bool _vehiclePickedByUser = false;

  /// Availability of [vehicleTypeId], or null when unknown.
  VehicleAvailability? availabilityFor(String? vehicleTypeId) {
    final availability = _availability;
    if (availability == null || vehicleTypeId == null) return null;
    return availability[vehicleTypeId] ?? VehicleAvailability.unavailable;
  }

  /// Whether the pickup is far enough ahead that dispatch waits (the server
  /// starts searching 45 minutes before pickup).
  bool get _scheduledForLater {
    final at = state.scheduledAt;
    return at != null &&
        at.isAfter(DateTime.now().add(const Duration(minutes: 45)));
  }

  /// Records fresh availability and, while the customer has not chosen a
  /// vehicle themselves, moves the selection to the best available one.
  /// [compatible] is the picker's list in catalogue order (smallest and
  /// cheapest first).
  void applyVehicleAvailability(
    Map<String, VehicleAvailability>? availability,
    List<VehicleTypeOption> compatible,
  ) {
    _availability = availability;
    if (availability == null || compatible.isEmpty) return;
    if (_vehiclePickedByUser || state.jobId != null) return;
    if (state.stage != RideStage.vehicle && state.stage != RideStage.confirm) {
      return;
    }
    int rank(VehicleTypeOption v) =>
        (availability[v.id] ?? VehicleAvailability.unavailable).rank;
    VehicleTypeOption? best;
    for (final v in compatible) {
      if (best == null || rank(v) < rank(best)) best = v;
    }
    final current = state.vehicleClass;
    if (best == null || best.id == current?.id) return;
    if (current != null &&
        compatible.any((v) => v.id == current.id) &&
        rank(current) <= rank(best)) {
      return;
    }
    state = state.copyWith(
      vehicleClass: best,
      clearQuote: true,
      clearError: true,
    );
    if (state.hasRoute) unawaited(refreshQuote());
  }

  void ensureVehicleSelected(List<VehicleTypeOption> vehicles) {
    if (vehicles.isEmpty) return;
    final current = state.vehicleClass;
    // Keep a valid selection. If the selected vehicle disappeared from the
    // bookable catalogue (for example its pricing plan was disabled), replace
    // it so the customer cannot keep quoting an unpriceable vehicle.
    if (current != null && vehicles.any((v) => v.id == current.id)) {
      return;
    }
    final preferred = vehicles.length > 1 ? vehicles[1] : vehicles.first;
    state = state.copyWith(
      vehicleClass: preferred,
      clearQuote: true,
      clearError: true,
    );
  }

  void setPickup(RidePlace location) {
    state = state.copyWith(
      pickup: location,
      clearQuote: true,
      clearError: true,
      clearRouteError: true,
      routePoints: const <LatLng>[],
    );
    if (state.hasRoute) {
      state = state.copyWith(stage: RideStage.vehicle);
      unawaited(refreshQuote());
      _scheduleRouteCalculation();
    }
  }

  void setDestination(RidePlace location) {
    state = state.copyWith(
      destination: location,
      clearQuote: true,
      clearError: true,
      clearRouteError: true,
      routePoints: const <LatLng>[],
    );
    if (state.hasRoute) {
      state = state.copyWith(stage: RideStage.vehicle);
      unawaited(refreshQuote());
      _scheduleRouteCalculation();
    }
  }

  void swap() {
    final p = state.pickup;
    final d = state.destination;
    if (p == null || d == null) return;
    state = state.copyWith(
      pickup: d,
      destination: p,
      clearQuote: true,
      clearError: true,
      clearRouteError: true,
      routePoints: const <LatLng>[],
    );
    unawaited(refreshQuote());
    _scheduleRouteCalculation();
  }

  /// Debounces route recalculation so rapid endpoint changes do not fire a
  /// request on every keystroke or pin drag.
  void _scheduleRouteCalculation() {
    _routeTimer?.cancel();
    final gen = ++_routeGen;
    _routeTimer = Timer(const Duration(milliseconds: 400), () async {
      if (gen != _routeGen) return;
      await _computeRoute(gen);
    });
  }

  /// Calculates the road route for the current endpoints and stores the decoded
  /// polyline, distance, and duration. Stale results are discarded when a
  /// newer calculation supersedes them.
  Future<void> _computeRoute(int generation) async {
    final pickup = state.pickup;
    final destination = state.destination;
    if (pickup == null ||
        destination == null ||
        !pickup.hasCoordinates ||
        !destination.hasCoordinates) {
      return;
    }

    state = state.copyWith(isRouting: true, clearRouteError: true);
    try {
      final result = await _routeService.computeRoute(
        originLat: pickup.latitude,
        originLng: pickup.longitude,
        destinationLat: destination.latitude,
        destinationLng: destination.longitude,
      );
      // Ignore results from superseded requests.
      if (generation != _routeGen || !ref.mounted) return;
      final points = decodePolyline(result.encodedPolyline);
      state = state.copyWith(
        isRouting: false,
        routePoints: points,
        distanceKm: result.distanceKm,
        durationMin: result.durationMin,
        clearRouteError: true,
      );
      // Price the real road route rather than the straight-line estimate.
      if (state.vehicleClass != null) {
        unawaited(refreshQuote());
      }
    } on RouteException catch (error) {
      if (generation != _routeGen || !ref.mounted) return;
      state = state.copyWith(
        isRouting: false,
        routePoints: const <LatLng>[],
        routeError: error.message,
      );
    } catch (error, stack) {
      if (generation != _routeGen || !ref.mounted) return;
      state = state.copyWith(
        isRouting: false,
        routePoints: const <LatLng>[],
        routeError: ErrorHandler.map(error, stackTrace: stack).message,
      );
    }
  }

  /// Shows the current driving leg, and the booked route between legs.
  ///
  /// The route is fetched once per leg and trimmed on the device as the
  /// driver advances. It is fetched again only when the driver strays more
  /// than 80 m from it, the leg changes, or it is older than 5 minutes.
  Future<void> _computeTrackingRoute() async {
    final leg = state.trackingLeg;
    if (leg == null) {
      _trackingRoute = const <LatLng>[];
      _trackingTarget = null;
      _routeGen++;
      if (state.routePoints.isNotEmpty ||
          state.isRouting ||
          state.liveEtaMin != null) {
        state = state.copyWith(
          routePoints: const <LatLng>[],
          isRouting: false,
          clearLiveEta: true,
        );
      }
      return;
    }
    final (:origin, :target) = leg;
    final originIsDriver = _driverLegStatuses.contains(state.jobStatus);

    final legChanged =
        _trackingTarget != target || _trackingOriginIsDriver != originIsDriver;
    if (legChanged) {
      _trackingRoute = const <LatLng>[];
      _trackingFetchedAt = null;
      _trackingTarget = target;
      _trackingOriginIsDriver = originIsDriver;
    }

    final needsFetch =
        _trackingRoute.length < 2 ||
        (originIsDriver &&
            _rerouteRule.needsReroute(
              route: _trackingRoute.map(_geo).toList(),
              position: _geo(origin),
              fetchedAt: _trackingFetchedAt ?? DateTime(2000),
            ));
    if (!needsFetch) {
      _applyTrackingRoute();
      return;
    }

    final now = DateTime.now();
    final lastAttempt = _trackingLastAttempt;
    if (!legChanged &&
        lastAttempt != null &&
        now.difference(lastAttempt) < const Duration(seconds: 20)) {
      _applyTrackingRoute();
      return;
    }
    _trackingLastAttempt = now;

    final generation = ++_routeGen;
    try {
      final result = await _routeService.computeRoute(
        originLat: origin.latitude,
        originLng: origin.longitude,
        destinationLat: target.latitude,
        destinationLng: target.longitude,
      );
      if (generation != _routeGen || !ref.mounted) return;
      _trackingRoute = decodePolyline(result.encodedPolyline);
      _trackingFetchedAt = DateTime.now();
      _trackingKm = result.distanceKm;
      _trackingMin = result.durationMin;
      state = state.copyWith(isRouting: false);
      _applyTrackingRoute();
    } catch (_) {
      if (generation != _routeGen || !ref.mounted) return;
      // Keep the previous route (if any); retry after the gap.
      state = state.copyWith(isRouting: false);
      _applyTrackingRoute();
    }
  }

  static const _rerouteRule = RerouteRule();
  static const _driverLegStatuses = <String?>{
    'accepted',
    'heading_to_pickup',
    'in_transit',
  };
  static GeoPoint _geo(LatLng p) => (lat: p.latitude, lng: p.longitude);

  List<LatLng> _trackingRoute = const <LatLng>[];
  DateTime? _trackingFetchedAt;
  DateTime? _trackingLastAttempt;
  LatLng? _trackingTarget;
  bool _trackingOriginIsDriver = false;
  double _trackingKm = 0;
  int _trackingMin = 0;

  /// Publishes the route still ahead of the driver, and its ETA.
  void _applyTrackingRoute() {
    final route = _trackingRoute;
    if (route.length < 2) {
      if (state.routePoints.isNotEmpty) {
        state = state.copyWith(
          routePoints: const <LatLng>[],
          clearLiveEta: true,
        );
      }
      return;
    }
    final lat = state.driverLatitude;
    final lng = state.driverLongitude;
    if (!_trackingOriginIsDriver || lat == null || lng == null) {
      state = state.copyWith(routePoints: route, clearLiveEta: true);
      return;
    }
    final remaining = remainingRoute(route.map(_geo).toList(), (
      lat: lat,
      lng: lng,
    ));
    final remainingKm = polylineLengthMeters(remaining) / 1000;
    final totalKm = _trackingKm <= 0 ? remainingKm : _trackingKm;
    final minutes = totalKm <= 0
        ? 0
        : (_trackingMin * (remainingKm / totalKm)).ceil();
    state = state.copyWith(
      routePoints: <LatLng>[
        LatLng(lat, lng),
        ...remaining.skip(1).map((p) => LatLng(p.lat, p.lng)),
      ],
      liveEtaMin: minutes,
      liveRemainingKm: remainingKm,
    );
  }

  void selectVehicle(VehicleTypeOption vehicle) {
    _vehiclePickedByUser = true;
    state = state.copyWith(
      vehicleClass: vehicle,
      stage: RideStage.confirm,
      clearQuote: true,
      clearError: true,
    );
    unawaited(refreshQuote());
  }

  void selectCargo(CargoTypeOption cargo) {
    final currentVehicle = state.vehicleClass;
    final weight = state.parcelWeightKg;
    final clearVehicle =
        currentVehicle != null &&
        !canVehicleCarryCargo(currentVehicle, cargo, weight);
    // The customer must pick again when their vehicle no longer fits.
    if (clearVehicle) _vehiclePickedByUser = false;
    state = state.copyWith(
      cargo: cargo,
      clearVehicle: clearVehicle,
      clearQuote: true,
      clearError: true,
    );
    if (state.hasRoute) unawaited(refreshQuote());
  }

  /// Sets (or clears, with `null`) the requested pickup time.
  ///
  /// Any schedule change invalidates the quote because time-of-day pricing and
  /// the scheduled-at field are part of it.
  void setScheduledAt(DateTime? at) {
    state = state.copyWith(
      scheduledAt: at,
      clearSchedule: at == null,
      clearQuote: true,
      clearError: true,
    );
    if (state.hasRoute) unawaited(refreshQuote());
  }

  /// Payment selection is displayed immediately. Phase 5 settlement remains
  /// server-owned; the client never marks a job paid.
  void selectPaymentMethod(MockPaymentMethod method) {
    state = state.copyWith(paymentMethod: method);
  }

  void setParcelDetails({
    String? description,
    double? weightKg,
    int? valueTzs,
    List<String>? photoPaths,
  }) {
    final newWeight = weightKg ?? state.parcelWeightKg;
    final currentVehicle = state.vehicleClass;
    final cargo = state.cargo;
    final clearVehicle =
        currentVehicle != null &&
        !canVehicleCarryCargo(currentVehicle, cargo, newWeight);
    if (clearVehicle) _vehiclePickedByUser = false;
    state = state.copyWith(
      parcelDescription: description ?? state.parcelDescription,
      parcelWeightKg: weightKg ?? state.parcelWeightKg,
      parcelValueTzs: valueTzs ?? state.parcelValueTzs,
      parcelPhotoPaths: photoPaths ?? state.parcelPhotoPaths,
      clearVehicle: clearVehicle,
      clearQuote: true,
    );
    if (state.hasRoute) unawaited(refreshQuote());
  }

  /// Sets the recipient, or clears it with nulls ("I'm receiving it").
  void setRecipient({String? name, String? phone}) {
    final trimmedName = name?.trim() ?? '';
    final trimmedPhone = phone?.replaceAll(RegExp(r'[\s()-]'), '') ?? '';
    if (trimmedName.isEmpty || trimmedPhone.isEmpty) {
      state = state.copyWith(clearRecipient: true);
    } else {
      state = state.copyWith(
        recipientName: trimmedName,
        recipientPhone: trimmedPhone,
      );
    }
    final jobId = state.jobId;
    if (jobId != null) unawaited(_saveRecipient(jobId));
  }

  Future<void> _saveRecipient(String jobId) async {
    try {
      await _repo.setRecipient(
        jobId,
        name: state.recipientName,
        phone: state.recipientPhone,
      );
    } catch (error, stack) {
      if (!ref.mounted || state.jobId != jobId) return;
      state = state.copyWith(
        errorMessage:
            'Your move is booked, but the recipient could not be saved. '
            '${ErrorHandler.map(error, stackTrace: stack).message}',
      );
    }
  }

  void clearParcelDetails() {
    state = state.copyWith(clearParcel: true, clearQuote: true);
    if (state.hasRoute) unawaited(refreshQuote());
  }

  /// Client-side mirror of the quote engine's load checks.
  ///
  /// The server remains authoritative, but failing here keeps the customer on
  /// the sheet with actionable copy instead of a rounded request error.
  String? _validateLoad(VehicleTypeOption vehicle) {
    final description = state.parcelDescription?.trim();
    if (description != null && description.length > 1000) {
      return 'Keep the parcel description under 1000 characters.';
    }

    final weight = state.parcelWeightKg;
    if (weight != null) {
      if (weight <= 0) return 'Enter a parcel weight greater than zero.';
      if (vehicle.capacityKgMax > 0 && weight > vehicle.capacityKgMax) {
        return 'This load weighs ${weight.toStringAsFixed(weight % 1 == 0 ? 0 : 1)} kg '
            'but a ${vehicle.name} carries at most '
            '${vehicle.capacityKgMax.round()} kg. Choose a larger vehicle.';
      }
    }

    final cargo = state.cargo;
    if (cargo != null) {
      if (cargo.allowedVehicleTypeCodes.isNotEmpty &&
          !cargo.allowedVehicleTypeCodes.contains(vehicle.code)) {
        return '${cargo.name} cannot travel in a ${vehicle.name}. '
            'Choose an allowed vehicle.';
      }
      if (cargo.prohibitedVehicleTypeCodes.contains(vehicle.code)) {
        return '${cargo.name} cannot travel in a ${vehicle.name}. '
            'Choose another vehicle.';
      }
      final maxValue = cargo.maxValueTzs;
      if (maxValue != null &&
          state.parcelValueTzs != null &&
          state.parcelValueTzs! > maxValue) {
        return 'The declared value is above the TZS '
            '${_tzs.format(maxValue)} limit for ${cargo.name}. '
            'Split the load or contact support.';
      }
    }

    if (state.parcelValueTzs == null || state.parcelValueTzs! <= 0) {
      return 'Add an approximate value for your parcel so the driver can '
          'handle it correctly.';
    }
    if (state.parcelPhotoPaths.isEmpty) {
      return 'Add at least one photo of the parcel.';
    }

    final scheduled = state.scheduledAt;
    if (scheduled != null) {
      final now = DateTime.now();
      if (scheduled.isBefore(now.subtract(const Duration(minutes: 1)))) {
        return 'Choose a pickup time in the future.';
      }
      if (scheduled.isAfter(now.add(const Duration(days: 60)))) {
        return 'Moves can be scheduled at most 60 days ahead.';
      }
    }

    if (state.distanceKm > 1000) {
      return 'This route is too long for a single move.';
    }
    return null;
  }

  Future<void> refreshQuote() async {
    final pickup = state.pickup;
    final destination = state.destination;
    final vehicle = state.vehicleClass;
    final user = ref.read(authProvider).currentUser;
    if (pickup == null ||
        destination == null ||
        vehicle == null ||
        user == null) {
      return;
    }

    final validationError = _validateLoad(vehicle);
    if (validationError != null) {
      _quoteGen++;
      state = state.copyWith(
        isQuoting: false,
        clearQuote: true,
        errorMessage: validationError,
      );
      return;
    }

    final gen = ++_quoteGen;
    state = state.copyWith(isQuoting: true, clearError: true);
    try {
      final quote = await _repo.requestQuote(
        pickup: pickup,
        destination: destination,
        vehicle: vehicle,
        cargo: state.cargo,
        weightKg: state.parcelWeightKg,
        valueTzs: state.parcelValueTzs,
        scheduledAt: state.scheduledAt,
        cargoDescription: state.parcelDescription,
      );
      if (gen != _quoteGen) return;
      state = state.copyWith(
        quoteId: quote.quoteId,
        quoteTotal: quote.total,
        quoteSubtotal: quote.subtotal,
        quoteVat: quote.vat,
        distanceKm: quote.distanceKm,
        durationMin: quote.durationMin,
        isQuoting: false,
      );
    } catch (error, stack) {
      if (gen != _quoteGen) return;
      state = state.copyWith(
        isQuoting: false,
        errorMessage: ErrorHandler.map(error, stackTrace: stack).message,
      );
    }
  }

  /// Creates the job from the persisted quote and starts dispatch. The search
  /// stays on the same screen and updates through realtime plus a slow poll
  /// fallback for unreliable mobile networks.
  /// False only when availability is known and no driver of [vehicle] is
  /// online nearby for a move that would be dispatched now. The list may be
  /// up to 25 s old, so a "none" is re-checked once before blocking.
  Future<bool> _vehicleCanBeBookedNow(VehicleTypeOption vehicle) async {
    if (_scheduledForLater) return true;
    if (!(availabilityFor(vehicle.id)?.isNone ?? false)) return true;
    final pickup = state.pickup;
    if (pickup == null) return true;
    try {
      final fresh = await _repo.vehicleAvailabilityNear(
        lat: pickup.latitude,
        lng: pickup.longitude,
      );
      if (!ref.mounted) return false;
      _availability = fresh;
      return !(availabilityFor(vehicle.id)?.isNone ?? false);
    } catch (_) {
      // Unknown: let dispatch decide rather than blocking the booking.
      return true;
    }
  }

  Future<void> confirmAndFindDriver() async {
    if (!state.hasRoute || state.isSubmitting) return;
    final user = ref.read(authProvider).currentUser;
    if (user == null) {
      state = state.copyWith(
        errorMessage: 'Your session expired. Please sign in again.',
      );
      return;
    }

    final vehicle = state.vehicleClass;
    if (vehicle == null) {
      state = state.copyWith(errorMessage: 'Choose a vehicle first.');
      return;
    }
    final validationError = _validateLoad(vehicle);
    if (validationError != null) {
      state = state.copyWith(
        stage: RideStage.confirm,
        errorMessage: validationError,
      );
      return;
    }
    if (!await _vehicleCanBeBookedNow(vehicle)) {
      state = state.copyWith(
        stage: RideStage.confirm,
        errorMessage:
            'No ${vehicle.name} drivers are near your pickup right now. '
            'Choose another vehicle or schedule the move for later.',
      );
      return;
    }

    state = state.copyWith(
      stage: RideStage.searching,
      isSubmitting: true,
      clearDriver: true,
      clearJob: true,
      clearOtp: true,
      clearError: true,
    );

    try {
      if (state.quoteId == null) {
        await refreshQuote();
        if (state.quoteId == null) {
          state = state.copyWith(
            stage: RideStage.confirm,
            isSubmitting: false,
            errorMessage: state.errorMessage ?? 'Could not price this move.',
          );
          return;
        }
      }

      final job = await _createJobWithFreshQuote(
        paymentMethod: state.paymentMethod.id,
      );
      state = state.copyWith(jobId: job.id, jobStatus: job.status);
      _subscribe(job.id);
      _startPolling(job.id);

      // Parcel photos are uploaded after the job exists so they land under the
      // path the storage policy expects. A failure here must not lose the
      // move: the customer can still complete it, and support can see the job.
      await _attachParcelPhotos(job.id);
      if (state.hasRecipient) await _saveRecipient(job.id);

      final dispatch = await _repo.dispatch(job.id);
      _lastAutoDispatch = DateTime.now();
      if (dispatch.count == 0) {
        final message = _noDriverMessage(dispatch);
        state = state.copyWith(
          isSubmitting: false,
          errorMessage: message,
          clearError: message == null,
        );
        unawaited(_updateAlternatives(job.id, dispatch));
        return;
      }
      state = state.copyWith(
        isSubmitting: false,
        clearError: true,
        clearAlternatives: true,
      );
    } catch (error, stack) {
      state = state.copyWith(
        stage: state.jobId == null ? RideStage.confirm : RideStage.searching,
        isSubmitting: false,
        errorMessage: ErrorHandler.map(error, stackTrace: stack).message,
      );
    }
  }

  Future<void> _attachParcelPhotos(String jobId) async {
    final paths = state.parcelPhotoPaths;
    final carryOver = _carryOverPhotoPaths;
    _carryOverPhotoPaths = const <String>[];
    if (paths.isEmpty && carryOver.isEmpty) return;
    state = state.copyWith(isUploadingPhotos: true);
    try {
      final uploaded = paths.isNotEmpty
          ? await _repo.uploadParcelPhotos(jobId: jobId, localPaths: paths)
          : await _repo.copyParcelPhotos(jobId: jobId, sourcePaths: carryOver);
      if (state.jobId == jobId) {
        state = state.copyWith(
          cargoPhotoPaths: uploaded,
          isUploadingPhotos: false,
        );
      }
    } catch (error, stack) {
      if (!ref.mounted) return;
      state = state.copyWith(
        isUploadingPhotos: false,
        errorMessage:
            'Your move is still active, but the parcel photos could not be '
            'uploaded. ${ErrorHandler.map(error, stackTrace: stack).message}',
      );
    }
  }

  /// Creates the job, re-quoting once if the quote expired.
  ///
  /// A quote is valid for 15 minutes. If the customer leaves the confirmation
  /// sheet open for longer, the job insert is rejected with SQLSTATE 22023
  /// ("quote ... has expired"). Re-quote and try again rather than failing.
  Future<CustomerJobSnapshot> _createJobWithFreshQuote({
    String? paymentMethod,
  }) async {
    final quoteId = state.quoteId;
    if (quoteId == null) {
      throw StateError('Cannot create a job without a quote.');
    }
    try {
      return await _repo.createJob(quoteId, paymentMethod: paymentMethod);
    } on PostgrestException catch (error) {
      if (error.code != '22023') rethrow;
      await refreshQuote();
      final freshQuoteId = state.quoteId;
      if (freshQuoteId == null) rethrow;
      return _repo.createJob(freshQuoteId, paymentMethod: paymentMethod);
    }
  }

  /// Explains why dispatch found nobody.
  ///
  /// The server reports the step that emptied the result, so the customer
  /// sees the actual cause instead of a generic "no drivers nearby". Returns
  /// null for states that are normal (a live offer is out, or a scheduled move
  /// is deliberately waiting), so the searching view stays calm.
  String? _noDriverMessage(DispatchResult dispatch) {
    final reason = dispatch.reason?.trim();
    if (reason == null || reason.isEmpty) {
      return 'No verified drivers are nearby right now. We will keep looking.';
    }
    switch (reason) {
      case 'waiting for a driver to respond':
        return null;
      case 'a search round just ran':
        // A round ran moments ago; keep whatever the customer already sees.
        return state.errorMessage;
      case 'no driver was available for this move':
        return _noDriverFoundMessage;
      case 'job is scheduled for later':
        return 'Your move is scheduled for ${state.scheduledLabel}. '
            'We will start looking for a driver 45 minutes before pickup.';
      case 'job is no longer dispatchable':
        return 'This move can no longer be offered to new drivers.';
      case 'no verified drivers are available right now':
        return 'No verified drivers are online right now. We will keep looking.';
      case 'drivers are online but have not shared a recent location':
        return 'Drivers are online but have not shared a recent location yet. '
            'We will keep looking.';
      case 'drivers have no verified vehicle attached':
        return 'The drivers online are still waiting for a vehicle to be '
            'verified. We will keep looking.';
      case _noDriverOfClassReason:
        if (state.alternativeVehicles.isNotEmpty) {
          return 'No online driver has a '
              '${state.vehicleClass?.name ?? 'vehicle of this class'} right '
              'now. You can switch to another vehicle that can carry your '
              'load, or wait for one to come online.';
        }
        return 'No online driver has a vehicle of the class you selected. '
            'Try a different vehicle, or wait for one to come online.';
      case 'every matching driver is already on a job':
        return 'Every matching driver is already on a move. We will keep '
            'looking for a free driver.';
      case 'no matching driver is within the search radius':
        return 'No matching driver is close enough yet. We are widening the '
            'search.';
      case 'no matching driver is free right now':
        return 'No matching driver is free right now. We will keep looking.';
      default:
        return 'No verified drivers are nearby right now. We will keep looking.';
    }
  }

  /// Looks up other vehicle classes the customer could switch to when
  /// dispatch found no online driver with the booked class.
  ///
  /// Only classes that are bookable, can carry the declared cargo and weight,
  /// and have at least one free driver near the pickup are offered.
  Future<void> _updateAlternatives(
    String jobId,
    DispatchResult dispatch,
  ) async {
    final noDriverOfClass =
        dispatch.count == 0 &&
        dispatch.reason?.trim() == _noDriverOfClassReason;
    if (noDriverOfClass && state.vehicleClass == null) {
      // A resumed job starts without the catalogue selection; restore it so
      // the alternatives can be filtered by what the load needs.
      await _restoreCatalogSelection(jobId);
      if (!ref.mounted || state.jobId != jobId) return;
    }
    final current = state.vehicleClass;
    if (!noDriverOfClass || current == null) {
      if (state.alternativeVehicles.isNotEmpty) {
        state = state.copyWith(clearAlternatives: true);
      }
      return;
    }
    try {
      final counts = await _repo.availableVehicleTypes(jobId);
      if (!ref.mounted || state.jobId != jobId) return;
      if (counts.isEmpty) {
        state = state.copyWith(clearAlternatives: true);
        return;
      }
      final catalogue = await ref.read(rideVehicleTypesProvider.future);
      if (!ref.mounted || state.jobId != jobId) return;
      final alternatives = <AlternativeVehicle>[
        for (final vehicle in catalogue)
          if (vehicle.id != current.id &&
              (counts[vehicle.id] ?? 0) > 0 &&
              canVehicleCarryCargo(vehicle, state.cargo, state.parcelWeightKg))
            AlternativeVehicle(
              vehicle: vehicle,
              driverCount: counts[vehicle.id]!,
            ),
      ];
      state = state.copyWith(alternativeVehicles: alternatives);
      state = state.copyWith(errorMessage: _noDriverMessage(dispatch));
    } catch (_) {
      // Suggestions are best-effort; the generic message still applies.
    }
  }

  /// Cancels the unmatched job and books the same move with [vehicle].
  ///
  /// The job is tied to a quote for one vehicle class, so switching means a
  /// new quote and a new job. Nobody accepted the old job, so the server
  /// charges no cancellation fee.
  Future<void> switchVehicleAndRedispatch(VehicleTypeOption vehicle) async {
    if (state.isSubmitting) return;
    final jobId = state.jobId;
    final userId = ref.read(authProvider).currentUser?.id;
    if (jobId == null || userId == null) return;
    if (state.driver != null) return;

    final storedPhotos = state.cargoPhotoPaths;
    state = state.copyWith(isSubmitting: true, clearError: true);
    // Stop listening first so the old job's cancellation does not flip the
    // sheet back to the confirm stage with a "cancelled" message.
    _cleanup();
    try {
      await _repo.cancelJob(
        jobId,
        userId,
        reason: 'Customer switched to a ${vehicle.name}',
      );
    } catch (error, stack) {
      if (!ref.mounted) return;
      _subscribe(jobId);
      _startPolling(jobId);
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: ErrorHandler.map(error, stackTrace: stack).message,
      );
      return;
    }
    if (!ref.mounted) return;
    _quoteGen++;
    _lastAutoDispatch = null;
    // Without the local files (a resumed search), reuse the stored photos.
    _carryOverPhotoPaths = state.parcelPhotoPaths.isEmpty
        ? storedPhotos
        : const <String>[];
    // A pickup time that has already passed while searching means "now" for
    // the new booking; keep only a time that is still ahead.
    final scheduled = state.scheduledAt;
    final keepSchedule =
        scheduled != null &&
        scheduled.isAfter(DateTime.now().add(const Duration(minutes: 5)));
    state = state.copyWith(
      vehicleClass: vehicle,
      isSubmitting: false,
      clearSchedule: !keepSchedule,
      clearQuote: true,
      clearJob: true,
      clearDriver: true,
      clearOtp: true,
      clearError: true,
    );
    await confirmAndFindDriver();
  }

  Future<void> retryDispatch() async {
    final jobId = state.jobId;
    if (jobId == null) {
      await confirmAndFindDriver();
      return;
    }
    state = state.copyWith(
      stage: RideStage.searching,
      isSubmitting: true,
      clearError: true,
    );
    try {
      final result = await _repo.dispatch(jobId);
      _lastAutoDispatch = DateTime.now();
      final message = result.count == 0 ? _noDriverMessage(result) : null;
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: message,
        clearError: message == null,
      );
      unawaited(_updateAlternatives(jobId, result));
      _startPolling(jobId);
    } catch (error, stack) {
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: ErrorHandler.map(error, stackTrace: stack).message,
      );
    }
  }

  /// Used by deep links and history detail to jump straight into a job.
  Future<void> loadJob(String jobId) async {
    _cleanup();
    _lastAutoDispatch = null;
    _otpIssuedFor = null;
    _forgetJobCatalog();
    state = RideState(stage: RideStage.searching, jobId: jobId);
    try {
      final job = await _repo.getJob(jobId);
      if (!ref.mounted || state.jobId != jobId) return;
      if (job == null) {
        state = state.copyWith(errorMessage: 'That move could not be found.');
        return;
      }
      _applyJob(job);
      if (!job.isTerminal) {
        _subscribe(jobId);
        _startPolling(jobId);
      }
    } catch (error, stack) {
      state = state.copyWith(
        errorMessage: ErrorHandler.map(error, stackTrace: stack).message,
      );
    }
  }

  /// Restores an in-flight move when the app starts on the home screen.
  ///
  /// Only runs from a pristine idle state so it never replaces a route the
  /// customer is already editing.
  Future<void> resumeActiveJob() async {
    if (state.stage != RideStage.idle || state.jobId != null) return;
    try {
      final job = await _repo.getActiveJob();
      if (job == null || !ref.mounted) return;
      if (state.stage != RideStage.idle || state.jobId != null) return;
      await loadJob(job.id);
    } catch (_) {
      // Resume is best-effort; a failure leaves the customer on the form.
    }
  }

  /// Uploads pickup/delivery evidence for the current job.
  Future<bool> uploadEvidence({
    required String evidenceType,
    required List<int> bytes,
    required String fileName,
    String? mimeType,
  }) async {
    final jobId = state.jobId;
    if (jobId == null) {
      state = state.copyWith(
        errorMessage: 'No active move to attach proof to.',
      );
      return false;
    }
    try {
      await _repo.uploadJobEvidence(
        jobId: jobId,
        evidenceType: evidenceType,
        bytes: bytes,
        fileName: fileName,
        mimeType: mimeType,
      );
      return true;
    } catch (error, stack) {
      state = state.copyWith(
        errorMessage: ErrorHandler.map(error, stackTrace: stack).message,
      );
      return false;
    }
  }

  /// Sends a photo/file to the driver through the job chat.
  Future<bool> sendChatAttachment({
    required List<int> bytes,
    required String fileName,
    String? mimeType,
    String? caption,
  }) async {
    final jobId = state.jobId;
    if (jobId == null) {
      state = state.copyWith(errorMessage: 'No active move to chat about.');
      return false;
    }
    try {
      await _repo.sendChatAttachment(
        jobId: jobId,
        bytes: bytes,
        fileName: fileName,
        mimeType: mimeType,
        caption: caption,
      );
      return true;
    } catch (error, stack) {
      state = state.copyWith(
        errorMessage: ErrorHandler.map(error, stackTrace: stack).message,
      );
      return false;
    }
  }

  Future<void> cancelSearch() async {
    if (state.isSubmitting) return;
    final jobId = state.jobId;
    final userId = ref.read(authProvider).currentUser?.id;
    if (jobId != null && userId != null) {
      state = state.copyWith(isSubmitting: true, clearError: true);
      try {
        await _repo.cancelJob(
          jobId,
          userId,
          reason: state.driver != null
              ? 'Customer cancelled after a driver was assigned'
              : 'Customer cancelled while searching',
        );
      } catch (error, stack) {
        if (!ref.mounted) return;
        state = state.copyWith(
          isSubmitting: false,
          errorMessage: ErrorHandler.map(error, stackTrace: stack).message,
        );
        return;
      }
    }
    _cleanup();
    _quoteGen++;
    _forgetJobCatalog();
    // Wipe the whole request form (route, vehicle, parcel, schedule, quote)
    // so the customer can start a brand-new request from scratch.
    state = RideState();
  }

  /// Confirms delivery on the server. The driver's completion then follows.
  Future<void> confirmDelivery() async {
    final jobId = state.jobId;
    if (jobId == null ||
        state.isSubmitting ||
        state.jobStatus != 'arrived_destination') {
      return;
    }
    state = state.copyWith(isSubmitting: true, clearError: true);
    try {
      await _repo.confirmDelivery(jobId);
      if (!ref.mounted || state.jobId != jobId) return;
      await _refreshJob(jobId);
      if (!ref.mounted || state.jobId != jobId) return;
      state = state.copyWith(isSubmitting: false);
    } catch (error, stack) {
      if (!ref.mounted || state.jobId != jobId) return;
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: ErrorHandler.map(error, stackTrace: stack).message,
      );
    }
  }

  void complete() {
    _cleanup();
    state = state.copyWith(stage: RideStage.done);
  }

  void reset() {
    _cleanup();
    _quoteGen++;
    _vehiclePickedByUser = false;
    _availability = null;
    _forgetJobCatalog();
    state = RideState();
  }

  void _forgetJobCatalog() {
    _jobVehicleTypeId = null;
    _jobCargoTypeId = null;
    _jobPaymentMethod = null;
    _catalogRestore = null;
    _catalogRestoreFor = null;
    _carryOverPhotoPaths = const <String>[];
  }

  /// Rebuilds the vehicle, cargo and payment selection of a resumed job from
  /// the catalogue, so a search restored after an app restart behaves like
  /// one started in this session (load checks, vehicle alternatives).
  ///
  /// Runs once per job; concurrent callers share the same lookup.
  Future<void> _restoreCatalogSelection(String jobId) {
    if (_catalogRestoreFor == jobId && _catalogRestore != null) {
      return _catalogRestore!;
    }
    _catalogRestoreFor = jobId;
    return _catalogRestore = () async {
      final vehicleId = _jobVehicleTypeId;
      final cargoId = _jobCargoTypeId;
      final paymentId = _jobPaymentMethod;
      try {
        final vehicles = vehicleId != null && state.vehicleClass == null
            ? await ref.read(rideVehicleTypesProvider.future)
            : const <VehicleTypeOption>[];
        final cargoTypes = cargoId != null && state.cargo == null
            ? await ref.read(rideCargoTypesProvider.future)
            : const <CargoTypeOption>[];
        if (!ref.mounted || state.jobId != jobId) return;
        VehicleTypeOption? vehicle;
        for (final v in vehicles) {
          if (v.id == vehicleId) vehicle = v;
        }
        CargoTypeOption? cargo;
        for (final c in cargoTypes) {
          if (c.id == cargoId) cargo = c;
        }
        MockPaymentMethod? payment;
        for (final m in mockPaymentMethods) {
          if (m.id == paymentId) payment = m;
        }
        state = state.copyWith(
          vehicleClass: state.vehicleClass ?? vehicle,
          cargo: state.cargo ?? cargo,
          paymentMethod: payment,
        );
      } catch (_) {
        // Best-effort: allow a later call to try again.
        if (_catalogRestoreFor == jobId) {
          _catalogRestore = null;
          _catalogRestoreFor = null;
        }
      }
    }();
  }

  void backToRoute() {
    _cleanup();
    _quoteGen++;
    state = state.copyWith(
      stage: RideStage.vehicle,
      clearDriver: true,
      clearJob: true,
      clearOtp: true,
      clearError: true,
    );
  }

  void driverFound(Driver driver) {
    state = state.copyWith(stage: RideStage.tracking, driver: driver);
  }

  void _subscribe(String jobId) {
    _channel?.unsubscribe();
    final client = ref.read(supabaseProvider);
    _channel = client
        .channel('customer-job-$jobId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'jobs',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: jobId,
          ),
          callback: (_) => unawaited(_refreshJob(jobId)),
        )
        .subscribe();
  }

  /// Statuses in which the driver broadcasts a live position.
  static const _liveStatuses = <String?>{
    'accepted',
    'heading_to_pickup',
    'arrived',
    'cargo_verified',
    'loading',
    'in_transit',
    'arrived_destination',
  };

  String? _liveChannelFor;
  DateTime? _lastLiveFixAt;

  bool get _liveFixIsRecent {
    final at = _lastLiveFixAt;
    return at != null &&
        DateTime.now().difference(at) < const Duration(seconds: 60);
  }

  /// Joins (or leaves) the job's private live-location channel.
  ///
  /// The driver broadcasts every few seconds; the database only authorises
  /// the channel (RLS on realtime.messages), so live tracking costs no row
  /// writes. The 8 s job poll stays as the fallback.
  void _syncLiveChannel(String jobId, String? status) {
    final live = _liveStatuses.contains(status);
    if (live && _liveChannelFor == jobId) return;
    if (!live && _liveChannelFor == null) return;
    final client = ref.read(supabaseProvider);
    final previous = _locationChannel;
    _locationChannel = null;
    _liveChannelFor = null;
    _lastLiveFixAt = null;
    if (previous != null) unawaited(client.removeChannel(previous));
    if (!live) return;
    _liveChannelFor = jobId;
    _locationChannel = client
        .channel(
          'job-location:$jobId',
          opts: const RealtimeChannelConfig(private: true),
        )
        .onBroadcast(
          event: 'position',
          callback: (payload) => _onLiveFix(jobId, payload),
        )
        .subscribe();
  }

  void _onLiveFix(String jobId, Map<String, dynamic> payload) {
    if (!ref.mounted || state.jobId != jobId) return;
    // Broadcast payloads arrive wrapped under 'payload' on some clients.
    final data = payload['payload'] is Map
        ? (payload['payload'] as Map).cast<String, dynamic>()
        : payload;
    final lat = (data['lat'] as num?)?.toDouble();
    final lng = (data['lng'] as num?)?.toDouble();
    if (lat == null || lng == null) return;
    _lastLiveFixAt = DateTime.now();
    state = state.copyWith(
      driverLatitude: lat,
      driverLongitude: lng,
      driverHeading: (data['heading'] as num?)?.toDouble(),
      driverLocationFresh: true,
      driverLocationUpdatedAt: DateTime.now(),
    );
    unawaited(_computeTrackingRoute());
  }

  void _startPolling(String jobId) {
    _poll?.cancel();
    _poll = Timer.periodic(
      const Duration(seconds: 8),
      (_) => unawaited(_refreshJob(jobId)),
    );
  }

  Future<void> _refreshJob(String jobId) async {
    if (state.jobId != jobId) return;
    final generation = ++_refreshGeneration;
    try {
      final job = await _repo.getJob(jobId);
      if (ref.mounted &&
          generation == _refreshGeneration &&
          job != null &&
          state.jobId == jobId) {
        _applyJob(job);
        _maybeAutoRedispatch(job);
      }
    } catch (_) {
      // Realtime/poll failures are non-fatal; the next tick retries.
    }
  }

  /// Rebuilds a map endpoint from stored job coordinates, or returns
  /// [current] when it already points at the same place.
  ///
  /// Jobs only persist an address and a coordinate, not the provider metadata
  /// (place id, structured address). Reusing [current] while it matches keeps
  /// that metadata and avoids refitting the map on every poll.
  RidePlace? _restoredPlace({
    required RidePlace? current,
    required String jobId,
    required String suffix,
    required String fallbackName,
    required String address,
    required double? latitude,
    required double? longitude,
  }) {
    if (latitude == null || longitude == null) return current;
    if (current != null &&
        (current.latitude - latitude).abs() <= 1e-6 &&
        (current.longitude - longitude).abs() <= 1e-6) {
      return current;
    }
    final trimmed = address.trim();
    return RidePlace(
      id: 'job-$jobId-$suffix',
      name: trimmed.isNotEmpty ? trimmed : fallbackName,
      district: '',
      latitude: latitude,
      longitude: longitude,
      formattedAddress: trimmed.isNotEmpty ? trimmed : null,
      source: current?.source ?? RidePlaceSource.map,
    );
  }

  void _applyJob(CustomerJobSnapshot job) {
    final status = job.status;
    if (status == 'cancelled') {
      _cleanup();
      state = state.copyWith(
        stage: RideStage.confirm,
        jobStatus: status,
        cancellationReason: job.cancellationReason,
        cancellationFee: job.cancellationFee,
        errorMessage: _cancelledMessage(job.cancellationReason),
        clearDriver: true,
      );
      return;
    }

    Driver? driver;
    if (job.driverId != null) {
      driver = Driver(
        id: job.driverId!,
        name: job.driverName ?? 'SafeShift driver',
        vehicleClass: job.vehicleType ?? state.vehicleClass?.name ?? 'Vehicle',
        rating: job.driverRating,
        phone: job.driverPhone ?? '',
        completedTrips: 0,
        verified: job.driverVerified,
      );
    }

    final completed = status == 'completed';
    final scheduledLater =
        driver == null &&
        job.scheduledAt != null &&
        job.scheduledAt!.isAfter(
          DateTime.now().add(const Duration(minutes: 45)),
        );

    final RideStage stage;
    if (completed) {
      stage = RideStage.done;
    } else if (driver != null) {
      stage = RideStage.tracking;
    } else {
      stage = RideStage.searching;
    }

    // The previous driver handed the job back (or the server released them)
    // and the move is searching again.
    final driverReleased =
        state.driver != null &&
        driver == null &&
        !completed &&
        (status == 'requested' || status == 'quoted' || status == 'matched');
    if (driverReleased) _lastAutoDispatch = DateTime.now();

    String? message = state.errorMessage;
    if (driver != null || completed) {
      message = null;
    } else if (driverReleased) {
      message =
          'Your driver could not make it. We are finding you another driver '
          'at the same price.';
    } else if (scheduledLater) {
      message =
          'Your move is scheduled for ${_formatSchedule(job.scheduledAt!)}. '
          'We will start looking for a driver 45 minutes before pickup.';
    }

    // Restore the map endpoints when opening an existing job (cold start or a
    // deep link). Keep the richer place the customer already picked while it
    // still matches the job, so a polling refresh does not reset the camera.
    final pickupPlace = _restoredPlace(
      current: state.pickup,
      jobId: job.id,
      suffix: 'pickup',
      fallbackName: 'Pickup',
      address: job.pickupAddress,
      latitude: job.pickupLat,
      longitude: job.pickupLng,
    );
    final destinationPlace = _restoredPlace(
      current: state.destination,
      jobId: job.id,
      suffix: 'dropoff',
      fallbackName: 'Drop-off',
      address: job.destinationAddress,
      latitude: job.destinationLat,
      longitude: job.destinationLng,
    );

    _syncLiveChannel(job.id, status);
    final liveRecent = _liveFixIsRecent && _liveStatuses.contains(status);
    if (state.jobStatus != status) {
      _routeGen++;
    }
    state = state.copyWith(
      stage: stage,
      jobStatus: status,
      isRouting: state.jobStatus != status ? false : null,
      clearOtp: status != 'arrived_destination' && status != 'in_transit',
      routePoints: state.jobStatus != status ? const <LatLng>[] : null,
      pickup: pickupPlace,
      destination: destinationPlace,
      pickupAddress: job.pickupAddress,
      destinationAddress: job.destinationAddress,
      scheduledAt: job.customerPickupTime,
      clearSchedule: job.customerPickupTime == null,
      acceptedAt: job.acceptedAt,
      dispatchAttempts: job.dispatchAttempts,
      parcelDescription: job.cargoDescription,
      parcelWeightKg: job.cargoWeightKg,
      parcelValueTzs: job.declaredValueTzs?.round(),
      cargoPhotoPaths: job.cargoPhotoPaths,
      driver: driver,
      clearDriver: driver == null,
      clearDriverLocation:
          job.isDelivered ||
          status == 'disputed' ||
          (!liveRecent && (job.driverLat == null || job.driverLng == null)),
      distanceKm: job.distanceKm > 0 ? job.distanceKm : null,
      quoteTotal: job.amount > 0 ? job.amount : null,
      // A live broadcast fix is newer than the polled 30 s history point.
      driverLatitude: liveRecent ? null : job.driverLat,
      driverLongitude: liveRecent ? null : job.driverLng,
      driverLocationFresh: liveRecent ? true : job.driverLocationFresh,
      driverLocationUpdatedAt: liveRecent ? null : job.driverLocationUpdatedAt,
      errorMessage: message,
      clearError: message == null,
    );

    _jobVehicleTypeId = job.vehicleTypeId ?? _jobVehicleTypeId;
    _jobCargoTypeId = job.cargoTypeId ?? _jobCargoTypeId;
    _jobPaymentMethod = job.paymentMethod ?? _jobPaymentMethod;
    if ((state.vehicleClass == null && _jobVehicleTypeId != null) ||
        (state.cargo == null && _jobCargoTypeId != null)) {
      unawaited(_restoreCatalogSelection(job.id));
    }

    if (status == 'arrived') {
      if (_pickupWaitFor != job.id) {
        _pickupWaitFor = job.id;
        unawaited(_loadPickupWait(job.id));
      }
    } else if (state.pickupFreeWaitEndsAt != null || _pickupWaitFor != null) {
      _pickupWaitFor = null;
      state = state.copyWith(clearPickupWait: true);
    }

    if (_recipientLoadedFor != job.id) {
      _recipientLoadedFor = job.id;
      unawaited(_loadRecipient(job.id));
    }

    // With a separate recipient the server texts the code to them when the
    // goods leave the pickup; issuing here would replace that code. The
    // customer can still resend it from the tracking card.
    if (status == 'arrived_destination' &&
        !state.hasRecipient &&
        state.deliveryOtp == null &&
        _otpIssuedFor != job.id) {
      _otpIssuedFor = job.id;
      unawaited(_issueOtp(job.id));
    }
    if (completed) {
      _cleanup();
    } else {
      unawaited(_computeTrackingRoute());
    }
  }

  /// Runs the client-side dispatch fallback while the customer is searching.
  ///
  /// The database worker is the primary re-dispatch loop; this exists so a
  /// missing or paused pg_cron does not strand a move. It respects the
  /// server's `last_dispatched_at` cadence and the six-attempt cap so it never
  /// races the worker or burns the customer's search.
  void _maybeAutoRedispatch(CustomerJobSnapshot job) {
    if (state.stage != RideStage.searching) return;
    if (state.jobId == null || state.jobId != job.id) return;
    if (job.driverId != null || job.isTerminal || job.isDelivered) return;
    if (job.dispatchAttempts >= 6) return;
    final scheduled = job.scheduledAt;
    if (scheduled != null &&
        scheduled.isAfter(DateTime.now().add(const Duration(minutes: 45)))) {
      return;
    }
    final now = DateTime.now();
    final last = [?_lastAutoDispatch, ?job.lastDispatchedAt].fold<DateTime?>(
      null,
      (latest, value) {
        if (latest == null || value.isAfter(latest)) return value;
        return latest;
      },
    );
    if (last != null && now.difference(last) < _autoDispatchCooldown) return;
    _lastAutoDispatch = now;
    unawaited(_autoDispatch(job.id));
  }

  Future<void> _autoDispatch(String jobId) async {
    if (!ref.mounted || state.jobId != jobId) return;
    if (state.stage != RideStage.searching) return;
    try {
      final result = await _repo.dispatch(jobId);
      if (!ref.mounted || state.jobId != jobId) return;
      final message = result.count == 0 ? _noDriverMessage(result) : null;
      state = state.copyWith(
        errorMessage: message,
        clearError: message == null,
      );
      unawaited(_updateAlternatives(jobId, result));
    } catch (_) {
      // Silent retry; the next poll tick tries again.
    }
  }

  static const _noDriverFoundMessage =
      'We could not find a driver for this move. You were not charged. '
      'Confirm again to search once more, or choose another vehicle.';

  static String _cancelledMessage(String? reason) {
    final trimmed = reason?.trim() ?? '';
    if (trimmed.isEmpty) return 'This move was cancelled.';
    if (trimmed.toLowerCase().startsWith('no driver was available')) {
      return _noDriverFoundMessage;
    }
    return 'This move was cancelled: $trimmed';
  }

  static String _formatSchedule(DateTime at) {
    final local = at.toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(local.year, local.month, local.day);
    final days = day.difference(today).inDays;
    final time = DateFormat('h:mm a').format(local);
    if (days == 0) return 'today at $time';
    if (days == 1) return 'tomorrow at $time';
    return '${DateFormat('EEE d MMM').format(local)} at $time';
  }

  Future<void> _loadRecipient(String jobId) async {
    try {
      final recipient = await _repo.getRecipient(jobId);
      if (!ref.mounted || state.jobId != jobId) return;
      final phone = recipient.phone;
      if (phone == null || phone.isEmpty) return;
      state = state.copyWith(
        recipientName: recipient.name,
        recipientPhone: phone,
      );
    } catch (_) {
      _recipientLoadedFor = null;
    }
  }

  /// Issues a new delivery code: shown here and texted to the recipient.
  Future<void> resendDeliveryCode() async {
    final jobId = state.jobId;
    if (jobId == null || state.isSubmitting) return;
    state = state.copyWith(isSubmitting: true, clearError: true);
    try {
      final code = await _repo.issueDeliveryOtp(jobId);
      if (!ref.mounted || state.jobId != jobId) return;
      _otpIssuedFor = jobId;
      state = state.copyWith(isSubmitting: false, deliveryOtp: code);
    } catch (error, stack) {
      if (!ref.mounted) return;
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: ErrorHandler.map(error, stackTrace: stack).message,
      );
    }
  }

  Future<void> _loadPickupWait(String jobId) async {
    try {
      final endsAt = await _repo.pickupFreeWaitEndsAt(jobId);
      if (!ref.mounted || state.jobId != jobId) return;
      state = state.copyWith(
        pickupFreeWaitEndsAt: endsAt,
        clearPickupWait: endsAt == null,
      );
    } catch (_) {
      // The countdown is informational; retry on the next status change.
      _pickupWaitFor = null;
    }
  }

  /// What cancelling right now would cost. Read-only.
  Future<CancellationPreview?> cancellationPreview() async {
    final jobId = state.jobId;
    if (jobId == null) return null;
    return _repo.cancellationPreview(jobId);
  }

  Future<void> _issueOtp(String jobId) async {
    try {
      final code = await _repo.issueDeliveryOtp(jobId);
      if (ref.mounted &&
          state.jobId == jobId &&
          state.jobStatus == 'arrived_destination') {
        state = state.copyWith(deliveryOtp: code);
      }
    } catch (_) {
      _otpIssuedFor = null;
    }
  }

  void _cleanup() {
    _routeGen++;
    _refreshGeneration++;
    _routeTimer?.cancel();
    _routeTimer = null;
    _poll?.cancel();
    _poll = null;
    _channel?.unsubscribe();
    _channel = null;
    final liveChannel = _locationChannel;
    _locationChannel = null;
    _liveChannelFor = null;
    _lastLiveFixAt = null;
    if (liveChannel != null) unawaited(liveChannel.unsubscribe());
    _trackingRoute = const <LatLng>[];
    _trackingTarget = null;
  }
}

final rideProvider = NotifierProvider<RideNotifier, RideState>(
  RideNotifier.new,
);

final rideVehicleTypesProvider = FutureProvider<List<VehicleTypeOption>>((ref) {
  // Hide vehicles that have no live pricing plan. Offering them would make
  // every quote for that vehicle fail with a server-side P0002.
  return CatalogRepository(ref.watch(supabaseProvider))
      .getQuotableVehicleTypes();
});

/// Pickup point rounded to ~100 m so small GPS changes reuse the same query.
typedef PickupPoint = ({double lat, double lng});

PickupPoint pickupPointOf(RidePlace place) => (
  lat: (place.latitude * 1000).round() / 1000,
  lng: (place.longitude * 1000).round() / 1000,
);

/// Vehicle availability near a pickup point, refreshed every 25 s while the
/// vehicle picker watches it. Resolves to null when it cannot be loaded, so
/// the picker falls back to showing every vehicle as bookable.
final vehicleAvailabilityProvider = FutureProvider.autoDispose
    .family<Map<String, VehicleAvailability>?, PickupPoint>((ref, point) async {
      final timer = Timer(const Duration(seconds: 25), ref.invalidateSelf);
      ref.onDispose(timer.cancel);
      try {
        return await RideRepository(ref.watch(supabaseProvider))
            .vehicleAvailabilityNear(lat: point.lat, lng: point.lng);
      } catch (_) {
        return null;
      }
    });

final rideCargoTypesProvider = FutureProvider<List<CargoTypeOption>>((ref) {
  return CatalogRepository(ref.watch(supabaseProvider)).getCargoTypes();
});

final rideSavedPlacesProvider = FutureProvider<List<RidePlace>>((ref) async {
  final user = ref.watch(authProvider).currentUser;
  if (user == null) return const <RidePlace>[];
  return ref.watch(placesRepositoryProvider).getSavedPlaces(user.id);
});

/// Whether [vehicle] can carry [cargo] with the optional [weightKg].
///
/// Cargo compatibility comes from the catalogue (`allowed`/`prohibited`
/// vehicle type codes); capacity is checked only when a weight is known.
bool canVehicleCarryCargo(
  VehicleTypeOption vehicle,
  CargoTypeOption? cargo,
  double? weightKg,
) {
  if (cargo != null) {
    if (cargo.allowedVehicleTypeCodes.isNotEmpty &&
        !cargo.allowedVehicleTypeCodes.contains(vehicle.code)) {
      return false;
    }
    if (cargo.prohibitedVehicleTypeCodes.contains(vehicle.code)) {
      return false;
    }
  }
  if (weightKg != null &&
      weightKg > 0 &&
      vehicle.capacityKgMax > 0 &&
      weightKg > vehicle.capacityKgMax) {
    return false;
  }
  return true;
}
