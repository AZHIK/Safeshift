import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:safeshift_shared/safeshift_shared.dart'
    show
        MarkerGlide,
        SafeShiftThemeContext,
        VehicleMarkers,
        framingBounds,
        navigationCamera,
        safeShiftDarkMapStyle,
        vehicleMarkerKindFor;

import '../../data/driver_route_service.dart';
import '../../domain/entities/driver_job.dart';
import '../../domain/entities/driver_status.dart';
import '../../../vehicle/providers/vehicle_provider.dart';
import '../../providers/home_provider.dart';

const _defaultCentre = LatLng(-6.79, 39.25);

/// Google Maps view for the driver screen.
///
/// While driving (heading to pickup, in transit) the camera follows the
/// driver, turned to the direction of travel, like a navigation app. Touching
/// the map hands control to the driver and shows a Re-centre button. In the
/// other stages the camera frames the job's points once per stage.
///
/// The polyline is the remaining road route from [liveRouteProvider], trimmed
/// on the device as the driver advances.
///
/// [mapPadding] marks the area covered by the bottom sheet; the camera fits
/// and centres inside the rest, so the route is never hidden under it.
class MapPlaceholder extends ConsumerStatefulWidget {
  const MapPlaceholder({
    super.key,
    required this.status,
    this.job,
    this.mapPadding = EdgeInsets.zero,
  });

  final DriverStatus status;
  final DriverJob? job;
  final EdgeInsets mapPadding;

  @override
  ConsumerState<MapPlaceholder> createState() => _MapPlaceholderState();
}

class _MapPlaceholderState extends ConsumerState<MapPlaceholder>
    with SingleTickerProviderStateMixin {
  GoogleMapController? _controller;
  bool _following = true;
  DateTime? _lastFollowAt;
  BitmapDescriptor? _vehicleIcon;
  String? _vehicleIconKey;
  bool _ready = false;
  Timer? _refitAfterPadding;

  /// Glides the driver's own vehicle between GPS fixes.
  late final MarkerGlide _glide = MarkerGlide(
    vsync: this,
    onFrame: () {
      if (mounted && _ready) setState(() {});
    },
  );

  bool get _driving =>
      widget.status == DriverStatus.headingToPickup ||
      widget.status == DriverStatus.inTransit;

  @override
  void initState() {
    super.initState();
    final home = ref.read(homeProvider);
    if (home.driverLat != null && home.driverLng != null) {
      _glide.update(
        (lat: home.driverLat!, lng: home.driverLng!),
        heading: home.driverHeading,
        animate: false,
      );
    }
    _ready = true;
    WidgetsBinding.instance.addPostFrameCallback((_) => _frame());
  }

  /// Top-down vehicle matching the driver's own vehicle type.
  void _loadVehicleIcon(String? vehicleTypeCode) {
    final kind = vehicleMarkerKindFor(vehicleTypeCode);
    final color = context.colors.primary;
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final key = '${kind.name}|${color.toARGB32()}|$dpr';
    if (key == _vehicleIconKey) return;
    _vehicleIconKey = key;
    unawaited(
      VehicleMarkers.render(
        kind: kind,
        color: color,
        devicePixelRatio: dpr,
      ).then((image) {
        if (!mounted || _vehicleIconKey != key) return;
        setState(
          () => _vehicleIcon = BitmapDescriptor.bytes(
            image.png,
            width: image.width,
            height: image.height,
          ),
        );
      }, onError: (_) {}),
    );
  }

  @override
  void didUpdateWidget(covariant MapPlaceholder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.status != widget.status ||
        oldWidget.job?.id != widget.job?.id) {
      // A new stage starts in follow mode again.
      _following = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _frame());
    } else if (oldWidget.mapPadding != widget.mapPadding && _following) {
      // The sheet moved: re-frame once the map has applied the new padding.
      _refitAfterPadding?.cancel();
      _refitAfterPadding = Timer(const Duration(milliseconds: 120), () {
        if (mounted && _following) _frame();
      });
    }
  }

  LatLng? _driverPosition() {
    final home = ref.read(homeProvider);
    if (home.driverLat != null && home.driverLng != null) {
      return LatLng(home.driverLat!, home.driverLng!);
    }
    return null;
  }

  /// Positions the camera for the current stage.
  void _frame() {
    if (!mounted || _controller == null) return;
    if (_driving) {
      _follow(force: true);
    } else {
      _fitPoints();
    }
  }

  void _follow({bool force = false}) {
    final controller = _controller;
    final driver = _driverPosition();
    if (controller == null || driver == null || !_following || !_driving) {
      return;
    }
    final now = DateTime.now();
    final last = _lastFollowAt;
    if (!force && last != null && now.difference(last).inMilliseconds < 900) {
      return;
    }
    _lastFollowAt = now;
    final home = ref.read(homeProvider);
    final heading = home.driverHeading ?? 0;
    // Like Bolt/Uber navigation: zoom by speed and keep the car in the lower
    // part of the visible map so the road ahead fills the screen.
    final padding = widget.mapPadding;
    final visibleHeight =
        MediaQuery.sizeOf(context).height - padding.top - padding.bottom;
    final camera = navigationCamera(
      vehicle: (lat: driver.latitude, lng: driver.longitude),
      heading: heading,
      speedKmh: home.driverSpeedKmh,
      visibleHeightPx: visibleHeight,
    );
    unawaited(
      controller.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: LatLng(camera.target.lat, camera.target.lng),
            zoom: camera.zoom,
            bearing: heading,
            tilt: 45,
          ),
        ),
      ),
    );
  }

  void _fitPoints() {
    final job = widget.job;
    final points = <LatLng>[];
    final driver = _driverPosition();
    if (driver != null) points.add(driver);
    // The whole road route, not just its ends: a winding road can leave the
    // box spanned by pickup and drop-off.
    points.addAll(ref.read(liveRouteProvider)?.points ?? const <LatLng>[]);
    if (job?.pickupLat != null && job?.pickupLng != null) {
      points.add(LatLng(job!.pickupLat!, job.pickupLng!));
    }
    if (job?.destinationLat != null && job?.destinationLng != null) {
      points.add(LatLng(job!.destinationLat!, job.destinationLng!));
    }
    final controller = _controller;
    if (points.isEmpty || controller == null) return;
    // At least ~1.5 km across, so a short trip still shows its streets.
    final bounds = framingBounds(
      points.map((p) => (lat: p.latitude, lng: p.longitude)),
    );
    if (bounds == null) return;
    unawaited(
      controller.animateCamera(
        CameraUpdate.newLatLngBounds(
          LatLngBounds(
            southwest: LatLng(bounds.south, bounds.west),
            northeast: LatLng(bounds.north, bounds.east),
          ),
          56,
        ),
      ),
    );
  }

  void _recentre() {
    setState(() => _following = true);
    if (_driving) {
      _follow(force: true);
    } else {
      _fitPoints();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Re-frame when the road route first arrives (or changes leg) so it is
    // fully in view outside driving mode.
    ref.listen(liveRouteProvider.select((r) => r?.points.isNotEmpty ?? false), (
      previous,
      hasRoute,
    ) {
      if (hasRoute && previous != true && _following && !_driving) {
        _fitPoints();
      }
    });
    // Follow each accepted GPS fix while in driving mode.
    ref.listen(
      homeProvider.select((h) => (h.driverLat, h.driverLng, h.driverHeading)),
      (_, next) {
        final (lat, lng, heading) = next;
        if (lat != null && lng != null) {
          _glide.update((lat: lat, lng: lng), heading: heading);
        }
        _follow();
      },
    );
    final vehicleCode = ref.watch(
      vehicleStateProvider.select((v) => v.value?.vehicleTypeCode),
    );
    _loadVehicleIcon(vehicleCode);
    final home = ref.watch(homeProvider);
    final route = ref.watch(liveRouteProvider);
    final job = widget.job;
    final driver = home.driverLat != null && home.driverLng != null
        ? LatLng(home.driverLat!, home.driverLng!)
        : null;
    final pickup = job != null && job.pickupLat != null && job.pickupLng != null
        ? LatLng(job.pickupLat!, job.pickupLng!)
        : null;
    final destination =
        job != null && job.destinationLat != null && job.destinationLng != null
        ? LatLng(job.destinationLat!, job.destinationLng!)
        : null;

    final markers = <Marker>{
      if (pickup != null && widget.status != DriverStatus.inTransit)
        Marker(
          markerId: const MarkerId('pickup'),
          position: pickup,
          infoWindow: const InfoWindow(title: 'Pickup'),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueGreen,
          ),
        ),
      if (destination != null)
        Marker(
          markerId: const MarkerId('dropoff'),
          position: destination,
          infoWindow: const InfoWindow(title: 'Drop-off'),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        ),
      if (_glide.position != null)
        Marker(
          markerId: const MarkerId('driver'),
          position: LatLng(_glide.position!.lat, _glide.position!.lng),
          icon:
              _vehicleIcon ??
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
          rotation: _vehicleIcon == null ? 0 : _glide.bearing,
          flat: _vehicleIcon != null,
          anchor: _vehicleIcon == null
              ? const Offset(0.5, 1)
              : const Offset(0.5, 0.5),
          zIndexInt: 2,
        ),
    };

    final routePoints = route?.points ?? const <LatLng>[];
    final shown = _glide.position;
    final linePoints = _driving && shown != null && routePoints.length > 1
        ? <LatLng>[LatLng(shown.lat, shown.lng), ...routePoints.skip(1)]
        : routePoints;
    final polylines = <Polyline>{
      if (linePoints.length > 1)
        Polyline(
          polylineId: const PolylineId('active-leg'),
          points: linePoints,
          color: context.colors.primary,
          width: 6,
        ),
    };

    final cameraTarget = driver ?? pickup ?? destination ?? _defaultCentre;
    return Stack(
      children: [
        Positioned.fill(
          child: Listener(
            // Any touch hands the camera to the driver until Re-centre.
            onPointerDown: (_) {
              if (_following) setState(() => _following = false);
            },
            child: GoogleMap(
              style: Theme.of(context).brightness == Brightness.dark
                  ? safeShiftDarkMapStyle
                  : null,
              onMapCreated: (controller) {
                _controller = controller;
                _frame();
              },
              initialCameraPosition: CameraPosition(
                target: cameraTarget,
                zoom: 14,
              ),
              markers: markers,
              polylines: polylines,
              mapType: MapType.normal,
              // The app draws its own driver marker from GPS.
              myLocationEnabled: false,
              myLocationButtonEnabled: false,
              compassEnabled: false,
              padding: widget.mapPadding,
            ),
          ),
        ),
        if (!_following)
          Positioned(
            right: 16,
            top: MediaQuery.paddingOf(context).top + 72,
            child: FloatingActionButton.small(
              heroTag: 'driver-map-recentre',
              tooltip: 'Re-centre',
              onPressed: _recentre,
              child: const Icon(Icons.my_location_rounded),
            ),
          ),
      ],
    );
  }

  @override
  void dispose() {
    _refitAfterPadding?.cancel();
    _glide.dispose();
    _controller?.dispose();
    super.dispose();
  }
}
