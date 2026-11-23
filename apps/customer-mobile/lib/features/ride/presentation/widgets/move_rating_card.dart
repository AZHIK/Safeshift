import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:safeshift_shared/safeshift_shared.dart';

import '../../../../core/network/supabase_client.dart';
import '../../../../core/widgets/buttons/primary_button.dart';
import '../../../../core/widgets/cards/info_card.dart';
import '../../providers/ride_provider.dart';

/// Rate the driver after delivery. Shared with history details.
class MoveRatingCard extends ConsumerWidget {
  const MoveRatingCard({super.key, required this.jobId, this.driverName});

  final String jobId;
  final String? driverName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(jobRatingProvider(jobId)).value;
    if (status == null || (!status.canRate && !status.rated)) {
      return const SizedBox.shrink();
    }
    final name = (driverName ?? '').trim();
    return InfoCard(
      child: RatingPanel(
        title: name.isEmpty ? 'How was your driver?' : 'How was $name?',
        subtitle: 'Your rating helps keep moves safe and on time.',
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
          ref.invalidate(jobRatingProvider(jobId));
        },
      ),
    );
  }
}
