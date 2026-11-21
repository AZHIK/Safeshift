import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:safeshift_shared/safeshift_shared.dart'
    show
        MarkerGlide,
        SafeShiftThemeContext,
        VehicleMarkers,
        framingBounds,
        safeShiftDarkMapStyle,
        vehicleMarkerKindFor;

import '../../providers/ride_provider.dart';

/// Google Maps integration for the customer ride screen.
///
/// Behaves like the big ride apps:
/// * the driver marker glides between live updates and turns with the road
///   instead of jumping every few seconds;
/// * the camera frames the trip once per stage, then only re-frames when the
///   driver nears the edge of the view;
/// * as soon as the customer touches the map the camera is theirs, until they
///   tap Re-centre;
/// * [mapPadding] marks the parts covered by the sheet and top bar, so the
///   route is always framed in the visible part of the map.
class ShinyMapView extends StatefulWidget {
  const ShinyMapView({
    super.key,
    required this.state,
    this.mapPadding = EdgeInsets.zero,
  });

  final RideState state;

  /// Screen area hidden by overlays (top bar, bottom sheet).
  final EdgeInsets mapPadding;

  @override
  State<ShinyMapView> createState() => ShinyMapViewState();
}

class ShinyMapViewState extends State<ShinyMapView>
    with SingleTickerProviderStateMixin {
  GoogleMapController? _controller;
  bool _following = true;
  String? _framedFor;
  DateTime? _lastEdgeCheck;
  BitmapDescriptor? _driverIcon;
  String? _driverIconKey;
  Timer? _refitAfterPadding;

  /// Height of the map view, for the covered fraction in edge checks.
  double _mapHeight = 0;

  /// Glides the driver's vehicle between live fixes.
  late final MarkerGlide _glide = MarkerGlide(
    vsync: this,
    onFrame: () {
      if (mounted && _ready) setState(() {});
    },
  );

  static const _defaultCenter = LatLng(-6.7924, 39.2083); // Dar es Salaam

  /// Centers the map on a fresh device location when the customer taps the
  /// my-location control. That hands the camera to the customer.
  Future<void> moveTo(double latitude, double longitude) async {
    final controller = _controller;
    if (controller == null) return;
    setState(() => _following = false);
    try {
      await controller.animateCamera(
        CameraUpdate.newLatLngZoom(LatLng(latitude, longitude), 15.5),
      );
    } catch (_) {
      // Map not ready or the view was disposed.
    }
  }

  @override
  void initState() {
    super.initState();
    _takeDriverFix(widget.state, animate: false);
    _ready = true;
  }

  /// Redraws from the glide start after initState (build reads the position).
  bool _ready = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadDriverIcon();
  }

  /// Top-down vehicle matching the booked vehicle type, rendered once and
  /// cached app-wide.
  void _loadDriverIcon() {
    final kind = vehicleMarkerKindFor(
      widget.state.vehicleClass?.code ?? widget.state.driver?.vehicleClass,
    );
    final color = context.colors.primary;
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final key = '${kind.name}|${color.toARGB32()}|$dpr';
    if (key == _driverIconKey) return;
    _driverIconKey = key;
    unawaited(
      VehicleMarkers.render(
        kind: kind,
        color: color,
        devicePixelRatio: dpr,
      ).then((image) {
        if (!mounted || _driverIconKey != key) return;
        setState(
          () => _driverIcon = BitmapDescriptor.bytes(
            image.png,
            width: image.width,
            height: image.height,
          ),
        );
      }, onError: (_) {}),
    );
  }

  @override
  void didUpdateWidget(covariant ShinyMapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final old = oldWidget.state;
    final now = widget.state;
    if (old.driverLatitude != now.driverLatitude ||
        old.driverLongitude != now.driverLongitude ||
        old.driverHeading != now.driverHeading) {
      _takeDriverFix(now, animate: true);
    }
    if (old.vehicleClass?.code != now.vehicleClass?.code ||
        old.driver?.vehicleClass != now.driver?.vehicleClass) {
      _loadDriverIcon();
    }
    if (oldWidget.mapPadding != widget.mapPadding) {
      _onPaddingChanged();
    } else {
      _maybeFrame();
    }
  }

  /// The sheet moved: re-frame the route into the new visible area once the
  /// map has applied the padding (it is sent to the platform view on build).
  void _onPaddingChanged() {
    _refitAfterPadding?.cancel();
    if (!_following) return;
    _refitAfterPadding = Timer(const Duration(milliseconds: 120), () {
      if (!mounted || !_following) return;
      _framedFor = null;
      _maybeFrame();
    });
  }

  // ---------------------------------------------------------------------------
  // Driver marker animation
  // ---------------------------------------------------------------------------

  void _takeDriverFix(RideState state, {required bool animate}) {
    final lat = state.driverLatitude;
    final lng = state.driverLongitude;
    if (lat == null || lng == null) {
      if (_glide.position != null) _glide.clear();
      return;
    }
    _glide.update(
      (lat: lat, lng: lng),
      heading: state.driverHeading,
      animate: animate,
    );
  }

  // ---------------------------------------------------------------------------
  // Camera rules
  // ---------------------------------------------------------------------------

  bool get _tracking => widget.state.stage == RideStage.tracking;

  /// What the camera is currently framing. A change re-frames once.
  String _frameKey(RideState s) => [
    s.stage.name,
    s.jobStatus ?? '',
    s.pickup?.id ?? '',
    s.destination?.id ?? '',
    // Re-frame once when the first route arrives for this stage.
    s.routePoints.isEmpty ? 'no-route' : 'route',
  ].join('|');

  void _maybeFrame() {
    if (!_following) return;
    final key = _frameKey(widget.state);
    if (key != _framedFor) {
      _framedFor = key;
      unawaited(_fitToContent());
      return;
    }
    if (_tracking) unawaited(_keepDriverInView());
  }

  /// Re-frames only when the driver is about to leave the visible area.
  Future<void> _keepDriverInView() async {
    final controller = _controller;
    final shown = _glide.position;
    if (controller == null || shown == null) return;
    final now = DateTime.now();
    final last = _lastEdgeCheck;
    if (last != null && now.difference(last) < const Duration(seconds: 3)) {
      return;
    }
    _lastEdgeCheck = now;
    try {
      final region = await controller.getVisibleRegion();
      // The region spans the whole view, including what the sheet and top
      // bar cover; only the uncovered part counts as "in view".
      final latSpan = region.northeast.latitude - region.southwest.latitude;
      final height = _mapHeight;
      final padding = widget.mapPadding;
      final coveredBottom = height > 0 ? padding.bottom / height : 0.0;
      final coveredTop = height > 0 ? padding.top / height : 0.0;
      final latPad = latSpan * 0.15;
      final lngPad =
          (region.northeast.longitude - region.southwest.longitude) * 0.15;
      final inside =
          shown.lat >
              region.southwest.latitude + latSpan * coveredBottom + latPad &&
          shown.lat <
              region.northeast.latitude - latSpan * coveredTop - latPad &&
          shown.lng > region.southwest.longitude + lngPad &&
          shown.lng < region.northeast.longitude - lngPad;
      if (!inside && _following && mounted) await _fitToContent();
    } catch (_) {
      // Map not ready.
    }
  }

  Future<void> _fitToContent() async {
    final controller = _controller;
    if (controller == null) return;
    final state = widget.state;
    final points = <LatLng>[];
    if (state.routePoints.isNotEmpty) {
      // The remaining road route already starts at the driver.
      points.addAll(state.routePoints);
    } else {
      final pickup = state.pickup;
      final destination = state.destination;
      if (pickup != null) points.add(LatLng(pickup.latitude, pickup.longitude));
      if (destination != null) {
        points.add(LatLng(destination.latitude, destination.longitude));
      }
    }
    final shown = _glide.position;
    if (shown != null) points.add(LatLng(shown.lat, shown.lng));
    if (points.isEmpty) return;
    // At least ~1.5 km across, like Bolt/Uber: a short trip still shows the
    // surrounding streets instead of zooming to street level.
    final bounds = framingBounds(
      points.map((p) => (lat: p.latitude, lng: p.longitude)),
    );
    if (bounds == null) return;
    try {
      await controller.animateCamera(
        CameraUpdate.newLatLngBounds(
          LatLngBounds(
            southwest: LatLng(bounds.south, bounds.west),
            northeast: LatLng(bounds.north, bounds.east),
          ),
          56,
        ),
      );
    } catch (_) {
      // Map not ready or bounds invalid.
    }
  }

  void _recentre() {
    setState(() => _following = true);
    _framedFor = null;
    _maybeFrame();
  }

  // ---------------------------------------------------------------------------
  // Drawing
  // ---------------------------------------------------------------------------

  Set<Marker> _markersFor(RideState state) {
    final markers = <Marker>{};
    final pickup = state.pickup;
    final destination = state.destination;
    final pickedUp = const {
      'loading',
      'in_transit',
      'arrived_destination',
      'delivered',
    }.contains(state.jobStatus);
    if (pickup != null && !pickedUp) {
      markers.add(
        Marker(
          markerId: const MarkerId('pickup'),
          position: LatLng(pickup.latitude, pickup.longitude),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueGreen,
          ),
          infoWindow: InfoWindow(title: pickup.name),
        ),
      );
    }
    if (destination != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('dropoff'),
          position: LatLng(destination.latitude, destination.longitude),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: InfoWindow(title: destination.name),
        ),
      );
    }
    final shown = _glide.position;
    if (shown != null) {
      final icon = _driverIcon;
      markers.add(
        Marker(
          markerId: const MarkerId('driver'),
          position: LatLng(shown.lat, shown.lng),
          icon:
              icon ??
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
          rotation: icon == null ? 0 : _glide.bearing,
          flat: icon != null,
          anchor: icon == null ? const Offset(0.5, 1) : const Offset(0.5, 0.5),
          zIndexInt: 2,
          infoWindow: InfoWindow(title: state.driver?.name ?? 'Driver'),
        ),
      );
    }
    return markers;
  }

  Set<Polyline> _polylinesFor(RideState state) {
    // Render the actual road-following route when one has been computed.
    // Never fall back to a straight line: if no route is available yet, draw
    // nothing so the customer is not shown an inaccurate path.
    if (state.routePoints.isEmpty) return const <Polyline>{};
    final shown = _glide.position;
    // While the marker glides, start the line at the marker so they meet.
    final points = _tracking && shown != null && state.routePoints.length > 1
        ? <LatLng>[LatLng(shown.lat, shown.lng), ...state.routePoints.skip(1)]
        : state.routePoints;
    return <Polyline>{
      Polyline(
        polylineId: const PolylineId('route'),
        points: points,
        color: context.colors.primary,
        width: 5,
      ),
    };
  }

  LatLng _initialTarget(RideState state) {
    final pickup = state.pickup;
    if (pickup != null) return LatLng(pickup.latitude, pickup.longitude);
    return _defaultCenter;
  }

  @override
  void dispose() {
    _refitAfterPadding?.cancel();
    _glide.dispose();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    return Stack(
      children: [
        Positioned.fill(
          child: LayoutBuilder(
            builder: (context, constraints) {
              _mapHeight = constraints.maxHeight;
              return Listener(
                // Any touch hands the camera to the customer until Re-centre.
                onPointerDown: (_) {
                  if (_following) setState(() => _following = false);
                },
                child: GoogleMap(
                  style: Theme.of(context).brightness == Brightness.dark
                      ? safeShiftDarkMapStyle
                      : null,
                  onMapCreated: (GoogleMapController controller) {
                    _controller = controller;
                    _framedFor = null;
                    _maybeFrame();
                  },
                  initialCameraPosition: CameraPosition(
                    target: _initialTarget(state),
                    zoom: 13,
                  ),
                  markers: _markersFor(state),
                  polylines: _polylinesFor(state),
                  mapType: MapType.normal,
                  myLocationEnabled: true,
                  myLocationButtonEnabled: true,
                  // Fits and centres the camera inside the uncovered area.
                  padding: widget.mapPadding,
                ),
              );
            },
          ),
        ),
        if (!_following && (state.hasRoute || _glide.position != null))
          Positioned(
            right: 16,
            top: MediaQuery.paddingOf(context).top + 120,
            child: FloatingActionButton.small(
              heroTag: 'customer-map-recentre',
              tooltip: 'Re-centre',
              onPressed: _recentre,
              child: const Icon(Icons.center_focus_strong_rounded),
            ),
          ),
      ],
    );
  }
}
