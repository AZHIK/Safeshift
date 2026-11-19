import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../../core/constants/app_colors.dart';
import '../../../../../core/constants/app_sizes.dart';
import '../../../../../core/theme/text_styles.dart';
import '../../../domain/entities/driver_job.dart';
import '../../../domain/entities/driver_status.dart';
import '../../../providers/cargo_photos_provider.dart';
import '../../../providers/home_provider.dart';

/// Opens the full cargo review: description, measurements and parcel photos.
///
/// The same sheet is used for an incoming offer (before accepting) and for an
/// active job (after accepting), so the driver sees exactly the same cargo
/// information at both points. While an offer is open, the review pauses its
/// countdown so the driver cannot be timed out mid-inspection.
Future<void> showCargoReviewSheet(
  BuildContext context,
  DriverJob job, {
  WidgetRef? ref,
}) async {
  final reviewRef = ref;
  final holdNotifier =
      reviewRef != null &&
          reviewRef.read(homeProvider).driverStatus == DriverStatus.incomingJob
      ? reviewRef.read(offerReviewHoldProvider.notifier)
      : null;
  holdNotifier?.set(true);
  try {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CargoReviewSheet(job: job),
    );
  } finally {
    holdNotifier?.set(false);
  }
}

/// Detailed cargo review bottom sheet.
class CargoReviewSheet extends ConsumerWidget {
  const CargoReviewSheet({super.key, required this.job});

  final DriverJob job;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final urls = ref.watch(
      cargoPhotoUrlsProvider(cargoPhotoKey(job.cargoPhotoPaths)),
    );

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Center(child: CargoSheetHandle()),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSizes.lg,
                AppSizes.sm,
                AppSizes.lg,
                AppSizes.md,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Cargo details',
                    style: TextStyles.headline.copyWith(fontSize: 20),
                  ),
                  const SizedBox(height: AppSizes.xs),
                  Text(
                    'Review what the customer is sending before you commit.',
                    style: TextStyles.body.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSizes.md),
                  CargoInfo(job: job),
                  const SizedBox(height: AppSizes.md),
                  Text(
                    'Parcel photos',
                    style: TextStyles.title.copyWith(fontSize: 16),
                  ),
                  const SizedBox(height: AppSizes.sm),
                  CargoPhotoGrid(
                    job: job,
                    urls: urls.value ?? const <String>[],
                    loading: urls.isLoading,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Cargo facts shared by the inline summary and the full review sheet.
class CargoInfo extends StatelessWidget {
  const CargoInfo({super.key, required this.job});

  final DriverJob job;

  @override
  Widget build(BuildContext context) {
    final rows = <(String, String)>[];
    final description = job.cargoDescription?.trim();
    if (description != null && description.isNotEmpty) {
      rows.add(('Description', description));
    }
    rows.add(('Cargo', job.cargoClass));
    final weight = job.cargoWeightKg;
    if (weight != null) {
      rows.add((
        'Weight',
        '${weight.toStringAsFixed(weight % 1 == 0 ? 0 : 1)} kg',
      ));
    }
    final value = job.declaredValueTzs;
    if (value != null && value > 0) {
      rows.add((
        'Declared value',
        'TZS ${NumberFormat('#,##0').format(value)}',
      ));
    }
    final scheduled = job.scheduledAt;
    if (scheduled != null) {
      rows.add((
        'Pickup time',
        DateFormat('EEE d MMM, h:mm a').format(scheduled.toLocal()),
      ));
    }
    rows.add(( 'Photos', '${job.cargoPhotoPaths.length}'));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final row in rows)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSizes.sm),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 110,
                  child: Text(
                    row.$1,
                    style: TextStyles.caption.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                Expanded(child: Text(row.$2, style: TextStyles.body)),
              ],
            ),
          ),
      ],
    );
  }
}

/// A grid of tappable parcel thumbnails. Tapping opens a zoomable full view.
class CargoPhotoGrid extends StatelessWidget {
  const CargoPhotoGrid({
    super.key,
    required this.job,
    required this.urls,
    this.loading = false,
  });

  final DriverJob job;
  final List<String> urls;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    if (job.cargoPhotoPaths.isEmpty) {
      return Text(
        'No parcel photos were added for this job.',
        style: TextStyles.body.copyWith(color: AppColors.textSecondary),
      );
    }
    if (loading && urls.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(AppSizes.lg),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (urls.isEmpty) {
      return Text(
        'Photos are not available right now.',
        style: TextStyles.body.copyWith(color: AppColors.error),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: AppSizes.sm,
        mainAxisSpacing: AppSizes.sm,
      ),
      itemCount: urls.length,
      itemBuilder: (context, index) => CargoThumbnail(
        url: urls[index],
        onTap: () => _openFullPhoto(context, urls, index),
      ),
    );
  }
}

/// A compact strip used inside the offer card and the en-route sheet.
class CargoPhotoStrip extends ConsumerWidget {
  const CargoPhotoStrip({super.key, required this.job});

  final DriverJob job;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (job.cargoPhotoPaths.isEmpty) return const SizedBox.shrink();
    final urls = ref.watch(
      cargoPhotoUrlsProvider(cargoPhotoKey(job.cargoPhotoPaths)),
    );
    final photos = urls.value ?? const <String>[];
    if (photos.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 72,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: photos.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppSizes.sm),
        itemBuilder: (context, index) => CargoThumbnail(
          url: photos[index],
          onTap: () => _openFullPhoto(context, photos, index),
        ),
      ),
    );
  }
}

class CargoThumbnail extends StatelessWidget {
  const CargoThumbnail({super.key, required this.url, required this.onTap});

  final String url;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: CachedNetworkImage(
          imageUrl: url,
          fit: BoxFit.cover,
          placeholder: (_, _) => Container(
            color: AppColors.divider.withValues(alpha: 0.4),
            child: const Center(
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
          errorWidget: (_, _, _) => Container(
            color: AppColors.divider.withValues(alpha: 0.4),
            child: const Icon(Icons.broken_image_outlined),
          ),
        ),
      ),
    );
  }
}

void _openFullPhoto(BuildContext context, List<String> urls, int initialIndex) {
  var current = initialIndex;
  showDialog<void>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setState) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(AppSizes.sm),
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            Positioned.fill(
              child: InteractiveViewer(
                child: CachedNetworkImage(
                  imageUrl: urls[current],
                  fit: BoxFit.contain,
                  placeholder: (_, _) => const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
                  errorWidget: (_, _, _) => const Center(
                    child: Icon(Icons.broken_image_outlined, color: Colors.white),
                  ),
                ),
              ),
            ),
            IconButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              icon: const Icon(Icons.close_rounded, color: Colors.white),
            ),
            if (urls.length > 1)
              Positioned(
                bottom: AppSizes.sm,
                left: 0,
                right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      onPressed: () => setState(
                        () => current = (current - 1) % urls.length,
                      ),
                      icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
                    ),
                    Text(
                      '${current + 1} / ${urls.length}',
                      style: TextStyles.body.copyWith(color: Colors.white),
                    ),
                    IconButton(
                      onPressed: () => setState(
                        () => current = (current + 1) % urls.length,
                      ),
                      icon: const Icon(
                        Icons.arrow_forward_ios,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

class CargoSheetHandle extends StatelessWidget {
  const CargoSheetHandle({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 4,
      margin: const EdgeInsets.symmetric(vertical: AppSizes.sm),
      decoration: BoxDecoration(
        color: AppColors.divider,
        borderRadius: BorderRadius.circular(999),
      ),
    );
  }
}
