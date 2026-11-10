import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../../shared/mock/mock_jobs.dart';
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
  late GoogleMapController _controller;
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};
  LatLng? _driverPosition;

  @override
  void initState() {
    super.initState();
    _initMarkers();
  }

  void _initMarkers() {
    // Pickup marker (green)
    _markers.add(
      Marker(
        markerId: const MarkerId('pickup'),
        position: const LatLng(-6.8180, 39.2700), // Kariakoo Market, Dar es Salaam
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        infoWindow: const InfoWindow(title: 'Pickup'),
      ),
    );

    // Drop-off marker (red)
    _markers.add(
      Marker(
        markerId: const MarkerId('dropoff'),
        position: const LatLng(-6.7750, 39.2250), // Mlimani City, Dar es Salaam
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        infoWindow: const InfoWindow(title: 'Drop-off'),
      ),
    );

    // Driver marker
    _markers.add(
      Marker(
        markerId: const MarkerId('driver'),
        position: _driverPosition ?? const LatLng(-6.7900, 39.2500),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        infoWindow: const InfoWindow(title: 'Driver'),
      ),
    );

    // Update driver position based on status
    if (widget.status.hasActiveJob || widget.status == DriverStatus.incomingJob) {
      _driverPosition = const LatLng(-6.7900, 39.2500); // Simulated position
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return GoogleMap(
      onMapCreated: (GoogleMapController controller) {
        _controller = controller;
        setState(() {});
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
    _controller.dispose();
    super.dispose();
  }
}