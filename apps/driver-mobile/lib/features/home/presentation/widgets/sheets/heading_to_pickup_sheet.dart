import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/constants/app_colors.dart';
import '../../../../../core/constants/app_sizes.dart';
import '../../../../../core/theme/text_styles.dart';
import '../../../../../core/widgets/buttons/primary_button.dart';
import '../../../../../core/widgets/cards/info_card.dart';
import '../../../../../core/widgets/feedback/app_snackbar.dart';
import '../../../providers/home_provider.dart';
import 'sheet_handle.dart';

/// Heading-to-pickup sheet: customer card + ETA + primary action.
class HeadingToPickupSheet extends ConsumerWidget {
  const HeadingToPickupSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final job = ref.watch(homeProvider).activeJob;
    if (job == null) return const SizedBox.shrink();
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
        Text('Heading to pickup', style: TextStyles.headline.copyWith(fontSize: 18)),
        const SizedBox(height: AppSizes.sm),
        InfoCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor:
                        AppColors.primary.withValues(alpha: 0.12),
                    child: Text(
                      job.customerName.isNotEmpty
                          ? job.customerName[0].toUpperCase()
                          : '?',
                      style: TextStyles.title.copyWith(
                        color: AppColors.primaryDark,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSizes.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(job.customerName, style: TextStyles.title),
                        Text(
                          'ETA 8 min · ${job.pickupDistanceKm.toStringAsFixed(1)} km',
                          style: TextStyles.caption.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Call customer',
                    onPressed: () => AppSnackbar.showInfo(
                      context,
                      'Calling ${job.customerName} (mock)',
                    ),
                    icon: const Icon(Icons.call_outlined),
                  ),
                  IconButton(
                    tooltip: 'Message customer',
                    onPressed: () => AppSnackbar.showInfo(
                      context,
                      'Messaging ${job.customerName} (mock)',
                    ),
                    icon: const Icon(Icons.chat_bubble_outline_rounded),
                  ),
                ],
              ),
              const Divider(height: AppSizes.lg),
              Row(
                children: [
                  const Icon(
                    Icons.location_on_rounded,
                    size: 18,
                    color: AppColors.onlineGreen,
                  ),
                  const SizedBox(width: AppSizes.sm),
                  Expanded(child: Text(job.pickup, style: TextStyles.body)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSizes.md),
        PrimaryButton(
          label: 'Arrived at pickup',
          icon: Icons.navigation_rounded,
          onPressed: () => ref.read(homeProvider.notifier).advanceStage(),
        ),
        TextButton(
          onPressed: () =>
              AppSnackbar.showInfo(context, 'Support contacted (mock)'),
          child: const Text('Problem / Support'),
        ),
      ],
    );
  }
}
