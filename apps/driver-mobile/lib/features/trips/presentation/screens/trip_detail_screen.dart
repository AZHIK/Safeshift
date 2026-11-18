import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/errors/error_handler.dart';
import '../../../../core/theme/text_styles.dart';
import '../../../../core/widgets/cards/info_card.dart';
import '../../../../core/widgets/cards/status_pill.dart';
import '../../../../core/widgets/feedback/app_empty_state.dart';
import '../../../home/domain/entities/driver_job.dart';
import '../../providers/trips_provider.dart';

String _tzs(num amount) => 'TZS ${NumberFormat('#,##0').format(amount)}';

/// Pushed route: details of a real trip owned by the signed-in driver.
///
/// The trip is loaded by id from the server instead of filtering the history
/// page, so routes to older trips resolve and unknown/foreign ids show a
/// missing state rather than a stale list entry.
class TripDetailScreen extends ConsumerWidget {
  const TripDetailScreen({super.key, required this.tripId});

  final String tripId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trip = ref.watch(driverTripDetailProvider(tripId));
    return Scaffold(
      appBar: AppBar(title: const Text('Trip details')),
      body: trip.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => AppEmptyState(
          icon: Icons.cloud_off_rounded,
          title: 'Could not load this trip',
          message: ErrorHandler.map(error, stackTrace: stack).message,
          actionLabel: 'Try again',
          onAction: () => ref.invalidate(driverTripDetailProvider(tripId)),
        ),
        data: (trip) {
          if (trip == null) {
            return AppEmptyState(
              icon: Icons.search_off_rounded,
              title: 'Trip not found',
              message: 'This trip does not exist or does not belong to your account.',
              actionLabel: 'Back to trips',
              onAction: () =>
                  context.canPop() ? context.pop() : context.go('/trips'),
            );
          }
          return _TripDetails(trip: trip);
        },
      ),
    );
  }
}

class _TripDetails extends StatelessWidget {
  const _TripDetails({required this.trip});

  final DriverJob trip;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSizes.lg),
      children: [
        InfoCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  StatusPill(status: trip.status ?? 'completed'),
                  const Spacer(),
                  Text(
                    trip.completedAt == null
                        ? 'Completion time unavailable'
                        : DateFormat('d MMM yyyy, h:mm a')
                              .format(trip.completedAt!),
                    style: TextStyles.caption.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSizes.md),
              _Leg(
                icon: Icons.location_on_rounded,
                color: AppColors.onlineGreen,
                label: 'Pickup',
                value: trip.pickup,
              ),
              const SizedBox(height: AppSizes.sm),
              _Leg(
                icon: Icons.flag_rounded,
                color: AppColors.error,
                label: 'Destination',
                value: trip.destination,
              ),
              const Divider(height: AppSizes.lg),
              _Row(
                label: 'Distance',
                value: '${trip.distanceKm.toStringAsFixed(1)} km',
              ),
              _Row(label: 'Customer', value: trip.customerName),
              _Row(label: 'Cargo', value: trip.cargoClass),
              if (trip.cargoDescription != null &&
                  trip.cargoDescription!.isNotEmpty)
                _Row(label: 'Description', value: trip.cargoDescription!),
              if (trip.cargoWeightKg != null)
                _Row(label: 'Weight', value: '${trip.cargoWeightKg} kg'),
              _Row(
                label: 'Fare',
                value: _tzs(trip.estimatedFareTzs),
                isTotal: true,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Leg extends StatelessWidget {
  const _Leg({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final Color color;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: AppSizes.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyles.caption.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              Text(value, style: TextStyles.title),
            ],
          ),
        ),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value, this.isTotal = false});

  final String label;
  final String value;
  final bool isTotal;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyles.caption.copyWith(
                color: AppColors.textSecondary,
                fontSize: isTotal ? 14 : 12,
              ),
            ),
          ),
          Text(
            value,
            style: isTotal
                ? TextStyles.title.copyWith(fontSize: 15)
                : const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
