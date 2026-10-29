import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/errors/error_handler.dart';
import '../../../../core/theme/text_styles.dart';
import '../../../../core/widgets/buttons/primary_button.dart';
import '../../providers/history_provider.dart';
import '../widgets/history_job_tile.dart';

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});
  static const List<String> _filters = <String>[
    'All',
    'Completed',
    'Cancelled',
    'In Progress',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(historyFilterProvider);
    final jobsAsync = ref.watch(filteredHistoryProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('My Trips')),
      body: Column(
        children: <Widget>[
          SizedBox(
            height: 58,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSizes.lg,
                vertical: AppSizes.sm,
              ),
              scrollDirection: Axis.horizontal,
              itemCount: _filters.length,
              separatorBuilder: (_, _) => const SizedBox(width: AppSizes.sm),
              itemBuilder: (context, index) {
                final filter = _filters[index];
                final isSelected = selected == filter;
                return ChoiceChip(
                  label: Text(filter),
                  selected: isSelected,
                  showCheckmark: false,
                  selectedColor: AppColors.primary,
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                  onSelected: (_) =>
                      ref.read(historyFilterProvider.notifier).select(filter),
                );
              },
            ),
          ),
          Expanded(
            child: jobsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) {
                final failure = ErrorHandler.map(error, stackTrace: stack);
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSizes.xl),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        const Icon(
                          Icons.cloud_off_rounded,
                          size: 56,
                          color: AppColors.textDisabled,
                        ),
                        const SizedBox(height: AppSizes.md),
                        Text(
                          failure.message,
                          textAlign: TextAlign.center,
                          style: TextStyles.body,
                        ),
                        const SizedBox(height: AppSizes.md),
                        PrimaryButton(
                          label: 'Try again',
                          onPressed: () => ref
                              .read(historyProvider.notifier)
                              .refresh(),
                        ),
                      ],
                    ),
                  ),
                );
              },
              data: (jobs) => jobs.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSizes.xl),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            const Icon(
                              Icons.route_outlined,
                              size: 56,
                              color: AppColors.primary,
                            ),
                            const SizedBox(height: AppSizes.md),
                            Text(
                              'No trips yet',
                              style: TextStyles.title.copyWith(fontSize: 18),
                            ),
                            const SizedBox(height: AppSizes.md),
                            PrimaryButton(
                              label: 'Book your first move',
                              onPressed: () => context.push('/booking'),
                            ),
                          ],
                        ),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: () =>
                          ref.read(historyProvider.notifier).refresh(),
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(
                          AppSizes.lg,
                          AppSizes.xs,
                          AppSizes.lg,
                          AppSizes.lg,
                        ),
                        itemCount: jobs.length,
                        separatorBuilder: (_, _) =>
                            const SizedBox(height: AppSizes.sm),
                        itemBuilder: (context, index) => HistoryJobTile(
                          job: jobs[index],
                          onTap: () =>
                              context.push('/history/${jobs[index].id}'),
                        ),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
