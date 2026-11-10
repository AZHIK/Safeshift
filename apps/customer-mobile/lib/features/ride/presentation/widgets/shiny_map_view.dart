import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../../core/constants/app_colors.dart';
import '../../providers/ride_provider.dart';

/// Google Maps integration for the customer ride screen.
/// Shows pickup/drop-off from real ride state and driver position when available.
class ShinyMapView extends StatefulWidget {
  const ShinyMapView({super.key, required this.state});

  final RideState state;

  @override
  State<ShinyMapView> createState() => ShinyMapViewState();
}

class ShinyMapViewState extends State<ShinyMapView> {
  GoogleMapController? _controller;

  static const _defaultCenter = LatLng(-6.7924, 39.2083); // Dar es Salaam

  /// Centers the map on a fresh device location when the customer taps the
  /// my-location control.
  Future<void> moveTo(double latitude, double longitude) async {
    final controller = _controller;
    if (controller == null) return;
    try {
      await controller.animateCamera(
        CameraUpdate.newLatLngZoom(LatLng(latitude, longitude), 16),
      );
    } catch (_) {
      // Map not ready or the view was disposed.
    }
  }

  @override
  void didUpdateWidget(covariant ShinyMapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    _fitToContent();
  }

  Set<Marker> _markersFor(RideState state) {
    final markers = <Marker>{};
    final pickup = state.pickup;
    final destination = state.destination;
    if (pickup != null) {
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
    final dLat = state.driverLatitude;
    final dLng = state.driverLongitude;
    if (dLat != null && dLng != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('driver'),
          position: LatLng(dLat, dLng),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueAzure,
          ),
          infoWindow: InfoWindow(title: state.driver?.name ?? 'Driver'),
        ),
      );
    }
    return markers;
  }

  Set<Polyline> _polylinesFor(RideState state) {
    // Render the actual road-following route when one has been computed.
    // Never fall back to a straight line: if no route is available yet, draw
    // nothing so the driver is not shown an inaccurate path.
    if (state.routePoints.isNotEmpty) {
      return <Polyline>{
        Polyline(
          polylineId: const PolylineId('route'),
          points: state.routePoints,
          color: AppColors.primaryDark,
          width: 5,
        ),
      };
    }
    return const <Polyline>{};
  }

  LatLng _initialTarget(RideState state) {
    final pickup = state.pickup;
    if (pickup != null) return LatLng(pickup.latitude, pickup.longitude);
    return _defaultCenter;
  }

  Future<void> _fitToContent() async {
    final controller = _controller;
    if (controller == null) return;
    final points = <LatLng>[];
    // Fit to the full road route when available so the entire driving path is
    // visible, not just the endpoints.
    if (widget.state.routePoints.isNotEmpty) {
      points.addAll(widget.state.routePoints);
    } else {
      final pickup = widget.state.pickup;
      final destination = widget.state.destination;
      if (pickup != null) points.add(LatLng(pickup.latitude, pickup.longitude));
      if (destination != null) {
        points.add(LatLng(destination.latitude, destination.longitude));
      }
    }
    if (widget.state.driverLatitude != null &&
        widget.state.driverLongitude != null) {
      points.add(
        LatLng(widget.state.driverLatitude!, widget.state.driverLongitude!),
      );
    }
    if (points.length < 2) return;
    double minLat = points.first.latitude, maxLat = points.first.latitude;
    double minLng = points.first.longitude, maxLng = points.first.longitude;
    for (final p in points) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }
    try {
      await controller.animateCamera(
        CameraUpdate.newLatLngBounds(
          LatLngBounds(
            southwest: LatLng(minLat, minLng),
            northeast: LatLng(maxLat, maxLng),
          ),
          60,
        ),
      );
    } catch (_) {
      // Map not ready or bounds invalid.
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    return GoogleMap(
      onMapCreated: (GoogleMapController controller) {
        _controller = controller;
        _fitToContent();
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
    );
  }
}
