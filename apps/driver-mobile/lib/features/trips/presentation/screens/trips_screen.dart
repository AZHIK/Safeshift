import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/errors/error_handler.dart';
import '../../../../core/theme/text_styles.dart';
import '../../../../core/widgets/buttons/primary_button.dart';
import '../../../../core/widgets/cards/info_card.dart';
import '../../../../core/widgets/cards/status_pill.dart';
import '../../../../shared/mock/mock_jobs.dart';
import '../../providers/trips_provider.dart';

String _tzs(num amount) => 'TZS ${NumberFormat('#,##0').format(amount)}';

/// Pushed route: completed-trips history with filter chips.
class TripsScreen extends ConsumerWidget {
  const TripsScreen({super.key});

  static const List<String> filters = <String>[
    'All',
    'Today',
    'This Week',
    'This Month',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(tripsFilterProvider);
    final tripsAsync = ref.watch(filteredTripsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Your trips')),
      body: Column(
        children: [
          SizedBox(
            height: 44,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppSizes.lg),
              itemCount: filters.length,
              separatorBuilder: (_, _) => const SizedBox(width: AppSizes.sm),
              itemBuilder: (context, i) {
                final selected = filters[i] == active;
                return ChoiceChip(
                  label: Text(filters[i]),
                  selected: selected,
                  onSelected: (_) => ref
                      .read(tripsFilterProvider.notifier)
                      .setFilter(filters[i]),
                );
              },
            ),
          ),
          const SizedBox(height: AppSizes.sm),
          Expanded(
            child: tripsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) {
                final failure = ErrorHandler.map(error, stackTrace: stack);
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSizes.xl),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(failure.message, textAlign: TextAlign.center),
                        const SizedBox(height: AppSizes.md),
                        PrimaryButton(
                          label: 'Try again',
                          onPressed: () =>
                              ref.read(driverTripsProvider.notifier).refresh(),
                        ),
                      ],
                    ),
                  ),
                );
              },
              data: (trips) => trips.isEmpty
                  ? const Center(child: Text('No trips for this filter'))
                  : RefreshIndicator(
                      onRefresh: () =>
                          ref.read(driverTripsProvider.notifier).refresh(),
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(
                          AppSizes.lg,
                          AppSizes.sm,
                          AppSizes.lg,
                          AppSizes.lg,
                        ),
                        itemCount: trips.length,
                        separatorBuilder: (_, _) =>
                            const SizedBox(height: AppSizes.sm),
                        itemBuilder: (context, i) => _TripTile(trip: trips[i]),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TripTile extends StatelessWidget {
  const _TripTile({required this.trip});

  final DriverJob trip;

  @override
  Widget build(BuildContext context) {
    return InfoCard(
      padding: 14,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${trip.pickup} → ${trip.destination}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyles.title,
                ),
              ),
              const SizedBox(width: AppSizes.sm),
              StatusPill(status: trip.status ?? 'completed'),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text(
                DateFormat('d MMM, h:mm a').format(
                  trip.completedAt ?? DateTime.now(),
                ),
                style: TextStyles.caption.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const Spacer(),
              Text(
                _tzs(trip.estimatedFareTzs),
                style: TextStyles.title.copyWith(color: AppColors.primaryDark),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
