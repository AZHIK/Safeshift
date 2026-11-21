import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../../core/constants/app_colors.dart';
import '../../../../../core/constants/app_sizes.dart';
import '../../../../../core/theme/text_styles.dart';
import '../../../../../core/widgets/buttons/primary_button.dart';
import '../../../../../core/widgets/cards/info_card.dart';
import '../../../../../core/widgets/feedback/app_snackbar.dart';
import '../../../providers/home_provider.dart';
import '../../../data/driver_route_service.dart';
import 'load_details.dart';
import 'sheet_handle.dart';
import 'trip_problem_sheet.dart';

Future<void> _sendChatPhoto(
  BuildContext context,
  WidgetRef ref,
  String customerName,
) async {
  final picked = await ImagePicker().pickImage(
    source: ImageSource.gallery,
    imageQuality: 85,
    maxWidth: 2000,
  );
  if (picked == null) return;
  final ok = await ref
      .read(homeProvider.notifier)
      .sendChatAttachment(
        bytes: await picked.readAsBytes(),
        fileName: picked.name,
        mimeType: picked.mimeType ?? 'image/jpeg',
        caption: 'Photo from driver',
      );
  if (!context.mounted) return;
  if (ok) {
    AppSnackbar.showSuccess(context, 'Photo sent to $customerName.');
  } else {
    AppSnackbar.showError(
      context,
      ref.read(homeProvider).errorMessage ?? 'Could not send the photo.',
    );
  }
}

/// Heading-to-pickup sheet: customer card + ETA + primary action.
class HeadingToPickupSheet extends ConsumerWidget {
  const HeadingToPickupSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final home = ref.watch(homeProvider);
    final job = home.activeJob;
    if (job == null) return const SizedBox.shrink();
    final route = ref.watch(liveRouteProvider);
    final routeLabel = switch (route) {
      null => 'Waiting for GPS…',
      LiveRouteView(hasError: true) => 'Route to pickup unavailable',
      LiveRouteView(isLoading: true) => 'Calculating route to pickup…',
      _ =>
        'ETA ${route.durationMin} min · ${route.distanceKm.toStringAsFixed(1)} km',
    };
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
          'Heading to pickup',
          style: TextStyles.headline.copyWith(fontSize: 18),
        ),
        const SizedBox(height: AppSizes.sm),
        InfoCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: context.colors.primary.withValues(
                      alpha: 0.12,
                    ),
                    child: Text(
                      job.customerName.isNotEmpty
                          ? job.customerName[0].toUpperCase()
                          : '?',
                      style: TextStyles.title.copyWith(
                        color: context.colors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSizes.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(job.customerName, style: TextStyles.title),
                        Text(
                          routeLabel,
                          style: TextStyles.caption.copyWith(
                            color: context.colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Call customer',
                    onPressed: () => AppSnackbar.showInfo(
                      context,
                      'Calling ${job.customerName} is not available yet',
                    ),
                    icon: const Icon(Icons.call_outlined),
                  ),
                  IconButton(
                    tooltip: 'Message customer',
                    onPressed: () =>
                        _sendChatPhoto(context, ref, job.customerName),
                    icon: const Icon(Icons.chat_bubble_outline_rounded),
                  ),
                ],
              ),
              const Divider(height: AppSizes.lg),
              Row(
                children: [
                  Icon(
                    Icons.location_on_rounded,
                    size: 18,
                    color: context.colors.secondary,
                  ),
                  const SizedBox(width: AppSizes.sm),
                  Expanded(child: Text(job.pickup, style: TextStyles.body)),
                ],
              ),
              LoadDetails(job: job),
            ],
          ),
        ),
        const SizedBox(height: AppSizes.md),
        PrimaryButton(
          label: 'Arrived at pickup',
          icon: Icons.navigation_rounded,
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
