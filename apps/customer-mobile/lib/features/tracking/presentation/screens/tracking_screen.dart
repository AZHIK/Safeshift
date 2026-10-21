import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/theme/text_styles.dart';
import '../../../../core/widgets/buttons/primary_button.dart';
import '../../../../core/widgets/cards/driver_avatar_card.dart';
import '../../../../core/widgets/feedback/app_snackbar.dart';
import '../../../../shared/mock/mock_drivers.dart';
import '../../../booking/providers/booking_provider.dart';
import '../widgets/map_view.dart';
import '../widgets/trip_status_stepper.dart';
import '../../providers/tracking_provider.dart';

class TrackingScreen extends ConsumerWidget {
  const TrackingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tracking = ref.watch(trackingProvider);
    final booking = ref.watch(bookingProvider);
    final driver = mockDrivers.firstWhere(
      (item) => item.id == tracking.driverLocation.driverId,
    );
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
                  TripStatusStepper(currentStep: tracking.currentStep),
                  const SizedBox(height: AppSizes.md),
                  DriverAvatarCard(driver: driver, showActions: true),
                  const SizedBox(height: AppSizes.sm),
                  _JobRouteRow(
                    icon: Icons.trip_origin_rounded,
                    color: AppColors.success,
                    title: booking?.pickup.name ?? 'Kariakoo Market',
                  ),
                  const SizedBox(height: AppSizes.xs),
                  _JobRouteRow(
                    icon: Icons.location_on_rounded,
                    color: AppColors.error,
                    title: booking?.destination.name ?? 'Mlimani City Mall',
                  ),
                  const SizedBox(height: AppSizes.sm),
                  Text(
                    '5.4 km  ·  18 min remaining',
                    style: TextStyles.caption.copyWith(
                      color: AppColors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSizes.md),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: <Widget>[
                      TextButton.icon(
                        onPressed: () => AppSnackbar.showInfo(
                          context,
                          'Share link copied (mock)',
                        ),
                        icon: const Icon(Icons.share_outlined),
                        label: const Text('Share Trip'),
                      ),
                      TextButton.icon(
                        onPressed: () => AppSnackbar.showError(
                          context,
                          'Emergency calling is not available yet',
                        ),
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
                  PrimaryButton(
                    label: 'Contact Driver',
                    onPressed: () => AppSnackbar.showInfo(
                      context,
                      'Calling ${driver.name} (mock)',
                    ),
                  ),
                  const SizedBox(height: AppSizes.md),
                  TextButton(
                    onPressed: () => context.push('/delivery'),
                    child: const Text('Confirm delivery'),
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
