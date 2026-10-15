import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/theme/text_styles.dart';
import '../../../../core/widgets/buttons/primary_button.dart';
import '../../../../core/widgets/cards/driver_avatar_card.dart';
import '../../../../core/widgets/cards/receipt_card.dart';
import '../../../../shared/mock/mock_drivers.dart';
import '../../../../shared/mock/mock_jobs.dart';
import '../../../../shared/mock/mock_locations.dart';
import '../../../../shared/mock/mock_vehicle_classes.dart';
import '../../../booking/providers/booking_provider.dart';
import '../../../tracking/domain/entities/driver.dart';
import '../../../booking/domain/entities/job.dart';

class HistoryDetailScreen extends ConsumerWidget {
  const HistoryDetailScreen({super.key, required this.jobId});
  final String jobId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final matches = mockJobs.where((job) => job.id == jobId);
    if (matches.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Trip Details')),
        body: const Center(child: Text('Trip not found.')),
      );
    }
    final job = matches.first;
    final driver = _driverFor(job);
    return Scaffold(
      appBar: AppBar(title: const Text('Trip Details')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSizes.lg,
          AppSizes.md,
          AppSizes.lg,
          AppSizes.xl,
        ),
        children: <Widget>[
          Text(
            DateFormat('EEEE, d MMMM yyyy')
                .format(job.createdAt ?? DateTime.now()),
            style: TextStyles.title.copyWith(fontSize: 16),
          ),
          const SizedBox(height: AppSizes.md),
          DriverAvatarCard(driver: driver),
          const SizedBox(height: AppSizes.md),
          _RouteSummary(job: job),
          const SizedBox(height: AppSizes.md),
          ReceiptCard.fromJob(job: job, driverName: driver.name),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSizes.lg,
            AppSizes.sm,
            AppSizes.lg,
            AppSizes.md,
          ),
          child: PrimaryButton(
            label: 'Book Again',
            onPressed: () {
              final pickup = mockLocations.firstWhere(
                (location) => location.name == job.pickupAddress,
                orElse: () => mockLocations.first,
              );
              final destination = mockLocations.firstWhere(
                (location) => location.name == job.destinationAddress,
                orElse: () => mockLocations[1],
              );
              final vehicle = mockVehicleClasses.firstWhere(
                (item) => item.id == job.vehicleClassId,
                orElse: () => mockVehicleClasses.first,
              );
              ref
                  .read(bookingProvider.notifier)
                  .save(
                    BookingDraft(
                      pickup: pickup,
                      destination: destination,
                      cargoCategory: null,
                      vehicleClass: vehicle,
                      scheduledTime: null,
                    ),
                  );
              context.push('/booking');
            },
          ),
        ),
      ),
    );
  }

  Driver _driverFor(Job job) {
    for (final driver in mockDrivers) {
      if (driver.id == job.driverId) return driver;
    }
    return mockDrivers.first;
  }
}

class _RouteSummary extends StatelessWidget {
  const _RouteSummary({required this.job});
  final Job job;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(AppSizes.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text('Route', style: TextStyles.title),
          const SizedBox(height: AppSizes.md),
          _RouteRow(
            icon: Icons.trip_origin_rounded,
            color: AppColors.success,
            text: job.pickupAddress,
          ),
          const SizedBox(height: AppSizes.sm),
          _RouteRow(
            icon: Icons.location_on_rounded,
            color: AppColors.error,
            text: job.destinationAddress,
          ),
          const Divider(height: AppSizes.lg),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              const Text('Trip amount'),
              Text(
                'TZS ${NumberFormat('#,##0').format(job.quoteAmount)}',
                style: TextStyles.title,
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

class _RouteRow extends StatelessWidget {
  const _RouteRow({
    required this.icon,
    required this.color,
    required this.text,
  });
  final IconData icon;
  final Color color;
  final String text;
  @override
  Widget build(BuildContext context) => Row(
    children: <Widget>[
      Icon(icon, size: 20, color: color),
      const SizedBox(width: AppSizes.sm),
      Expanded(
        child: Text(text, style: const TextStyle(fontWeight: FontWeight.w600)),
      ),
    ],
  );
}
