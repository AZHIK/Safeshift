import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_sizes.dart';
import '../../core/theme/text_styles.dart';
import '../../core/widgets/buttons/primary_button.dart';
import '../../core/widgets/cards/info_card.dart';
import '../models/ride_place.dart';
import '../providers/location_provider.dart';
import '../providers/places_provider.dart';
import '../services/places_api.dart';
import '../utils/geo.dart';

/// Opens a draggable-pin map so the customer can refine a GPS or selected
/// location to the exact pickup/delivery point.
Future<RidePlace?> showLocationPicker({
  required BuildContext context,
  required GeoPoint initial,
  String title = 'Adjust location',
}) {
  return Navigator.of(context).push<RidePlace>(
    MaterialPageRoute<RidePlace>(
      builder: (_) => LocationPickerScreen(initial: initial, title: title),
    ),
  );
}

class LocationPickerScreen extends ConsumerStatefulWidget {
  const LocationPickerScreen({
    super.key,
    required this.initial,
    this.title = 'Adjust location',
  });

  final GeoPoint initial;
  final String title;

  @override
  ConsumerState<LocationPickerScreen> createState() =>
      _LocationPickerScreenState();
}

class _LocationPickerScreenState extends ConsumerState<LocationPickerScreen> {
  GoogleMapController? _controller;
  late LatLng _center;
  RidePlace? _preview;
  bool _isResolving = false;
  String? _error;
  Timer? _debounce;
  int _generation = 0;
  LatLng? _lastRequestedCenter;
  CancelToken? _cancelToken;

  @override
  void initState() {
    super.initState();
    _center = LatLng(widget.initial.latitude, widget.initial.longitude);
    WidgetsBinding.instance.addPostFrameCallback((_) => _resolveCenter());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _cancelToken?.cancel('disposed');
    _controller?.dispose();
    super.dispose();
  }

  void _onCameraMove(CameraPosition position) {
    _center = position.target;
    if (_preview != null || _error != null) {
      setState(() {
        _preview = null;
        _error = null;
        _lastRequestedCenter = null;
      });
    }
  }

  void _onCameraIdle() {
    _debounce?.cancel();
    if (_lastRequestedCenter == _center) return;
    _debounce = Timer(const Duration(milliseconds: 400), _resolveCenter);
  }

  Future<void> _resolveCenter() async {
    if (!mounted) return;
    _cancelToken?.cancel('superseded');
    final cancelToken = CancelToken();
    _cancelToken = cancelToken;
    final target = _center;
    _lastRequestedCenter = target;
    final generation = ++_generation;
    setState(() {
      _isResolving = true;
      _error = null;
    });

    try {
      final language = Localizations.localeOf(context).languageCode;
      final place = await ref
          .read(placesRepositoryProvider)
          .reverseGeocode(
            latitude: target.latitude,
            longitude: target.longitude,
            source: RidePlaceSource.map,
            language: language,
            cancelToken: cancelToken,
          );
      // The map may have moved while the request was in flight. Ignore the
      // stale address so the card never describes a different point than the
      // pin.
      if (!mounted || generation != _generation || target != _center) return;
      setState(() {
        _preview = place.copyWith(
          latitude: target.latitude,
          longitude: target.longitude,
          source: RidePlaceSource.map,
          clearPlaceId: true,
        );
        _isResolving = false;
      });
    } on PlacesApiException catch (error) {
      if (!mounted ||
          generation != _generation ||
          target != _center ||
          error.isCancellation) {
        return;
      }
      setState(() {
        _preview = null;
        _isResolving = false;
        _error = error.message;
      });
    } catch (_) {
      if (!mounted || generation != _generation || target != _center) return;
      setState(() {
        _preview = null;
        _isResolving = false;
        _error = 'Could not resolve this point. You can still confirm it.';
      });
    } finally {
      if (identical(_cancelToken, cancelToken)) _cancelToken = null;
    }
  }

  Future<void> _useMyLocation() async {
    final location = await ref.read(currentLocationProvider.notifier).refresh();
    if (!mounted) return;
    if (location == null) {
      final message = ref.read(currentLocationProvider).message;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message ?? 'Your location is unavailable right now.'),
        ),
      );
      return;
    }

    final target = LatLng(location.latitude, location.longitude);
    setState(() => _center = target);
    await _controller?.animateCamera(CameraUpdate.newLatLngZoom(target, 17));
    await _resolveCenter();
  }

  void _confirm() {
    final preview = _preview;
    final place = preview != null
        ? preview.copyWith(
            latitude: _center.latitude,
            longitude: _center.longitude,
            source: RidePlaceSource.map,
            clearPlaceId: true,
          )
        : RidePlace(
            id:
                'map:${_center.latitude.toStringAsFixed(6)},'
                '${_center.longitude.toStringAsFixed(6)}',
            name: 'Pinned location',
            district: 'Map selection',
            latitude: _center.latitude,
            longitude: _center.longitude,
            source: RidePlaceSource.map,
            formattedAddress:
                '${_center.latitude.toStringAsFixed(5)}, '
                '${_center.longitude.toStringAsFixed(5)}',
          );
    Navigator.of(context).pop(place);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        leading: BackButton(onPressed: () => Navigator.of(context).pop()),
      ),
      body: Stack(
        children: <Widget>[
          GoogleMap(
            initialCameraPosition: CameraPosition(target: _center, zoom: 16),
            onMapCreated: (controller) => _controller = controller,
            onCameraMove: _onCameraMove,
            onCameraIdle: _onCameraIdle,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            compassEnabled: true,
            mapToolbarEnabled: false,
          ),
          const IgnorePointer(
            child: Center(
              child: Padding(
                padding: EdgeInsets.only(bottom: 44),
                child: Icon(
                  Icons.location_pin,
                  size: 52,
                  color: AppColors.error,
                ),
              ),
            ),
          ),
          Positioned(
            right: AppSizes.md,
            top: AppSizes.md,
            child: Material(
              color: Colors.white,
              shape: const CircleBorder(),
              elevation: 4,
              child: IconButton(
                tooltip: 'Use my current location',
                onPressed: _useMyLocation,
                icon: const Icon(
                  Icons.my_location_rounded,
                  color: AppColors.primaryDark,
                ),
              ),
            ),
          ),
          Positioned(
            left: AppSizes.md,
            right: AppSizes.md,
            bottom: AppSizes.md,
            child: _PickerCard(
              preview: _preview,
              isResolving: _isResolving,
              error: _error,
              onConfirm: _confirm,
            ),
          ),
        ],
      ),
    );
  }
}

class _PickerCard extends StatelessWidget {
  const _PickerCard({
    required this.preview,
    required this.isResolving,
    required this.error,
    required this.onConfirm,
  });

  final RidePlace? preview;
  final bool isResolving;
  final String? error;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final place = preview;
    final title =
        place?.name ?? (isResolving ? 'Finding address…' : 'Pinned location');
    final address = place?.addressLine ?? '';
    return InfoCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(
                Icons.location_on_rounded,
                color: AppColors.primaryDark,
              ),
              const SizedBox(width: AppSizes.sm),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyles.title,
                ),
              ),
            ],
          ),
          if (address.isNotEmpty) ...<Widget>[
            const SizedBox(height: 4),
            Text(
              address,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyles.caption.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
          if (isResolving) ...<Widget>[
            const SizedBox(height: 8),
            const LinearProgressIndicator(minHeight: 3),
          ],
          if (error != null) ...<Widget>[
            const SizedBox(height: 6),
            Text(
              error!,
              style: TextStyles.caption.copyWith(color: AppColors.error),
            ),
          ],
          const SizedBox(height: 10),
          PrimaryButton(
            label: 'Confirm location',
            icon: Icons.check_rounded,
            isLoading: isResolving,
            onPressed: isResolving ? null : onConfirm,
          ),
        ],
      ),
    );
  }
}
