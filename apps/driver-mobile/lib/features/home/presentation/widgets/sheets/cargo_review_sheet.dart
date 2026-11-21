import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../../core/constants/app_colors.dart';
import '../../../../../core/constants/app_sizes.dart';
import '../../../../../core/theme/text_styles.dart';
import '../../../../../core/widgets/buttons/primary_button.dart';
import '../../../domain/entities/driver_job.dart';
import '../../../domain/entities/driver_status.dart';
import '../../../providers/cargo_photos_provider.dart';
import '../../../providers/home_provider.dart';

/// Opens the full cargo review: description, measurements and parcel photos.
///
/// The same sheet is used for an incoming offer (before accepting) and for an
/// active job (after accepting), so the driver sees exactly the same cargo
/// information at both points. Offer expiry remains controlled by the server.
Future<void> showCargoReviewSheet(
  BuildContext context,
  DriverJob job, {
  WidgetRef? ref,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => CargoReviewSheet(job: job),
  );
}

/// Detailed cargo review bottom sheet.
class CargoReviewSheet extends ConsumerWidget {
  const CargoReviewSheet({super.key, required this.job});

  final DriverJob job;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final home = ref.watch(homeProvider);
    final incoming =
        home.driverStatus == DriverStatus.incomingJob &&
        home.incomingJob?.id == job.id &&
        home.incomingJob?.offerId == job.offerId;
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
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
                        color: context.colors.onSurfaceVariant,
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
                    CargoPhotoStrip(job: job),
                    if (incoming) ...[
                      const SizedBox(height: AppSizes.md),
                      Text(
                        '${home.countdownSeconds} seconds left to accept',
                        style: TextStyles.caption.copyWith(
                          color: context.colors.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: AppSizes.sm),
                      PrimaryButton(
                        label: 'Accept job',
                        icon: Icons.check_rounded,
                        isLoading: home.isSubmitting,
                        onPressed: () async {
                          final offer = ref.read(homeProvider).incomingJob;
                          if (offer?.id != job.id ||
                              offer?.offerId != job.offerId) {
                            return;
                          }
                          await ref.read(homeProvider.notifier).acceptJob();
                          if (context.mounted &&
                              ref.read(homeProvider).driverStatus ==
                                  DriverStatus.headingToPickup) {
                            Navigator.of(context).pop();
                          }
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
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
    rows.add(('Photos', '${job.cargoPhotoPaths.length}'));

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
                      color: context.colors.onSurfaceVariant,
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

/// Swipe through parcel photos and tap one to open a zoomable preview.
class CargoPhotoStrip extends ConsumerWidget {
  const CargoPhotoStrip({super.key, required this.job, this.compact = false});

  final DriverJob job;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (job.cargoPhotoPaths.isEmpty) {
      return Text(
        'No parcel photos were added for this job.',
        style: TextStyles.body.copyWith(color: context.colors.onSurfaceVariant),
      );
    }
    final urls = ref.watch(
      cargoPhotoUrlsProvider(cargoPhotoKey(job.cargoPhotoPaths)),
    );
    final photos = urls.value ?? const <String>[];
    if (photos.isEmpty) {
      if (compact) return const SizedBox.shrink();
      if (urls.isLoading) {
        return const Padding(
          padding: EdgeInsets.all(AppSizes.lg),
          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
        );
      }
      return Text(
        'Photos are not available right now.',
        style: TextStyles.body.copyWith(color: context.colors.error),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        // Leave a glimpse of the next photo so the strip is visibly scrollable.
        final width = compact
            ? 72.0
            : constraints.maxWidth * (photos.length > 1 ? 0.9 : 1.0);
        final height = compact ? width : (width * 0.75).clamp(0.0, 300.0);
        return SizedBox(
          height: height,
          child: ListView.separated(
            key: PageStorageKey(job.id),
            scrollDirection: Axis.horizontal,
            itemCount: photos.length,
            separatorBuilder: (_, _) => const SizedBox(width: AppSizes.sm),
            itemBuilder: (context, index) => SizedBox(
              width: width,
              child: Semantics(
                button: true,
                label: 'Open cargo photo ${index + 1} of ${photos.length}',
                child: CargoThumbnail(
                  url: photos[index],
                  onTap: () => _openPhotoPreview(context, photos, index),
                ),
              ),
            ),
          ),
        );
      },
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
            color: context.colors.outlineVariant.withValues(alpha: 0.4),
            child: const Center(
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
          errorWidget: (_, _, _) => Container(
            color: context.colors.outlineVariant.withValues(alpha: 0.4),
            child: const Icon(Icons.broken_image_outlined),
          ),
        ),
      ),
    );
  }
}

void _openPhotoPreview(
  BuildContext context,
  List<String> urls,
  int initialIndex,
) {
  var current = initialIndex;
  showDialog<void>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setState) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.symmetric(
          horizontal: AppSizes.sm,
          vertical: AppSizes.xs,
        ),
        constraints: BoxConstraints.tightFor(
          width: double.infinity,
          height: MediaQuery.sizeOf(context).height * 0.5,
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            Positioned.fill(
              child: InteractiveViewer(
                key: ValueKey(current),
                child: CachedNetworkImage(
                  imageUrl: urls[current],
                  fit: BoxFit.cover,
                  placeholder: (_, _) => const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
                  errorWidget: (_, _, _) => const Center(
                    child: Icon(
                      Icons.broken_image_outlined,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
            IconButton(
              tooltip: 'Close photo',
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
                      tooltip: 'Previous photo',
                      onPressed: () =>
                          setState(() => current = (current - 1) % urls.length),
                      icon: const Icon(
                        Icons.arrow_back_ios,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      '${current + 1} / ${urls.length}',
                      style: TextStyles.body.copyWith(color: Colors.white),
                    ),
                    IconButton(
                      tooltip: 'Next photo',
                      onPressed: () =>
                          setState(() => current = (current + 1) % urls.length),
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
        color: context.colors.outlineVariant,
        borderRadius: BorderRadius.circular(999),
      ),
    );
  }
}
