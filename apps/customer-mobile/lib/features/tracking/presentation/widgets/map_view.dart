import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../ride/providers/ride_provider.dart';

/// Google Maps view for tracking, driven by real ride/job state.
class MapView extends ConsumerStatefulWidget {
  const MapView({super.key});

  @override
  ConsumerState<MapView> createState() => _MapViewState();
}

class _MapViewState extends ConsumerState<MapView> {
  GoogleMapController? _controller;
  static const _defaultCenter = LatLng(-6.7924, 39.2083);

  Set<Marker> _markers(RideState state) {
    final markers = <Marker>{};
    final pickup = state.pickup;
    if (pickup != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('pickup'),
          position: LatLng(pickup.latitude, pickup.longitude),
          icon:
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          infoWindow: InfoWindow(title: pickup.name),
        ),
      );
    }
    final destination = state.destination;
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
    if (state.driverLatitude != null && state.driverLongitude != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('driver'),
          position: LatLng(state.driverLatitude!, state.driverLongitude!),
          icon:
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
          infoWindow: InfoWindow(title: state.driver?.name ?? 'Driver'),
        ),
      );
    }
    return markers;
  }

  Set<Polyline> _polylines(RideState state) {
    // Prefer the computed road route. Fall back to a straight line only when
    // no road route is available yet.
    if (state.routePoints.isNotEmpty) {
      return {
        Polyline(
          polylineId: const PolylineId('route'),
          points: state.routePoints,
          color: AppColors.primaryDark,
          width: 5,
        ),
      };
    }
    final pickup = state.pickup;
    final destination = state.destination;
    if (pickup == null || destination == null) return const <Polyline>{};
    return {
      Polyline(
        polylineId: const PolylineId('route'),
        points: [
          LatLng(pickup.latitude, pickup.longitude),
          LatLng(destination.latitude, destination.longitude),
        ],
        color: AppColors.primaryDark,
        width: 5,
      ),
    };
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(rideProvider);
    final target = state.pickup != null
        ? LatLng(state.pickup!.latitude, state.pickup!.longitude)
        : _defaultCenter;
    return GoogleMap(
      onMapCreated: (GoogleMapController controller) => _controller = controller,
      initialCameraPosition: CameraPosition(target: target, zoom: 13),
      markers: _markers(state),
      polylines: _polylines(state),
      mapType: MapType.normal,
      myLocationEnabled: true,
      myLocationButtonEnabled: true,
    );
  }
}
