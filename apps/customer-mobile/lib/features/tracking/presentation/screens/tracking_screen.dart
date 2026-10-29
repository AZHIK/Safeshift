import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/theme/text_styles.dart';
import '../../../../core/widgets/buttons/primary_button.dart';
import '../../../../core/widgets/cards/driver_avatar_card.dart';
import '../../../../core/widgets/feedback/app_snackbar.dart';
import '../../../booking/providers/booking_provider.dart';
import '../../../phase9/presentation/phase9_screens.dart';
import '../../../ride/providers/ride_provider.dart';
import '../widgets/map_view.dart';
import '../widgets/trip_status_stepper.dart';

/// Live tracking route, also reachable from `safeshift://tracking/<jobId>`.
///
/// The screen reads the same RideNotifier used by the main ride flow, so a
/// deep link and the in-app sheet always show the same server-backed state.
class TrackingScreen extends ConsumerStatefulWidget {
  const TrackingScreen({super.key, this.jobId});

  final String? jobId;

  @override
  ConsumerState<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends ConsumerState<TrackingScreen> {
  bool _uploading = false;

  Future<void> _attach({required bool evidence}) async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 2000,
    );
    if (picked == null) return;
    setState(() => _uploading = true);
    final notifier = ref.read(rideProvider.notifier);
    final bytes = await picked.readAsBytes();
    final ok = evidence
        ? await notifier.uploadEvidence(
            evidenceType: 'delivery_photo',
            bytes: bytes,
            fileName: picked.name,
            mimeType: picked.mimeType ?? 'image/jpeg',
          )
        : await notifier.sendChatAttachment(
            bytes: bytes,
            fileName: picked.name,
            mimeType: picked.mimeType ?? 'image/jpeg',
          );
    if (!mounted) return;
    setState(() => _uploading = false);
    if (ok) {
      AppSnackbar.showSuccess(
        context,
        evidence ? 'Photo attached to this move.' : 'Photo sent to driver.',
      );
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final id = widget.jobId;
      if (id == null || id.isEmpty) return;
      if (ref.read(rideProvider).jobId != id) {
        ref.read(rideProvider.notifier).loadJob(id);
      }
    });
  }

  int _stepFor(String? status) => switch (status) {
    'accepted' || 'heading_to_pickup' => 0,
    'arrived' => 1,
    'loading' => 2,
    'in_transit' => 3,
    'delivered' || 'completed' => 4,
    _ => 0,
  };

  String _labelFor(String? status) => switch (status) {
    'accepted' || 'heading_to_pickup' => 'Driver is heading to pickup',
    'arrived' => 'Driver has arrived at pickup',
    'loading' => 'Cargo is being loaded',
    'in_transit' => 'On the way to destination',
    'delivered' => 'Delivered',
    'completed' => 'Move completed',
    'cancelled' => 'Move cancelled',
    _ => 'Looking for a driver',
  };

  @override
  Widget build(BuildContext context) {
    final ride = ref.watch(rideProvider);
    final booking = ref.watch(bookingProvider);
    final driver = ride.driver;
    final pickup =
        ride.pickupAddress ??
        ride.pickup?.name ??
        booking?.pickup.name ??
        'Pickup';
    final destination =
        ride.destinationAddress ??
        ride.destination?.name ??
        booking?.destination.name ??
        'Destination';

    return Scaffold(
      appBar: AppBar(title: const Text('Track your move')),
      body: Column(
        children: <Widget>[
          const Expanded(flex: 4, child: MapView()),
          Expanded(
            flex: 6,
            child: Container(
              decoration: const BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: Color(0x14000000),
                    blurRadius: 16,
                    offset: Offset(0, -4),
                  ),
                ],
              ),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSizes.lg,
                  AppSizes.lg,
                  AppSizes.lg,
                  AppSizes.xl,
                ),
                children: <Widget>[
                  if (ride.errorMessage != null) ...<Widget>[
                    Text(
                      ride.errorMessage!,
                      style: TextStyles.body.copyWith(color: AppColors.error),
                    ),
                    const SizedBox(height: AppSizes.sm),
                  ],
                  TripStatusStepper(currentStep: _stepFor(ride.jobStatus)),
                  const SizedBox(height: AppSizes.md),
                  Text(
                    _labelFor(ride.jobStatus),
                    style: TextStyles.title.copyWith(fontSize: 15),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSizes.md),
                  if (driver != null)
                    DriverAvatarCard(driver: driver, showActions: true)
                  else
                    Text(
                      ride.jobId == null
                          ? 'Open this link from a move to see live status.'
                          : 'Assigning the nearest driver…',
                      textAlign: TextAlign.center,
                      style: TextStyles.body.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  const SizedBox(height: AppSizes.sm),
                  _JobRouteRow(
                    icon: Icons.trip_origin_rounded,
                    color: AppColors.success,
                    title: pickup,
                  ),
                  const SizedBox(height: AppSizes.xs),
                  _JobRouteRow(
                    icon: Icons.location_on_rounded,
                    color: AppColors.error,
                    title: destination,
                  ),
                  const SizedBox(height: AppSizes.sm),
                  Text(
                    ride.deliveryOtp == null
                        ? '${ride.distanceKm.toStringAsFixed(1)} km'
                        : 'Delivery code: ${ride.deliveryOtp}',
                    style: TextStyles.caption.copyWith(
                      color: ride.deliveryOtp == null
                          ? AppColors.textSecondary
                          : AppColors.primary,
                      fontWeight: ride.deliveryOtp == null
                          ? FontWeight.w400
                          : FontWeight.w700,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSizes.md),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: <Widget>[
                      TextButton.icon(
                        onPressed: ride.jobId == null
                            ? null
                            : () => shareTrip(context, ref, ride.jobId!),
                        icon: const Icon(Icons.share_outlined),
                        label: const Text('Share Trip'),
                      ),
                      TextButton.icon(
                        onPressed: ride.jobId == null
                            ? null
                            : () => raiseSos(context, ref, ride.jobId!),
                        icon: const Icon(
                          Icons.emergency_outlined,
                          color: AppColors.error,
                        ),
                        label: const Text(
                          'Emergency',
                          style: TextStyle(color: AppColors.error),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSizes.sm),
                  OutlinedButton.icon(
                    onPressed: _uploading
                        ? null
                        : () => _attach(evidence: false),
                    icon: const Icon(Icons.chat_bubble_outline_rounded),
                    label: Text(
                      _uploading ? 'Uploading…' : 'Send photo to driver',
                    ),
                  ),
                  const SizedBox(height: AppSizes.xs),
                  OutlinedButton.icon(
                    onPressed: _uploading
                        ? null
                        : () => _attach(evidence: true),
                    icon: const Icon(Icons.add_a_photo_outlined),
                    label: const Text('Add delivery photo'),
                  ),
                  const SizedBox(height: AppSizes.md),
                  PrimaryButton(
                    label: 'Back to home',
                    onPressed: () => context.go('/home'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _JobRouteRow extends StatelessWidget {
  const _JobRouteRow({
    required this.icon,
    required this.color,
    required this.title,
  });

  final IconData icon;
  final Color color;
  final String title;

  @override
  Widget build(BuildContext context) => Row(
    children: <Widget>[
      Icon(icon, size: 19, color: color),
      const SizedBox(width: AppSizes.sm),
      Expanded(
        child: Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyles.title.copyWith(fontSize: 12),
        ),
      ),
    ],
  );
}
