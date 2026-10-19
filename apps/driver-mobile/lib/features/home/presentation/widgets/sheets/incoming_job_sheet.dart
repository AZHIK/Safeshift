import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../../core/constants/app_colors.dart';
import '../../../../../core/constants/app_sizes.dart';
import '../../../../../core/theme/text_styles.dart';
import '../../../../../core/widgets/buttons/primary_button.dart';
import '../../../../../core/widgets/cards/info_card.dart';
import '../../../providers/home_provider.dart';
import 'sheet_handle.dart';

String _tzs(num amount) => 'TZS ${NumberFormat('#,##0').format(amount)}';

/// Full-height incoming-job request card with a 15s countdown ring.
class IncomingJobSheet extends ConsumerWidget {
  const IncomingJobSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final home = ref.watch(homeProvider);
    final job = home.incomingJob;
    if (job == null) {
      return const Padding(
        padding: EdgeInsets.all(AppSizes.lg),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    final progress = home.countdownSeconds / 15;
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
        Center(
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 72,
                height: 72,
                child: CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 6,
                  backgroundColor: AppColors.divider,
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    AppColors.onlineGreen,
                  ),
                ),
              ),
              Text(
                '${home.countdownSeconds}s',
                style: TextStyles.title.copyWith(fontSize: 16),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSizes.sm),
        Center(
          child: Text(
            'New job request · ${job.pickupDistanceKm.toStringAsFixed(1)} km away',
            style: TextStyles.body.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: AppSizes.md),
        InfoCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.location_on_rounded,
                    size: 18,
                    color: AppColors.onlineGreen,
                  ),
                  const SizedBox(width: AppSizes.sm),
                  Expanded(
                    child: Text(job.pickup, style: TextStyles.title),
                  ),
                ],
              ),
              const SizedBox(height: AppSizes.sm),
              Row(
                children: [
                  const Icon(
                    Icons.flag_rounded,
                    size: 18,
                    color: AppColors.error,
                  ),
                  const SizedBox(width: AppSizes.sm),
                  Expanded(
                    child: Text(job.destination, style: TextStyles.title),
                  ),
                ],
              ),
              const Divider(height: AppSizes.lg),
              Row(
                children: [
                  Expanded(
                    child: _Meta(label: 'Cargo', value: job.cargoClass),
                  ),
                  Expanded(
                    child: _Meta(
                      label: 'Trip',
                      value: '${job.distanceKm.toStringAsFixed(1)} km',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSizes.sm),
              Row(
                children: [
                  Expanded(
                    child: _Meta(label: 'Customer', value: job.customerName),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Estimated fare',
                          style: TextStyles.caption.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                        Text(
                          _tzs(job.estimatedFareTzs),
                          style: TextStyles.headline.copyWith(fontSize: 18),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSizes.md),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () =>
                    ref.read(homeProvider.notifier).declineJob(),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                child: const Text('Decline'),
              ),
            ),
            const SizedBox(width: AppSizes.md),
            Expanded(
              flex: 2,
              child: PrimaryButton(
                label: 'Accept',
                icon: Icons.check_rounded,
                onPressed: () =>
                    ref.read(homeProvider.notifier).acceptJob(),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyles.caption.copyWith(color: AppColors.textSecondary),
        ),
        Text(value, style: TextStyles.title),
      ],
    );
  }
}
