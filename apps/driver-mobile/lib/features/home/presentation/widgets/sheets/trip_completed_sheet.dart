import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../../core/constants/app_colors.dart';
import '../../../../../core/constants/app_sizes.dart';
import '../../../../../core/theme/text_styles.dart';
import '../../../../../core/widgets/buttons/primary_button.dart';
import '../../../../../core/widgets/cards/info_card.dart';
import '../../../../../core/widgets/feedback/app_snackbar.dart';
import '../../../../../shared/mock/mock_earnings.dart';
import '../../../providers/home_provider.dart';
import 'sheet_handle.dart';

String _tzs(num amount) => 'TZS ${NumberFormat('#,##0').format(amount)}';

/// Trip-completed sheet: fare breakdown + rating prompt + go-back-online.
class TripCompletedSheet extends ConsumerStatefulWidget {
  const TripCompletedSheet({super.key});

  @override
  ConsumerState<TripCompletedSheet> createState() => _TripCompletedSheetState();
}

class _TripCompletedSheetState extends ConsumerState<TripCompletedSheet> {
  int _stars = 5;

  @override
  Widget build(BuildContext context) {
    final job = ref.watch(homeProvider).activeJob;
    if (job == null) return const SizedBox.shrink();
    final fare = job.estimatedFareTzs.toDouble();
    final commission = (fare * MockEarnings.commissionRate).round();
    final earnings = (fare - commission).round();
    final base = (fare * 0.3).round();
    final distance = (fare * 0.55).round();
    final time = (fare - base - distance).round();
    return ListView(
      shrinkWrap: true,
      physics: const ClampingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        AppSizes.lg,
        AppSizes.sm,
        AppSizes.lg,
        AppSizes.lg,
      ),
      children: [
        const SheetHandle(),
        const Center(
          child: Icon(
            Icons.check_circle_rounded,
            size: 56,
            color: AppColors.onlineGreen,
          ),
        ),
        const SizedBox(height: AppSizes.sm),
        const Center(child: Text('Trip completed', style: TextStyles.headline)),
        const SizedBox(height: AppSizes.md),
        InfoCard(
          child: Column(
            children: [
              _Row(label: 'Base fare', value: _tzs(base)),
              _Row(label: 'Distance', value: _tzs(distance)),
              _Row(label: 'Time', value: _tzs(time)),
              _Row(
                label:
                    'Commission (${(MockEarnings.commissionRate * 100).round()}%)',
                value: '− ${_tzs(commission)}',
              ),
              const Divider(height: AppSizes.lg),
              _Row(label: 'Your earnings', value: _tzs(earnings), isTotal: true),
            ],
          ),
        ),
        const SizedBox(height: AppSizes.md),
        Center(
          child: Text(
            'Rate ${job.customerName}',
            style: TextStyles.title,
          ),
        ),
        const SizedBox(height: AppSizes.xs),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            5,
            (i) => IconButton(
              onPressed: () => setState(() => _stars = i + 1),
              icon: const Icon(Icons.star_rounded),
              iconSize: 32,
              color: _stars > i
                  ? const Color(0xFFFFB300)
                  : AppColors.divider,
            ),
          ),
        ),
        const SizedBox(height: AppSizes.sm),
        PrimaryButton(
          label: 'Go back online',
          icon: Icons.bolt_rounded,
          onPressed: () => ref.read(homeProvider.notifier).goBackOnline(),
        ),
        TextButton(
          onPressed: () {
            AppSnackbar.showInfo(context, 'Trip receipt (mock)');
            context.push('/trips');
          },
          child: const Text('View trip details'),
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
