import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/theme/text_styles.dart';
import '../../../../core/widgets/buttons/primary_button.dart';
import '../../../../core/widgets/cards/info_card.dart';
import '../../../../core/widgets/feedback/app_snackbar.dart';
import '../../../../shared/mock/mock_earnings.dart';
import '../../providers/earnings_provider.dart';
import '../widgets/earnings_chart.dart';
import '../widgets/earnings_stat_card.dart';

String _tzs(num amount) => 'TZS ${NumberFormat('#,##0').format(amount)}';

/// Pushed route: earnings dashboard with segment control + bar chart.
class EarningsScreen extends ConsumerWidget {
  const EarningsScreen({super.key});

  static const List<String> segments = <String>['Today', 'Week', 'Month'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final segment = ref.watch(earningsSegmentProvider);
    final notifier = ref.read(earningsSegmentProvider.notifier);
    final total = notifier.totalFor(segment);
    final trips = notifier.tripsFor(segment);
    return Scaffold(
      appBar: AppBar(title: const Text('Earnings')),
      body: ListView(
        padding: const EdgeInsets.all(AppSizes.lg),
        children: [
          InfoCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  segment == 'Today'
                      ? "Today's earnings"
                      : segment == 'Week'
                          ? "This week's earnings"
                          : "This month's earnings",
                  style: TextStyles.caption.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _tzs(total),
                  style: TextStyles.display.copyWith(fontSize: 32),
                ),
                const SizedBox(height: 4),
                Text(
                  '$trips trips',
                  style: TextStyles.body.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSizes.md),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'Today', label: Text('Today')),
              ButtonSegment(value: 'Week', label: Text('Week')),
              ButtonSegment(value: 'Month', label: Text('Month')),
            ],
            selected: {segment},
            onSelectionChanged: (s) => notifier.setSegment(s.first),
          ),
          const SizedBox(height: AppSizes.md),
          const InfoCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Last 7 days', style: TextStyles.title),
                SizedBox(height: AppSizes.md),
                SizedBox(height: 150, child: EarningsChart()),
              ],
            ),
          ),
          const SizedBox(height: AppSizes.md),
          Row(
            children: [
              EarningsStatCard(
                label: 'Net earnings',
                value: _tzs(
                  (total * (1 - MockEarnings.commissionRate)).round(),
                ),
                icon: Icons.account_balance_wallet_rounded,
              ),
              const SizedBox(width: AppSizes.sm),
              EarningsStatCard(
                label: 'Commission',
                value:
                    '${(MockEarnings.commissionRate * 100).round()}%',
                icon: Icons.percent_rounded,
              ),
            ],
          ),
          const SizedBox(height: AppSizes.md),
          PrimaryButton(
            label: 'Cash out',
            icon: Icons.payments_rounded,
            onPressed: () =>
                AppSnackbar.showInfo(context, 'Cash out requested (mock)'),
          ),
        ],
      ),
    );
  }
}
