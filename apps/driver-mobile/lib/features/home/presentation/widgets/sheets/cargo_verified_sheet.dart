import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/constants/app_sizes.dart';
import '../../../../../core/theme/text_styles.dart';
import '../../../../../core/widgets/buttons/primary_button.dart';
import '../../../../../core/widgets/cards/info_card.dart';
import '../../../providers/home_provider.dart';
import 'cargo_review_sheet.dart';
import 'load_details.dart';
import 'sheet_handle.dart';
import 'trip_problem_sheet.dart';

/// Confirmation that the driver checked the cargo at the pickup point.
class CargoVerifiedSheet extends ConsumerWidget {
  const CargoVerifiedSheet({super.key});

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
          'Cargo verified',
          style: TextStyles.headline.copyWith(fontSize: 18),
        ),
        const SizedBox(height: AppSizes.sm),
        InfoCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'The customer can see this step. Check the description, '
                'weight, value and photos before loading.',
                style: TextStyles.body,
              ),
              LoadDetails(job: job),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => showCargoReviewSheet(context, job, ref: ref),
                  icon: const Icon(Icons.inventory_2_outlined, size: 16),
                  label: const Text('Review cargo & photos'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSizes.md),
        PrimaryButton(
          label: 'Start loading',
          icon: Icons.inventory_2_outlined,
          onPressed: () => ref.read(homeProvider.notifier).advanceStage(),
        ),
        TextButton(
          onPressed: () => showTripProblemSheet(context),
          child: const Text('Problem with the cargo'),
        ),
      ],
    );
  }
}
