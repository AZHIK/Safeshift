import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:safeshift_shared/safeshift_shared.dart'
    show JobRatingStatus, RatingPanel, RatingRepository;

import '../../../../core/network/supabase_client.dart';
import '../../../../core/widgets/buttons/primary_button.dart';
import '../../../../core/widgets/cards/info_card.dart';

/// The driver's rating state for a finished job; null when it cannot be
/// loaded (the rating card is then not shown).
final driverJobRatingProvider = FutureProvider.autoDispose
    .family<JobRatingStatus?, String>((ref, jobId) async {
      try {
        return await RatingRepository(ref.watch(supabaseProvider))
            .status(jobId);
      } catch (_) {
        return null;
      }
    });

/// Rate the customer; optional, and possible later from trip details for
/// 7 days. Going back online does not wait for it.
class CustomerRatingCard extends ConsumerWidget {
  const CustomerRatingCard({
    super.key,
    required this.jobId,
    required this.customerName,
  });

  final String jobId;
  final String customerName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(driverJobRatingProvider(jobId)).value;
    if (status == null || (!status.canRate && !status.rated)) {
      return const SizedBox.shrink();
    }
    final name = customerName.trim();
    return InfoCard(
      child: RatingPanel(
        title: name.isEmpty ? 'Rate the customer' : 'How was $name?',
        subtitle: 'Helps other drivers know what to expect.',
        status: status,
        buttonBuilder: (label, onPressed, loading) => PrimaryButton(
          label: label,
          icon: Icons.star_rounded,
          isLoading: loading,
          onPressed: onPressed,
        ),
        onSubmit: (score, tags, comment) async {
          await RatingRepository(ref.read(supabaseProvider))
              .submit(jobId: jobId, score: score, tags: tags, comment: comment);
          ref.invalidate(driverJobRatingProvider(jobId));
        },
      ),
    );
  }
}
