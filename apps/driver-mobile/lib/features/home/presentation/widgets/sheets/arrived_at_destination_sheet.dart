import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/constants/app_sizes.dart';
import '../../../../../core/theme/text_styles.dart';
import '../../../../../core/widgets/buttons/primary_button.dart';
import '../../../../../core/widgets/cards/info_card.dart';
import '../../../providers/home_provider.dart';
import 'sheet_handle.dart';

/// Arrived-at-destination confirmation sheet.
class ArrivedAtDestinationSheet extends ConsumerWidget {
  const ArrivedAtDestinationSheet({super.key});

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
        Text(
          'Arrived at destination',
          style: TextStyles.headline.copyWith(fontSize: 18),
        ),
        const SizedBox(height: AppSizes.sm),
        InfoCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(job.destination, style: TextStyles.title),
              const SizedBox(height: AppSizes.xs),
              const Text(
                'Confirm handover with the customer, then complete the trip.',
                style: TextStyles.body,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSizes.md),
        PrimaryButton(
          label: 'Complete trip',
          icon: Icons.check_circle_rounded,
          onPressed: () => ref.read(homeProvider.notifier).advanceStage(),
        ),
      ],
    );
  }
}
