import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/constants/app_colors.dart';
import '../../../../../core/constants/app_sizes.dart';
import '../../../../../core/theme/text_styles.dart';
import '../../../../../core/widgets/buttons/primary_button.dart';
import '../../../../../core/widgets/cards/info_card.dart';
import '../../../../phase9/presentation/phase9_screens.dart';
import '../../../providers/home_provider.dart';
import 'sheet_handle.dart';

/// In-transit sheet: destination + remaining distance + ETA.
class InTransitSheet extends ConsumerWidget {
  const InTransitSheet({super.key});

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
        Text('On the way', style: TextStyles.headline.copyWith(fontSize: 18)),
        const SizedBox(height: AppSizes.sm),
        InfoCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
              const SizedBox(height: AppSizes.sm),
              Text(
                '${job.distanceKm.toStringAsFixed(1)} km remaining · ETA 22 min',
                style: TextStyles.body.copyWith(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSizes.md),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            TextButton.icon(
              onPressed: () => shareTrip(context, ref, job.id),
              icon: const Icon(Icons.share_outlined),
              label: const Text('Share trip'),
            ),
            TextButton.icon(
              onPressed: () => raiseSos(context, ref, job.id),
              icon: const Icon(Icons.emergency_outlined, color: AppColors.error),
              label: const Text(
                'SOS',
                style: TextStyle(color: AppColors.error),
              ),
            ),
          ],
        ),
        PrimaryButton(
          label: 'Arrived at destination',
          icon: Icons.flag_rounded,
          onPressed: () => ref.read(homeProvider.notifier).advanceStage(),
        ),
        TextButton(
          onPressed: () => context.push('/support'),
          child: const Text('Problem / Support'),
        ),
      ],
    );
  }
}
