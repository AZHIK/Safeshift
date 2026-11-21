import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/constants/app_colors.dart';
import '../../../../../core/constants/app_sizes.dart';
import '../../../../../core/theme/text_styles.dart';
import '../../../../../core/widgets/buttons/primary_button.dart';
import '../../../../../core/widgets/cards/info_card.dart';
import '../../../../phase9/presentation/phase9_screens.dart';
import '../../../data/driver_route_service.dart';
import '../../../providers/home_provider.dart';
import '../../../providers/job_recipient_provider.dart';
import 'sheet_handle.dart';

/// In-transit sheet: destination + remaining distance + ETA.
class InTransitSheet extends ConsumerWidget {
  const InTransitSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final home = ref.watch(homeProvider);
    final job = home.activeJob;
    if (job == null) return const SizedBox.shrink();
    final recipient = home.isMockMode
        ? null
        : ref.watch(jobRecipientProvider(job.id)).value;
    final route = ref.watch(liveRouteProvider);
    final routeLabel = switch (route) {
      null => 'Waiting for GPS…',
      LiveRouteView(hasError: true) => 'Route to destination unavailable',
      LiveRouteView(isLoading: true) => 'Calculating route to destination…',
      _ =>
        '${route.distanceKm.toStringAsFixed(1)} km remaining · ETA ${route.durationMin} min',
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
        Text('On the way', style: TextStyles.headline.copyWith(fontSize: 18)),
        const SizedBox(height: AppSizes.sm),
        InfoCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.flag_rounded,
                    size: 18,
                    color: context.colors.error,
                  ),
                  const SizedBox(width: AppSizes.sm),
                  Expanded(
                    child: Text(job.destination, style: TextStyles.title),
                  ),
                ],
              ),
              const SizedBox(height: AppSizes.sm),
              Text(
                routeLabel,
                style: TextStyles.body.copyWith(
                  color: context.colors.onSurfaceVariant,
                ),
              ),
              if (recipient != null) ...[
                const SizedBox(height: AppSizes.sm),
                Row(
                  children: [
                    Icon(
                      Icons.person_pin_circle_outlined,
                      size: 18,
                      color: context.colors.primary,
                    ),
                    const SizedBox(width: AppSizes.sm),
                    Expanded(
                      child: Text(
                        'Deliver to ${recipient.name} · ${recipient.phone}',
                        style: TextStyles.body,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppSizes.md),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            TextButton.icon(
              onPressed: () => shareTrip(context, ref, job.id),
              icon: const Icon(Icons.share_outlined),
              label: const Text('Share trip'),
            ),
            TextButton.icon(
              onPressed: () => raiseSos(context, ref, job.id),
              icon: Icon(Icons.emergency_outlined, color: context.colors.error),
              label: Text('SOS', style: TextStyle(color: context.colors.error)),
            ),
          ],
        ),
        PrimaryButton(
          label: 'Arrived at destination',
          icon: Icons.flag_rounded,
          onPressed: () => ref.read(homeProvider.notifier).advanceStage(),
        ),
        TextButton(
          onPressed: () => context.push('/support'),
          child: const Text('Problem / Support'),
        ),
      ],
    );
  }
}
