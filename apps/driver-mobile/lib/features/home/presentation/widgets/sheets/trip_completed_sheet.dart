import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../../core/constants/app_colors.dart';
import '../../../../../core/constants/app_sizes.dart';
import '../../../../../core/theme/text_styles.dart';
import '../../../../../core/widgets/buttons/primary_button.dart';
import '../../../../../core/widgets/cards/info_card.dart';
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
    final fare = job.estimatedFareTzs;
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
              _Row(label: 'Trip fare', value: _tzs(fare), isTotal: true),
              const SizedBox(height: AppSizes.sm),
              Text(
                'Your payout is recorded after the customer payment settles. '
                'Check Earnings for confirmed amounts.',
                textAlign: TextAlign.center,
                style: TextStyles.caption.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSizes.md),
        Center(
          child: Text('Rate ${job.customerName}', style: TextStyles.title),
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
              color: _stars > i ? const Color(0xFFFFB300) : AppColors.divider,
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
          onPressed: () => context.push('/trips'),
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
