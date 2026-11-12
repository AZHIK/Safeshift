import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../domain/entities/driver_job.dart';
import '../../domain/entities/driver_status.dart';

/// Google Maps integration for the driver screen.
/// Shows map with pickup/destination markers, driver position, and route polyline.
class MapPlaceholder extends StatefulWidget {
  const MapPlaceholder({super.key, required this.status, this.job});

  final DriverStatus status;
  final DriverJob? job;

  @override
  State<MapPlaceholder> createState() => _MapPlaceholderState();
}

class _MapPlaceholderState extends State<MapPlaceholder> {
  GoogleMapController? _controller;
  Set<Marker> _markers = const <Marker>{};
  final Set<Polyline> _polylines = const <Polyline>{};

  @override
  void initState() {
    super.initState();
    _markers = _buildMarkers();
  }

  @override
  void didUpdateWidget(covariant MapPlaceholder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.status != widget.status || oldWidget.job != widget.job) {
      // Build a NEW set instance: the Maps plugin compares the incoming set
      // with the previous one by identity, so mutating the same set in place
      // would never reach the native map.
      _markers = _buildMarkers();
    }
  }

  Set<Marker> _buildMarkers() {
    // Driver position. While a job is active the driver marker follows the
    // simulated position; otherwise it sits at the default city centre.
    final driverPosition = widget.status.hasActiveJob ||
            widget.status == DriverStatus.incomingJob
        ? const LatLng(-6.7900, 39.2500)
        : const LatLng(-6.7900, 39.2500);

    return <Marker>{
      // Pickup marker (green)
      Marker(
        markerId: const MarkerId('pickup'),
        position: const LatLng(-6.8180, 39.2700), // Kariakoo Market, Dar es Salaam
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        infoWindow: const InfoWindow(title: 'Pickup'),
      ),

      // Drop-off marker (red)
      Marker(
        markerId: const MarkerId('dropoff'),
        position: const LatLng(-6.7750, 39.2250), // Mlimani City, Dar es Salaam
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        infoWindow: const InfoWindow(title: 'Drop-off'),
      ),

      // Driver marker
      Marker(
        markerId: const MarkerId('driver'),
        position: driverPosition,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        infoWindow: const InfoWindow(title: 'Driver'),
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    return GoogleMap(
      onMapCreated: (GoogleMapController controller) {
        _controller = controller;
      },
      initialCameraPosition: const CameraPosition(
        target: LatLng(-6.7900, 39.2500),
        zoom: 14,
      ),
      markers: _markers,
      polylines: _polylines,
      mapType: MapType.normal,
      myLocationEnabled: true,
      myLocationButtonEnabled: true,
    );
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }
}
