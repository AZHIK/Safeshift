import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../../core/constants/app_colors.dart';
import '../../../../../core/constants/app_sizes.dart';
import '../../../../../core/theme/text_styles.dart';
import '../../../domain/entities/driver_job.dart';
import 'cargo_review_sheet.dart';

/// Compact summary of what is being moved: the customer's description, weight,
/// declared value, pickup schedule and the customer's parcel photos.
///
/// Used on the offer card (before accepting) and while heading to pickup, so
/// the driver knows whether the load fits the vehicle before committing.
/// Tapping the photos opens the full cargo review with every cargo field.
class LoadDetails extends ConsumerWidget {
  const LoadDetails({super.key, required this.job});

  final DriverJob job;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final description = job.cargoDescription?.trim();
    final chips = <Widget>[];

    final weight = job.cargoWeightKg;
    if (weight != null) {
      chips.add(
        _Chip(
          icon: Icons.scale_rounded,
          label: '${weight.toStringAsFixed(weight % 1 == 0 ? 0 : 1)} kg',
        ),
      );
    }

    final value = job.declaredValueTzs;
    if (value != null && value > 0) {
      chips.add(
        _Chip(
          icon: Icons.shield_outlined,
          label: 'Value TZS ${NumberFormat('#,##0').format(value)}',
        ),
      );
    }

    final photoCount = job.cargoPhotoPaths.length;
    if (photoCount > 0) {
      chips.add(
        _Chip(
          icon: Icons.photo_library_outlined,
          label: '$photoCount photo${photoCount == 1 ? '' : 's'}',
        ),
      );
    }

    final scheduled = job.scheduledAt;
    if (scheduled != null && scheduled.isAfter(DateTime.now())) {
      chips.add(
        _Chip(
          icon: Icons.schedule_rounded,
          label: DateFormat('EEE d MMM, h:mm a').format(scheduled.toLocal()),
        ),
      );
    }

    final hasDescription = description != null && description.isNotEmpty;
    if (!hasDescription && chips.isEmpty && photoCount == 0) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: AppSizes.lg),
        if (hasDescription)
          Text(
            description,
            style: TextStyles.body.copyWith(color: AppColors.textSecondary),
          ),
        if (hasDescription && chips.isNotEmpty)
          const SizedBox(height: AppSizes.sm),
        if (chips.isNotEmpty)
          Wrap(
            spacing: AppSizes.sm,
            runSpacing: AppSizes.xs,
            children: chips,
          ),
        if (photoCount > 0) ...[
          const SizedBox(height: AppSizes.sm),
          CargoPhotoStrip(job: job),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => showCargoReviewSheet(context, job, ref: ref),
              icon: const Icon(Icons.open_in_full_outlined, size: 16),
              label: const Text('Review cargo & photos'),
            ),
          ),
        ],
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.divider.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppColors.textSecondary),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyles.caption.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
