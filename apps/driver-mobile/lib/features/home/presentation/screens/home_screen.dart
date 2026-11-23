import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/feedback/app_snackbar.dart';
import '../../domain/entities/driver_status.dart';
import '../../providers/home_provider.dart';
import '../widgets/location_issue_banner.dart';
import '../widgets/map_placeholder.dart';
import '../widgets/sheets/arrived_at_destination_sheet.dart';
import '../widgets/sheets/cargo_review_sheet.dart';
import '../widgets/sheets/cargo_verified_sheet.dart';
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
  /// How far the sheet is open (fraction of the screen). The sheet is rebuilt
  /// per status at its initial size; drags update this once they settle.
  double? _sheetExtent;
  DriverStatus? _extentFor;
  Timer? _sheetSettle;

  bool _onSheetMoved(DraggableScrollableNotification notification) {
    final extent = notification.extent;
    _sheetSettle?.cancel();
    _sheetSettle = Timer(const Duration(milliseconds: 180), () {
      if (mounted && (extent - (_sheetExtent ?? 0)).abs() > 0.01) {
        setState(() => _sheetExtent = extent);
      }
    });
    return false;
  }

  /// The part of the map hidden by the sheet, so the camera frames the route
  /// and the vehicle in what the driver can actually see.
  EdgeInsets _mapPadding(BuildContext context, double extent) {
    final height = MediaQuery.sizeOf(context).height;
    final bottom = (height * extent).clamp(0.0, height * 0.62);
    return EdgeInsets.only(
      top: MediaQuery.paddingOf(context).top + 12,
      bottom: bottom,
    );
  }

  @override
  void dispose() {
    _sheetSettle?.cancel();
    super.dispose();
  }

  ({double initial, double min, double max}) _sizesFor(DriverStatus status) {
    return switch (status) {
      DriverStatus.offline => (initial: 0.28, min: 0.22, max: 0.55),
      DriverStatus.onlineIdle => (initial: 0.30, min: 0.22, max: 0.55),
      DriverStatus.onlineSearching => (initial: 0.32, min: 0.22, max: 0.55),
      DriverStatus.incomingJob => (initial: 0.9, min: 0.5, max: 0.95),
      DriverStatus.headingToPickup => (initial: 0.42, min: 0.3, max: 0.7),
      DriverStatus.arrivedAtPickup => (initial: 0.55, min: 0.3, max: 0.85),
      DriverStatus.cargoVerified => (initial: 0.55, min: 0.3, max: 0.85),
      DriverStatus.loading => (initial: 0.5, min: 0.3, max: 0.75),
      DriverStatus.inTransit => (initial: 0.42, min: 0.3, max: 0.7),
      DriverStatus.arrivedAtDestination => (initial: 0.5, min: 0.3, max: 0.8),
      DriverStatus.delivered => (initial: 0.45, min: 0.3, max: 0.7),
      DriverStatus.tripCompleted => (initial: 0.85, min: 0.5, max: 0.95),
    };
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<int>(homeProvider.select((s) => s.noticeSeq), (previous, next) {
      final notice = ref.read(homeProvider).notice;
      if (previous == next || notice == null || notice.isEmpty) return;
      AppSnackbar.showInfo(context, notice);
    });
    // Errors from going online (e.g. no verified vehicle) used to be set but
    // never shown on this screen. Job sheets render their own errors inline.
    ref.listen<String?>(homeProvider.select((s) => s.errorMessage), (
      previous,
      next,
    ) {
      final status = ref.read(homeProvider).driverStatus;
      final idle =
          status == DriverStatus.offline ||
          status == DriverStatus.onlineIdle ||
          status == DriverStatus.onlineSearching;
      if (next == null || next == previous || !idle) return;
      AppSnackbar.showError(context, next);
    });
    final home = ref.watch(homeProvider);
    final status = home.driverStatus;
    final sizes = _sizesFor(status);
    final job = home.activeJob ?? home.incomingJob;
    if (_extentFor != status) {
      // A new status rebuilds the sheet at its initial size.
      _extentFor = status;
      _sheetExtent = sizes.initial;
    }
    final extent = _sheetExtent ?? sizes.initial;

    return Scaffold(
      body: NotificationListener<DraggableScrollableNotification>(
        onNotification: _onSheetMoved,
        child: Stack(
          children: [
            Positioned.fill(
              child: MapPlaceholder(
                status: status,
                job: job,
                mapPadding: _mapPadding(context, extent),
              ),
            ),
            if (status == DriverStatus.incomingJob)
              Positioned.fill(
                child: IgnorePointer(
                  child: Container(
                    color: context.colors.primary.withValues(alpha: 0.08),
                  ),
                ),
              ),
            // Top overlay: the location banner, then the cargo button. One
            // column so they never overlap.
            Positioned(
              top: MediaQuery.of(context).padding.top + 12,
              left: 16,
              right: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  AnimatedSize(
                    duration: const Duration(milliseconds: 200),
                    alignment: Alignment.topCenter,
                    child: home.locationIssue == null
                        ? const SizedBox(width: double.infinity)
                        : Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: LocationIssueBanner(
                              issue: home.locationIssue!,
                              offline: status == DriverStatus.offline,
                            ),
                          ),
                  ),
                  // Cargo stays reviewable at every stage of a job — before
                  // accepting and all the way through delivery.
                  if (job != null)
                    FloatingActionButton.small(
                      heroTag: 'cargo-review',
                      tooltip: 'Review cargo',
                      onPressed: () =>
                          showCargoReviewSheet(context, job, ref: ref),
                      child: const Icon(Icons.inventory_2_outlined),
                    ),
                ],
              ),
            ),
            DraggableScrollableSheet(
              key: ValueKey<DriverStatus>(status),
              initialChildSize: sizes.initial,
              minChildSize: sizes.min,
              maxChildSize: sizes.max,
              snap: true,
              builder: (context, controller) => Container(
                decoration: BoxDecoration(
                  color: context.colors.surface,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(24),
                  ),
                  boxShadow: [
                    const BoxShadow(
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
      DriverStatus.cargoVerified => const CargoVerifiedSheet(),
      DriverStatus.loading => const LoadingSheet(),
      DriverStatus.inTransit => const InTransitSheet(),
      DriverStatus.arrivedAtDestination => const ArrivedAtDestinationSheet(),
      DriverStatus.delivered => const ArrivedAtDestinationSheet(),
      DriverStatus.tripCompleted => const TripCompletedSheet(),
    };
  }
}
