import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../domain/entities/driver_status.dart';
import '../../providers/home_provider.dart';
import '../widgets/map_placeholder.dart';
import '../widgets/sheets/arrived_at_destination_sheet.dart';
import '../widgets/sheets/arrived_at_pickup_sheet.dart';
import '../widgets/sheets/heading_to_pickup_sheet.dart';
import '../widgets/sheets/in_transit_sheet.dart';
import '../widgets/sheets/incoming_job_sheet.dart';
import '../widgets/sheets/loading_sheet.dart';
import '../widgets/sheets/offline_sheet.dart';
import '../widgets/sheets/online_sheet.dart';
import '../widgets/sheets/searching_sheet.dart';
import '../widgets/sheets/trip_completed_sheet.dart';

/// THE single driver screen. The map stays fixed; the bottom sheet morphs
/// in place as [DriverStatus] changes. No job-flow routes are pushed.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {

  ({double initial, double min, double max}) _sizesFor(DriverStatus status) {
    return switch (status) {
      DriverStatus.offline => (initial: 0.28, min: 0.22, max: 0.55),
      DriverStatus.onlineIdle => (initial: 0.30, min: 0.22, max: 0.55),
      DriverStatus.onlineSearching => (initial: 0.32, min: 0.22, max: 0.55),
      DriverStatus.incomingJob => (initial: 0.9, min: 0.5, max: 0.95),
      DriverStatus.headingToPickup => (initial: 0.42, min: 0.3, max: 0.7),
      DriverStatus.arrivedAtPickup => (initial: 0.42, min: 0.3, max: 0.7),
      DriverStatus.loading => (initial: 0.5, min: 0.3, max: 0.75),
      DriverStatus.inTransit => (initial: 0.42, min: 0.3, max: 0.7),
      DriverStatus.arrivedAtDestination =>
        (initial: 0.42, min: 0.3, max: 0.7),
      DriverStatus.tripCompleted => (initial: 0.85, min: 0.5, max: 0.95),
    };
  }

  @override
  Widget build(BuildContext context) {
    final home = ref.watch(homeProvider);
    final status = home.driverStatus;
    final sizes = _sizesFor(status);
    final job = home.activeJob ?? home.incomingJob;

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: MapPlaceholder(status: status, job: job),
          ),
          if (status == DriverStatus.incomingJob)
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  color: AppColors.primaryDark.withValues(alpha: 0.08),
                ),
              ),
            ),
          DraggableScrollableSheet(
            key: ValueKey<DriverStatus>(status),
            initialChildSize: sizes.initial,
            minChildSize: sizes.min,
            maxChildSize: sizes.max,
            snap: true,
            builder: (context, controller) => Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius:
                    BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [
                  BoxShadow(
                    color: Color(0x1A4E5E73),
                    blurRadius: 24,
                    offset: Offset(0, -8),
                  ),
                ],
              ),
              child: _SheetBody(status: status),
            ),
          ),
        ],
      ),
    );
  }
}

/// Wraps state-driven sheet content so the offline toggle can intercept
/// the first "Go Online" tap for mock permission dialogs.
class _SheetBody extends ConsumerWidget {
  const _SheetBody({required this.status});

  final DriverStatus status;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Offline sheet's toggle calls goOnline directly; the permission
    // dialogs are handled by wrapping here only when needed. The sheet
    // widgets own their scroll views, so this just switches content.
    return switch (status) {
      DriverStatus.offline => const OfflineSheet(),
      DriverStatus.onlineIdle => const OnlineSheet(),
      DriverStatus.onlineSearching => const SearchingSheet(),
      DriverStatus.incomingJob => const IncomingJobSheet(),
      DriverStatus.headingToPickup => const HeadingToPickupSheet(),
      DriverStatus.arrivedAtPickup => const ArrivedAtPickupSheet(),
      DriverStatus.loading => const LoadingSheet(),
      DriverStatus.inTransit => const InTransitSheet(),
      DriverStatus.arrivedAtDestination =>
        const ArrivedAtDestinationSheet(),
      DriverStatus.tripCompleted => const TripCompletedSheet(),
    };
  }
}
