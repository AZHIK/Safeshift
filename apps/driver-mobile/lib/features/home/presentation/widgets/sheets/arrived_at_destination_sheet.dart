import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/config/mock_mode.dart';
import '../../../../../core/constants/app_colors.dart';
import '../../../../../core/constants/app_sizes.dart';
import '../../../../../core/theme/text_styles.dart';
import '../../../../../core/widgets/buttons/primary_button.dart';
import '../../../../../core/widgets/cards/info_card.dart';
import '../../../providers/home_provider.dart';
import 'sheet_handle.dart';

/// Arrived-at-destination confirmation sheet.
///
/// In real mode the driver must enter the 6-digit code shown in the customer
/// app. Verification happens server-side; the trip is only completed after a
/// successful check.
class ArrivedAtDestinationSheet extends ConsumerStatefulWidget {
  const ArrivedAtDestinationSheet({super.key});

  @override
  ConsumerState<ArrivedAtDestinationSheet> createState() =>
      _ArrivedAtDestinationSheetState();
}

class _ArrivedAtDestinationSheetState
    extends ConsumerState<ArrivedAtDestinationSheet> {
  final _code = TextEditingController();

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final home = ref.watch(homeProvider);
    final job = home.activeJob;
    if (job == null) return const SizedBox.shrink();
    final mock = ref.watch(mockEnabledProvider);

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
              Text(
                mock
                    ? 'Confirm handover with the customer, then complete the trip.'
                    : 'Ask the customer for the 6-digit delivery code shown in their app.',
                style: TextStyles.body,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSizes.md),
        if (!mock) ...[
          TextField(
            controller: _code,
            keyboardType: TextInputType.number,
            maxLength: 6,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w900,
              letterSpacing: 8,
            ),
            decoration: const InputDecoration(
              counterText: '',
              hintText: '000000',
            ),
          ),
          if (home.errorMessage != null) ...[
            const SizedBox(height: AppSizes.xs),
            Text(
              home.errorMessage!,
              style: TextStyles.caption.copyWith(color: AppColors.error),
            ),
          ],
          const SizedBox(height: AppSizes.sm),
        ],
        PrimaryButton(
          label: mock ? 'Complete trip' : 'Verify code & complete',
          icon: Icons.check_circle_rounded,
          isLoading: home.isSubmitting,
          onPressed: () {
            if (mock) {
              ref.read(homeProvider.notifier).advanceStage();
            } else {
              ref.read(homeProvider.notifier).verifyDeliveryOtp(_code.text);
            }
          },
        ),
      ],
    );
  }
}
