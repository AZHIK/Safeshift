import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/constants/app_sizes.dart';
import '../../../../../core/theme/text_styles.dart';
import '../../../../../core/widgets/buttons/primary_button.dart';
import '../../../../../core/widgets/cards/info_card.dart';
import '../../../../../core/widgets/feedback/app_snackbar.dart';
import '../../../providers/home_provider.dart';
import 'sheet_handle.dart';

/// Arrived-at-pickup confirmation sheet.
class ArrivedAtPickupSheet extends ConsumerWidget {
  const ArrivedAtPickupSheet({super.key});

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
          'Arrived at pickup',
          style: TextStyles.headline.copyWith(fontSize: 18),
        ),
        const SizedBox(height: AppSizes.sm),
        InfoCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(job.pickup, style: TextStyles.title),
              const SizedBox(height: AppSizes.xs),
              Text(
                'Confirm you have met ${job.customerName} and are ready to load.',
                style: TextStyles.body,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSizes.md),
        PrimaryButton(
          label: 'Start trip',
          icon: Icons.play_arrow_rounded,
          onPressed: () => ref.read(homeProvider.notifier).advanceStage(),
        ),
        TextButton(
          onPressed: () => AppSnackbar.showInfo(
            context,
            'Support chat is not available yet',
          ),
          child: const Text('Problem / Support'),
        ),
      ],
    );
  }
}
