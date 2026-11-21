import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/constants/app_colors.dart';
import '../../../../../core/constants/app_sizes.dart';
import '../../../../../core/theme/text_styles.dart';
import '../../../../../core/widgets/buttons/primary_button.dart';
import '../../../../../core/widgets/cards/info_card.dart';
import '../../../providers/home_provider.dart';
import 'cargo_review_sheet.dart';
import 'load_details.dart';
import 'sheet_handle.dart';
import 'trip_problem_sheet.dart';

/// Arrived-at-pickup confirmation sheet.
class ArrivedAtPickupSheet extends ConsumerWidget {
  const ArrivedAtPickupSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final home = ref.watch(homeProvider);
    final job = home.activeJob;
    final waitEnds = home.pickupFreeWaitEndsAt;
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
                'Confirm you have met ${job.customerName}, then check the '
                'cargo against the booking.',
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
        if (waitEnds != null) ...[
          const SizedBox(height: AppSizes.sm),
          _WaitCountdown(endsAt: waitEnds),
        ],
        const SizedBox(height: AppSizes.md),
        PrimaryButton(
          label: 'Verify cargo',
          icon: Icons.fact_check_rounded,
          onPressed: () => ref.read(homeProvider.notifier).advanceStage(),
        ),
        TextButton(
          onPressed: () => showTripProblemSheet(context),
          child: const Text('Problem / Support'),
        ),
      ],
    );
  }
}

/// Free waiting time left at the pickup. When it runs out the driver may
/// report a no-show from "Problem / Support".
class _WaitCountdown extends StatefulWidget {
  const _WaitCountdown({required this.endsAt});

  final DateTime endsAt;

  @override
  State<_WaitCountdown> createState() => _WaitCountdownState();
}

class _WaitCountdownState extends State<_WaitCountdown> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final left = widget.endsAt.difference(DateTime.now());
    final over = left.isNegative;
    final mm = left.inMinutes.remainder(60).toString().padLeft(2, '0');
    final ss = left.inSeconds.remainder(60).toString().padLeft(2, '0');
    return Row(
      children: [
        Icon(
          Icons.timer_outlined,
          size: 18,
          color: over ? context.colors.error : context.colors.primary,
        ),
        const SizedBox(width: AppSizes.xs),
        Expanded(
          child: Text(
            over
                ? 'Free waiting time is over. If the customer still has not '
                      'come, you can report a no-show under Problem / Support.'
                : 'Free waiting time left: $mm:$ss',
            style: TextStyles.body,
          ),
        ),
      ],
    );
  }
}
