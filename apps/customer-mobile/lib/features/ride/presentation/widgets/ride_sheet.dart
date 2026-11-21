import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:safeshift_shared/safeshift_shared.dart';

import '../../../../core/config/env_config.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/buttons/primary_button.dart';
import '../../../../core/widgets/cards/info_card.dart';
import '../../../../core/widgets/sheets/address_suggestion_sheet.dart';
import '../../../../shared/models/ride_place.dart';
import '../../data/ride_repository.dart';
import '../../providers/ride_provider.dart';
import '../../../phase9/presentation/phase9_screens.dart';
import 'parcel_dialog.dart';
import 'payment_dialog.dart';

final _tzs = NumberFormat('#,##0');

/// Supabase project URL used to resolve the icons the catalogue serves.
final _iconBaseUrl = EnvConfig.current.supabaseUrl;

int? _totalFor(RideState ride, String? vehicleId) {
  if (vehicleId != null &&
      vehicleId == ride.vehicleClass?.id &&
      ride.quoteTotal != null) {
    return ride.quoteTotal!.round();
  }
  return null;
}

String _formatTzs(int? amount) {
  if (amount == null) return 'Get quote';
  return 'TZS ${_tzs.format(amount)}';
}

/// The morphing bottom sheet content. One widget, all stages.
class RideSheetBody extends ConsumerWidget {
  const RideSheetBody({super.key, required this.scrollController});

  final ScrollController scrollController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ride = ref.watch(rideProvider);
    final vehiclesAsync = ref.watch(rideVehicleTypesProvider);
    vehiclesAsync.whenData((vehicles) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(rideProvider.notifier).ensureVehicleSelected(vehicles);
      });
    });
    // Bottom inset = system gesture + nav height allowance so the
    // Confirm CTA is never hidden behind the bottom NavigationBar.
    final bottomInset =
        MediaQuery.paddingOf(context).bottom + kBottomNavigationBarHeight + 28;
    return ListView(
      controller: scrollController,
      padding: EdgeInsets.fromLTRB(18, 10, 18, bottomInset),
      children: [
        Center(
          child: Container(
            width: 44,
            height: 5,
            decoration: BoxDecoration(
              color: context.colors.outlineVariant,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
        ),
        const SizedBox(height: 12),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 280),
          child: switch (ride.stage) {
            RideStage.idle => const _IdleSearch(key: ValueKey('idle')),
            RideStage.route ||
            RideStage.vehicle ||
            RideStage.confirm => _RouteAndVehicles(
              key: const ValueKey('route'),
              vehiclesAsync: vehiclesAsync,
            ),
            RideStage.searching => const _SearchingView(
              key: ValueKey('searching'),
            ),
            RideStage.tracking => const _TrackingView(
              key: ValueKey('tracking'),
            ),
            RideStage.done => const _DoneView(key: ValueKey('done')),
          },
        ),
      ],
    );
  }
}

class _IdleSearch extends ConsumerWidget {
  const _IdleSearch({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ride = ref.watch(rideProvider);
    final notifier = ref.read(rideProvider.notifier);
    final savedPlacesAsync = ref.watch(rideSavedPlacesProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Karibu back', style: TextStyles.headline),
        const SizedBox(height: 4),
        Text(
          'Your next move, made easy.',
          style: TextStyles.body.copyWith(
            color: context.colors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 14),
        _RouteInputs(
          onPickup: () => showAddressSuggestionSheet(
            context: context,
            title: 'Choose pickup',
            hintText: 'Search pickup location',
            onSelected: notifier.setPickup,
          ),
          onDestination: () => showAddressSuggestionSheet(
            context: context,
            title: 'Where to?',
            hintText: 'Search destination',
            onSelected: notifier.setDestination,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Saved places',
          style: TextStyles.caption.copyWith(
            color: context.colors.onSurfaceVariant,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 8),
        savedPlacesAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          ),
          error: (_, _) => Text(
            'Could not load saved places.',
            style: TextStyles.caption.copyWith(
              color: context.colors.onSurfaceVariant,
            ),
          ),
          data: (places) => places.isEmpty
              ? Text(
                  'Save addresses in your profile to use them here.',
                  style: TextStyles.caption.copyWith(
                    color: context.colors.onSurfaceVariant,
                  ),
                )
              : Column(
                  children: [
                    for (final place in places.take(5)) ...[
                      _SavedPlaceTile(
                        icon: _savedPlaceIcon(place),
                        title: place.label?.isNotEmpty == true
                            ? place.label!
                            : place.name,
                        subtitle: place.district.isNotEmpty
                            ? place.district
                            : place.name,
                        onTap: () => notifier.setDestination(place),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ],
                ),
        ),
        if (ride.hasRoute) ...[
          const SizedBox(height: 14),
          PrimaryButton(
            label: 'See vehicles',
            icon: Icons.arrow_forward_rounded,
            onPressed: () => notifier.backToRoute(),
          ),
        ],
      ],
    );
  }
}

IconData _savedPlaceIcon(RidePlace place) {
  final label = (place.label ?? '').toLowerCase();
  if (label.contains('home')) return Icons.home_rounded;
  if (label.contains('work') || label.contains('office')) {
    return Icons.work_rounded;
  }
  if (label.contains('airport')) return Icons.flight_rounded;
  return Icons.place_rounded;
}

class _RouteAndVehicles extends ConsumerWidget {
  const _RouteAndVehicles({super.key, required this.vehiclesAsync});
  final AsyncValue<List<VehicleTypeOption>> vehiclesAsync;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ride = ref.watch(rideProvider);
    final notifier = ref.read(rideProvider.notifier);
    final cargoAsync = ref.watch(rideCargoTypesProvider);
    final total = _totalFor(ride, ride.vehicleClass?.id);
    final pickup = ride.pickup;
    // Polls every 25 s while this picker is on screen; stops when it closes.
    final availability = pickup == null
        ? null
        : ref.watch(vehicleAvailabilityProvider(pickupPointOf(pickup))).value;
    final selectedAvailability = availability == null
        ? null
        : (availability[ride.vehicleClass?.id] ??
              VehicleAvailability.unavailable);
    final scheduledLater =
        ride.scheduledAt != null &&
        ride.scheduledAt!.isAfter(
          DateTime.now().add(const Duration(minutes: 45)),
        );
    final mustSchedule =
        ride.vehicleClass != null &&
        (selectedAvailability?.isNone ?? false) &&
        !scheduledLater;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _RouteInputs(
          onPickup: () => showAddressSuggestionSheet(
            context: context,
            title: 'Choose pickup',
            hintText: 'Search pickup location',
            onSelected: notifier.setPickup,
          ),
          onDestination: () => showAddressSuggestionSheet(
            context: context,
            title: 'Where to?',
            hintText: 'Search destination',
            onSelected: notifier.setDestination,
          ),
          showSwap: true,
        ),
        const SizedBox(height: 14),
        Text(
          'What are you moving?',
          style: TextStyles.title.copyWith(fontSize: 15),
        ),
        const SizedBox(height: 2),
        Text(
          'Cargo type + parcel details help us size the vehicle.',
          style: TextStyles.caption.copyWith(
            color: context.colors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 10),
        cargoAsync.when(
          loading: () => const SizedBox(
            height: 38,
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          ),
          error: (_, _) => Text(
            'Could not load cargo types.',
            style: TextStyles.caption.copyWith(
              color: context.colors.onSurfaceVariant,
            ),
          ),
          data: (cargoTypes) => cargoTypes.isEmpty
              ? const CatalogEmptyNotice(kind: CatalogKind.cargo)
              : SizedBox(
                  height: 38,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: cargoTypes.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (context, i) {
                      final c = cargoTypes[i];
                      final sel = c.id == ride.cargo?.id;
                      return ChoiceChip(
                        label: Text(c.name),
                        avatar: CatalogIcon(
                          iconUrl: c.iconUrl,
                          supabaseUrl: _iconBaseUrl,
                          fallbackIcon: Icons.category_rounded,
                          size: 16,
                          color: sel
                              ? context.colors.onPrimary
                              : context.colors.onSurfaceVariant,
                        ),
                        selected: sel,
                        showCheckmark: false,
                        selectedColor: context.colors.primary,
                        labelStyle: TextStyle(
                          color: sel
                              ? context.colors.onPrimary
                              : context.colors.onSurface,
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                        ),
                        onSelected: (_) => notifier.selectCargo(c),
                      );
                    },
                  ),
                ),
        ),
        const SizedBox(height: 10),
        _ParcelCard(onTap: () => showParcelDialog(context, ref)),
        const SizedBox(height: 10),
        const _RecipientCard(),
        const SizedBox(height: 16),
        if (!ride.hasRequiredParcelDetails) ...[
          InfoCard(
            child: Row(
              children: [
                Icon(
                  Icons.inventory_2_outlined,
                  color: context.colors.onSurfaceVariant,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Describe your parcel (value + at least one photo) to see '
                    'vehicles and a price.',
                    style: TextStyles.caption.copyWith(
                      color: context.colors.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ] else ...[
          Row(
            children: [
              Text(
                'Choose a vehicle',
                style: TextStyles.title.copyWith(fontSize: 15),
              ),
              const Spacer(),
              _SchedulePill(),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Sized from your route + parcel above.',
            style: TextStyles.caption.copyWith(
              color: context.colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 10),
          vehiclesAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => Text(
              'Could not load vehicle types.',
              style: TextStyles.caption.copyWith(color: context.colors.error),
            ),
            data: (vehicles) {
              final compatible = vehicles
                  .where(
                    (v) => canVehicleCarryCargo(
                      v,
                      ride.cargo,
                      ride.parcelWeightKg,
                    ),
                  )
                  .toList(growable: false);
              WidgetsBinding.instance.addPostFrameCallback((_) {
                ref
                    .read(rideProvider.notifier)
                    .applyVehicleAvailability(availability, compatible);
              });
              // Available first, then busy, then none; catalogue order
              // (smallest first) within each group.
              final ordered = availability == null
                  ? compatible
                  : ([...compatible.indexed]..sort((a, b) {
                          int rank(VehicleTypeOption v) =>
                              (availability[v.id] ??
                                      VehicleAvailability.unavailable)
                                  .rank;
                          final byRank = rank(a.$2).compareTo(rank(b.$2));
                          return byRank != 0 ? byRank : a.$1.compareTo(b.$1);
                        }))
                        .map((e) => e.$2)
                        .toList(growable: false);
              return compatible.isEmpty
                  ? const CatalogEmptyNotice(kind: CatalogKind.vehicles)
                  : Column(
                      children: [
                        for (final v in ordered)
                          _VehicleTile(
                            vehicle: v,
                            availability: availability == null
                                ? null
                                : (availability[v.id] ??
                                      VehicleAvailability.unavailable),
                            selected: v.id == ride.vehicleClass?.id,
                            price: _totalFor(ride, v.id),
                            onTap: () => notifier.selectVehicle(v),
                          ),
                      ],
                    );
            },
          ),
          const SizedBox(height: 12),
          // Quote preview (shown once the parcel is described).
          InfoCard(
            selected: true,
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.lime.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '${ride.distanceKm.toStringAsFixed(1)} km · ${ride.durationMin} min',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      _formatTzs(total),
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    CatalogIcon(
                      iconUrl: ride.vehicleClass?.iconUrl,
                      supabaseUrl: _iconBaseUrl,
                      fallbackIcon: Icons.local_shipping_outlined,
                      size: 16,
                      color: context.colors.onSurfaceVariant,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '${ride.vehicleClass?.name ?? 'Vehicle'} · ${ride.vehicleClass?.capacityLabel ?? ''} · ${ride.scheduledLabel}',
                        style: TextStyles.caption.copyWith(
                          color: context.colors.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
                if (ride.hasParcelDetails) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(
                        Icons.inventory_2_outlined,
                        size: 14,
                        color: context.colors.onSurfaceVariant,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          [
                            if ((ride.parcelDescription ?? '')
                                .trim()
                                .isNotEmpty)
                              ride.parcelDescription!.trim().length > 36
                                  ? '${ride.parcelDescription!.trim().substring(0, 36)}…'
                                  : ride.parcelDescription!.trim(),
                            if (ride.parcelWeightKg != null)
                              '${ride.parcelWeightKg!.toStringAsFixed(ride.parcelWeightKg! % 1 == 0 ? 0 : 1)} kg',
                            if (ride.parcelValueTzs != null)
                              'TZS ${_tzs.format(ride.parcelValueTzs!)}',
                            if (ride.parcelPhotoPaths.isNotEmpty)
                              '${ride.parcelPhotoPaths.length} photos',
                          ].join(' · '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyles.caption.copyWith(
                            color: context.colors.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
        if (ride.isQuoting)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: LinearProgressIndicator(minHeight: 3),
          ),
        if (ride.isRouting)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: LinearProgressIndicator(minHeight: 3),
          ),
        if (ride.routeError != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              ride.routeError!,
              style: TextStyles.caption.copyWith(color: context.colors.error),
            ),
          ),
        if (ride.errorMessage != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              ride.errorMessage!,
              style: TextStyles.caption.copyWith(color: context.colors.error),
            ),
          ),
        const SizedBox(height: 12),
        _PaymentTile(onTap: () => showPaymentDialog(context)),
        const SizedBox(height: 12),
        if (mustSchedule)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              'No ${ride.vehicleClass!.name} drivers are near your pickup '
              'right now. Schedule it for later or choose another vehicle.',
              style: TextStyles.caption.copyWith(
                color: context.colors.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        PrimaryButton(
          label: mustSchedule
              ? 'Schedule this move'
              : total == null
              ? 'Confirm Move'
              : 'Confirm Move · TZS ${_tzs.format(total)}',
          icon: mustSchedule ? Icons.schedule_rounded : Icons.bolt_rounded,
          isLoading: ride.isSubmitting || ride.isQuoting,
          onPressed:
              ride.hasRoute &&
                  !ride.isQuoting &&
                  ride.vehicleClass != null &&
                  ride.parcelValueTzs != null &&
                  ride.parcelValueTzs! > 0 &&
                  ride.parcelPhotoPaths.isNotEmpty
              ? (mustSchedule
                    ? () => _SchedulePill.pick(context, ref)
                    : () => ref
                          .read(rideProvider.notifier)
                          .confirmAndFindDriver())
              : null,
        ),
        const SizedBox(height: 4),
        Center(
          child: Text(
            'Final price may adjust if cargo changes',
            style: TextStyles.caption.copyWith(
              color: context.colors.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

/// Bolt-like payment row (mock UI only). Opens dialog, no new screen.
class _PaymentTile extends ConsumerWidget {
  const _PaymentTile({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final method = ref.watch(rideProvider).paymentMethod;
    final tint = method.iconColor(Theme.of(context).brightness);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: InfoCard(
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: tint.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(method.icon, color: tint),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Payment · mock, no charge',
                    style: TextStyle(
                      fontSize: 10,
                      color: context.colors.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          method.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(context).scaffoldBackgroundColor,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          'Change',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: context.colors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.chevron_right_rounded,
              color: context.colors.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

class _RouteInputs extends ConsumerWidget {
  const _RouteInputs({
    required this.onPickup,
    required this.onDestination,
    this.showSwap = false,
  });
  final VoidCallback onPickup;
  final VoidCallback onDestination;
  final bool showSwap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ride = ref.watch(rideProvider);
    return Container(
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.colors.outlineVariant),
        boxShadow: AppColors.cardShadow,
      ),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          const SizedBox(width: 6),
          Column(
            children: [
              Icon(
                Icons.trip_origin_rounded,
                color: context.colors.secondary,
                size: 26,
              ),
              const SizedBox(
                height: 30,
                child: VerticalDivider(width: 2, thickness: 2),
              ),
              Icon(
                Icons.location_on_rounded,
                color: context.colors.error,
                size: 26,
              ),
            ],
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              children: [
                _InputRow(
                  hint: 'Pickup location',
                  value: ride.pickup?.name,
                  onTap: onPickup,
                ),
                const Divider(height: 12),
                _InputRow(
                  hint: 'Where to?',
                  value: ride.destination?.name,
                  onTap: onDestination,
                ),
              ],
            ),
          ),
          if (showSwap)
            IconButton(
              onPressed: () => ref.read(rideProvider.notifier).swap(),
              icon: const Icon(Icons.swap_vert_rounded, size: 22),
              style: IconButton.styleFrom(
                backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                minimumSize: const Size(48, 48),
              ),
            ),
        ],
      ),
    );
  }
}

class _InputRow extends StatelessWidget {
  const _InputRow({required this.hint, this.value, required this.onTap});
  final String hint;
  final String? value;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(12),
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              value ?? hint,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: value == null ? FontWeight.w400 : FontWeight.w700,
                color: value == null
                    ? context.colors.onSurfaceVariant
                    : context.colors.onSurface,
              ),
            ),
          ),
          Icon(
            Icons.search_rounded,
            size: 20,
            color: context.colors.onSurfaceVariant,
          ),
        ],
      ),
    ),
  );
}

class _SavedPlaceTile extends StatelessWidget {
  const _SavedPlaceTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: context.colors.surface,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(18),
      side: BorderSide(color: context.colors.outlineVariant),
    ),
    elevation: 2,
    shadowColor: const Color(0x144E5E73),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, size: 26, color: context.colors.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: context.colors.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: context.colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: context.colors.onSurfaceVariant,
            ),
          ],
        ),
      ),
    ),
  );
}

class _VehicleTile extends StatelessWidget {
  const _VehicleTile({
    required this.vehicle,
    required this.availability,
    required this.selected,
    required this.price,
    required this.onTap,
  });
  final VehicleTypeOption vehicle;

  /// Null while unknown; then no availability line is shown.
  final VehicleAvailability? availability;
  final bool selected;
  final int? price;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Opacity(
      // Still tappable: the customer can choose it and schedule for later.
      opacity: (availability?.isNone ?? false) && !selected ? 0.55 : 1,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: selected ? AppColors.brandGradient : null,
            color: selected ? null : context.colors.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected
                  ? Colors.transparent
                  : context.colors.outlineVariant,
            ),
            boxShadow: AppColors.cardShadow,
          ),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: selected
                      ? Colors.white.withValues(alpha: 0.22)
                      : Theme.of(context).scaffoldBackgroundColor,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: CatalogIcon(
                  iconUrl: vehicle.iconUrl,
                  supabaseUrl: _iconBaseUrl,
                  fallbackIcon: Icons.local_shipping_outlined,
                  color: selected ? Colors.white : context.colors.primary,
                  size: 28,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      vehicle.name,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        color: selected
                            ? Colors.white
                            : context.colors.onSurface,
                      ),
                    ),
                    Text(
                      vehicle.description.isNotEmpty
                          ? '${vehicle.capacityLabel} · ${vehicle.description}'
                          : vehicle.capacityLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: selected
                            ? Colors.white.withValues(alpha: 0.85)
                            : context.colors.onSurfaceVariant,
                      ),
                    ),
                    if (availability != null)
                      _AvailabilityLine(
                        availability: availability!,
                        onBrand: selected,
                      ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _formatTzs(price),
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                      color: selected ? Colors.white : context.colors.onSurface,
                    ),
                  ),
                  Text(
                    selected ? 'Selected' : vehicle.capacityLabel,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: selected
                          ? AppColors.lime
                          : context.colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// "≈ 4 min away", "Busy · may take longer" or "None nearby · schedule".
class _AvailabilityLine extends StatelessWidget {
  const _AvailabilityLine({required this.availability, required this.onBrand});

  final VehicleAvailability availability;
  final bool onBrand;

  @override
  Widget build(BuildContext context) {
    final (label, icon, tone) = switch (availability.status) {
      VehicleAvailabilityStatus.available => (
        availability.etaMin == null
            ? 'Drivers nearby'
            : '≈ ${availability.etaMin} min away',
        Icons.bolt_rounded,
        context.colors.secondary,
      ),
      VehicleAvailabilityStatus.limited => (
        'Busy · may take longer',
        Icons.hourglass_bottom_rounded,
        context.colors.tertiary,
      ),
      VehicleAvailabilityStatus.none => (
        'None nearby now · schedule',
        Icons.schedule_rounded,
        context.colors.onSurfaceVariant,
      ),
    };
    final color = onBrand ? AppColors.lime : tone;
    return Padding(
      padding: const EdgeInsets.only(top: 3),
      child: Row(
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Parcel summary card — opens the dialog, never a new screen.
class _ParcelCard extends ConsumerWidget {
  const _ParcelCard({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ride = ref.watch(rideProvider);
    final done = ride.hasParcelDetails;
    final subtitle = done
        ? [
            if ((ride.parcelDescription ?? '').trim().isNotEmpty)
              ride.parcelDescription!.trim().length > 42
                  ? '${ride.parcelDescription!.trim().substring(0, 42)}…'
                  : ride.parcelDescription!.trim(),
            if (ride.parcelWeightKg != null)
              '${ride.parcelWeightKg!.toStringAsFixed(ride.parcelWeightKg! % 1 == 0 ? 0 : 1)} kg',
            if (ride.parcelValueTzs != null)
              'TZS ${_tzs.format(ride.parcelValueTzs!)}',
            if (ride.parcelPhotoPaths.isNotEmpty)
              '${ride.parcelPhotoPaths.length} photo${ride.parcelPhotoPaths.length > 1 ? 's' : ''}',
          ].join(' · ')
        : 'Photos, weight & approx. value — helps driver prepare';
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: InfoCard(
        selected: done,
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                gradient: done ? AppColors.brandGradient : null,
                color: done ? null : Theme.of(context).scaffoldBackgroundColor,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                done ? Icons.check_rounded : Icons.inventory_2_outlined,
                color: done ? Colors.white : context.colors.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Describe your parcel',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      if (done)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: context.colors.secondaryContainer,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            'ADDED',
                            style: TextStyle(
                              fontSize: 8,
                              fontWeight: FontWeight.w800,
                              color: context.colors.onSecondaryContainer,
                              letterSpacing: 0.6,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyles.caption.copyWith(
                      color: context.colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: context.colors.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

class _SchedulePill extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ride = ref.watch(rideProvider);
    final label = ride.scheduledLabel;
    final foreground = ride.isScheduled
        ? context.colors.onPrimary
        : context.colors.onSurfaceVariant;
    return InkWell(
      onTap: () => pick(context, ref),
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: ride.isScheduled
              ? context.colors.primary
              : context.colors.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.schedule_rounded, size: 14, color: foreground),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: foreground,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Opens the pickup-time chooser. Also used by the Confirm button when no
  /// driver of the chosen vehicle is nearby.
  static Future<void> pick(BuildContext context, WidgetRef ref) async {
    final notifier = ref.read(rideProvider.notifier);
    final current = ref.read(rideProvider).scheduledAt;
    final now = DateTime.now();
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.bolt_rounded),
              title: const Text('Now'),
              trailing: current == null
                  ? Icon(Icons.check_rounded, color: context.colors.primary)
                  : null,
              onTap: () => Navigator.pop(context, 'now'),
            ),
            ListTile(
              leading: const Icon(Icons.schedule_rounded),
              title: const Text('In 1 hour'),
              onTap: () => Navigator.pop(context, 'hour'),
            ),
            ListTile(
              leading: const Icon(Icons.calendar_month_rounded),
              title: Text(
                current == null ? 'Choose date & time' : 'Change date & time',
              ),
              onTap: () => Navigator.pop(context, 'pick'),
            ),
            if (current != null)
              ListTile(
                leading: const Icon(Icons.close_rounded),
                title: const Text('Clear schedule'),
                onTap: () => Navigator.pop(context, 'clear'),
              ),
          ],
        ),
      ),
    );
    if (choice == null) return;

    switch (choice) {
      case 'now':
      case 'clear':
        notifier.setScheduledAt(null);
        return;
      case 'hour':
        notifier.setScheduledAt(now.add(const Duration(hours: 1)));
        return;
      case 'pick':
        if (!context.mounted) return;
        final initial = current ?? now.add(const Duration(hours: 1));
        final date = await showDatePicker(
          context: context,
          initialDate: initial,
          firstDate: DateUtils.dateOnly(now),
          lastDate: DateUtils.dateOnly(now.add(const Duration(days: 60))),
          helpText: 'Pickup date',
        );
        if (date == null || !context.mounted) return;
        final time = await showTimePicker(
          context: context,
          initialTime: TimeOfDay.fromDateTime(initial),
          helpText: 'Pickup time',
        );
        if (time == null || !context.mounted) return;
        final at = DateTime(
          date.year,
          date.month,
          date.day,
          time.hour,
          time.minute,
        );
        if (at.isBefore(DateTime.now())) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Choose a pickup time in the future.'),
            ),
          );
          return;
        }
        notifier.setScheduledAt(at);
        return;
    }
  }
}

class _SearchingView extends ConsumerStatefulWidget {
  const _SearchingView({super.key});
  @override
  ConsumerState<_SearchingView> createState() => _SearchingViewState();
}

class _SearchingViewState extends ConsumerState<_SearchingView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ride = ref.watch(rideProvider);
    final scheduledLater =
        ride.scheduledAt != null &&
        ride.scheduledAt!.isAfter(
          DateTime.now().add(const Duration(minutes: 45)),
        );
    return Column(
      children: [
        const SizedBox(height: 8),
        SizedBox(
          height: 140,
          width: 140,
          child: AnimatedBuilder(
            animation: _c,
            builder: (_, _) => Stack(
              alignment: Alignment.center,
              children: [
                for (var i = 0; i < 3; i++)
                  Container(
                    width: 60 + ((_c.value + i / 3) % 1) * 80,
                    height: 60 + ((_c.value + i / 3) % 1) * 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: context.colors.primary.withValues(
                        alpha: (0.28 * (1 - ((_c.value + i / 3) % 1))).clamp(
                          0.0,
                          0.3,
                        ),
                      ),
                    ),
                  ),
                Container(
                  width: 72,
                  height: 72,
                  decoration: const BoxDecoration(
                    gradient: AppColors.brandGradient,
                    shape: BoxShape.circle,
                    boxShadow: AppColors.glowShadow,
                  ),
                  child: const Icon(
                    Icons.local_shipping_rounded,
                    color: Colors.white,
                    size: 34,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          scheduledLater ? 'Move scheduled' : 'Finding nearby drivers…',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        Text(
          scheduledLater
              ? 'We will start searching 45 minutes before pickup'
              : 'Looking for verified vehicles near your pickup',
          textAlign: TextAlign.center,
          style: TextStyles.body.copyWith(
            color: context.colors.onSurfaceVariant,
          ),
        ),
        if (ride.isUploadingPhotos) ...[
          const SizedBox(height: 10),
          const LinearProgressIndicator(minHeight: 3),
          const SizedBox(height: 4),
          Text(
            'Uploading parcel photos…',
            style: TextStyles.caption.copyWith(
              color: context.colors.onSurfaceVariant,
            ),
          ),
        ],
        if (ride.errorMessage != null) ...[
          const SizedBox(height: 10),
          Text(
            ride.errorMessage!,
            textAlign: TextAlign.center,
            style: TextStyles.caption.copyWith(
              color: scheduledLater
                  ? context.colors.onSurfaceVariant
                  : context.colors.error,
            ),
          ),
          if (!scheduledLater && ride.alternativeVehicles.isNotEmpty) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Available now',
                style: TextStyles.caption.copyWith(
                  fontWeight: FontWeight.w800,
                  color: context.colors.onSurface,
                ),
              ),
            ),
            const SizedBox(height: 6),
            for (final option in ride.alternativeVehicles)
              _AlternativeVehicleTile(
                option: option,
                enabled: !ride.isSubmitting,
                onTap: () => _confirmSwitch(context, option.vehicle),
              ),
          ],
          if (!scheduledLater) ...[
            const SizedBox(height: 8),
            PrimaryButton(
              label: 'Try again',
              icon: Icons.refresh_rounded,
              isLoading: ride.isSubmitting,
              onPressed: () => ref.read(rideProvider.notifier).retryDispatch(),
            ),
          ],
        ],
        const SizedBox(height: 14),
        OutlinedButton(
          onPressed: () => ref.read(rideProvider.notifier).cancelSearch(),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: const Text('Cancel request'),
        ),
      ],
    );
  }
}

extension on _SearchingViewState {
  Future<void> _confirmSwitch(
    BuildContext context,
    VehicleTypeOption vehicle,
  ) async {
    final current = ref.read(rideProvider).vehicleClass;
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Switch to ${vehicle.name}?'),
        content: Text(
          'We will cancel the ${current?.name ?? 'current'} request at no '
          'charge and look for a ${vehicle.name} instead. The price will be '
          'recalculated for the new vehicle.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Keep waiting'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Switch'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await ref.read(rideProvider.notifier).switchVehicleAndRedispatch(vehicle);
  }
}

class _AlternativeVehicleTile extends StatelessWidget {
  const _AlternativeVehicleTile({
    required this.option,
    required this.enabled,
    required this.onTap,
  });

  final AlternativeVehicle option;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final vehicle = option.vehicle;
    final drivers = option.driverCount;
    final subtitle = [
      if (vehicle.capacityLabel.isNotEmpty) vehicle.capacityLabel,
      '$drivers driver${drivers == 1 ? '' : 's'} nearby',
    ].join(' · ');
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: context.colors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: context.colors.outlineVariant),
          ),
          child: Row(
            children: [
              CatalogIcon(
                iconUrl: vehicle.iconUrl,
                supabaseUrl: _iconBaseUrl,
                fallbackIcon: Icons.local_shipping_outlined,
                color: context.colors.primary,
                size: 26,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      vehicle.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: context.colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                'Switch',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                  color: enabled
                      ? context.colors.primary
                      : context.colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TrackingView extends ConsumerWidget {
  const _TrackingView({super.key});

  static String _statusLabel(String? status) => switch (status) {
    'accepted' || 'heading_to_pickup' => 'Driver on the way',
    'arrived' => 'Driver has arrived at pickup',
    'cargo_verified' => 'Driver verified the cargo',
    'loading' => 'Loading your goods',
    'in_transit' => 'On the way to the destination',
    'arrived_destination' => 'Driver has arrived at the destination',
    'delivered' => 'Delivery confirmed',
    'completed' => 'Move completed',
    'cancelled' => 'Move cancelled',
    'disputed' => 'Move under review',
    _ => 'Driver assigned',
  };

  /// Live ETA for the leg in progress, or the booked trip figures.
  static String _tripMetrics(RideState ride) {
    final eta = ride.liveEtaMin;
    final km = ride.liveRemainingKm;
    if (eta != null && km != null) {
      final minutes = eta <= 1 ? 'under a minute' : '$eta min';
      return switch (ride.jobStatus) {
        'in_transit' => '$minutes to drop-off · ${km.toStringAsFixed(1)} km',
        _ => 'Arrives in $minutes · ${km.toStringAsFixed(1)} km',
      };
    }
    return '${ride.distanceKm.toStringAsFixed(1)} km · ${ride.durationMin} min';
  }

  /// Shown under the driver when their position has gone quiet.
  static String? _locationNote(RideState ride) {
    if (!ride.driverLocationFresh) return 'Location updating…';
    final at = ride.driverLocationUpdatedAt;
    if (at == null) return null;
    final age = DateTime.now().difference(at.toLocal());
    if (age < const Duration(seconds: 90)) return null;
    return 'Location last updated ${age.inMinutes} min ago';
  }

  static double _statusProgress(String? status) => switch (status) {
    'accepted' => 0.2,
    'heading_to_pickup' => 0.35,
    'arrived' => 0.5,
    'cargo_verified' => 0.58,
    'loading' => 0.65,
    'in_transit' => 0.8,
    'arrived_destination' => 0.9,
    'delivered' || 'completed' => 1.0,
    _ => 0.2,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ride = ref.watch(rideProvider);
    final driver = ride.driver;
    final status = ride.jobStatus;
    final prePickup =
        status == null ||
        status == 'accepted' ||
        status == 'heading_to_pickup' ||
        status == 'arrived' ||
        status == 'cargo_verified' ||
        status == 'loading';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.sizeOf(context).width * 0.52,
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: context.colors.secondaryContainer,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: context.colors.onSecondaryContainer,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _statusLabel(status),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: context.colors.onSecondaryContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Text(
              _tripMetrics(ride),
              style: TextStyles.caption.copyWith(
                color: context.colors.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        if (ride.isScheduled && prePickup) ...[
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(
                Icons.schedule_rounded,
                size: 14,
                color: context.colors.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Scheduled for ${ride.scheduledLabel}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyles.caption.copyWith(
                    color: context.colors.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: LinearProgressIndicator(
            value: _statusProgress(status),
            minHeight: 6,
            backgroundColor: context.colors.surfaceContainerHighest,
            color: context.colors.primary,
          ),
        ),
        if (status == 'arrived' && ride.pickupFreeWaitEndsAt != null) ...[
          const SizedBox(height: 10),
          _PickupWaitBanner(endsAt: ride.pickupFreeWaitEndsAt!),
        ],
        const SizedBox(height: 12),
        InfoCard(
          child: Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: context.colors.primary.withValues(alpha: 0.12),
                child: Text(
                  driver == null
                      ? '?'
                      : driver.name
                            .split(' ')
                            .where((e) => e.isNotEmpty)
                            .map((e) => e[0])
                            .take(2)
                            .join(),
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            driver?.name ?? 'SafeShift driver',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        Icon(
                          Icons.verified_rounded,
                          size: 16,
                          color: context.colors.primary,
                        ),
                      ],
                    ),
                    Text(
                      '${(driver?.rating ?? 0).toStringAsFixed(1)} · ${driver?.vehicleClass ?? ride.vehicleClass?.name ?? 'Vehicle'} · ${_formatTzs(_totalFor(ride, ride.vehicleClass?.id))}',
                      style: TextStyles.caption.copyWith(
                        color: context.colors.onSurfaceVariant,
                      ),
                    ),
                    if (ride.driverLatitude != null &&
                        _locationNote(ride) != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        _locationNote(ride)!,
                        style: TextStyles.caption.copyWith(
                          color: context.colors.onSurfaceVariant,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(
                          ride.paymentMethod.icon,
                          size: 13,
                          color: context.colors.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            'Paying with ${ride.paymentMethod.name}',
                            style: TextStyles.caption.copyWith(
                              color: context.colors.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton.filled(
                onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Calling is not available yet')),
                ),
                icon: const Icon(Icons.call_rounded, size: 20),
                style: IconButton.styleFrom(
                  backgroundColor: context.colors.primary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: ride.jobId == null
                    ? null
                    : () => shareTrip(context, ref, ride.jobId!),
                icon: const Icon(Icons.share_outlined, size: 18),
                label: const Text('Share'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: ride.jobId == null
                    ? null
                    : () => raiseSos(context, ref, ride.jobId!),
                icon: Icon(
                  Icons.emergency_outlined,
                  size: 18,
                  color: context.colors.error,
                ),
                label: Text(
                  'SOS',
                  style: TextStyle(color: context.colors.error),
                ),
              ),
            ),
          ],
        ),
        if (_cancellableStatuses.contains(status)) ...[
          const SizedBox(height: 4),
          Center(
            child: TextButton(
              onPressed: ride.isSubmitting
                  ? null
                  : () => _confirmCancelMove(context, ref),
              child: Text(
                'Cancel move',
                style: TextStyle(color: context.colors.error),
              ),
            ),
          ),
        ],
        if (ride.hasRecipient &&
            (status == 'in_transit' || status == 'arrived_destination')) ...[
          const SizedBox(height: 10),
          InfoCard(
            child: Row(
              children: [
                Icon(Icons.sms_outlined, color: context.colors.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'We texted the delivery code and tracking link to '
                    '${ride.recipientName ?? 'the recipient'} '
                    '(${ride.recipientPhone}).',
                    style: TextStyles.caption.copyWith(
                      color: context.colors.onSurfaceVariant,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: ride.isSubmitting
                      ? null
                      : () => ref
                            .read(rideProvider.notifier)
                            .resendDeliveryCode(),
                  child: const Text('Resend'),
                ),
              ],
            ),
          ),
        ],
        if (ride.deliveryOtp != null) ...[
          const SizedBox(height: 10),
          InfoCard(
            child: Row(
              children: [
                Icon(Icons.password_rounded, color: context.colors.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Give this delivery code to your driver',
                    style: TextStyles.caption.copyWith(
                      color: context.colors.onSurfaceVariant,
                    ),
                  ),
                ),
                Text(
                  ride.deliveryOtp!,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 4,
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 10),
        PrimaryButton(
          label: ride.jobStatus == 'completed'
              ? 'Finish'
              : ride.jobStatus == 'delivered'
              ? 'Delivery confirmed'
              : 'Confirm delivery',
          icon: Icons.check_rounded,
          isLoading: ride.isSubmitting,
          onPressed: switch (ride.jobStatus) {
            'arrived_destination' =>
              () => ref.read(rideProvider.notifier).confirmDelivery(),
            'completed' => () => ref.read(rideProvider.notifier).complete(),
            _ => null,
          },
        ),
      ],
    );
  }
}

/// Statuses in which the customer can still cancel from the app: the goods
/// have not been loaded yet.
const _cancellableStatuses = <String?>{
  'accepted',
  'heading_to_pickup',
  'arrived',
  'cargo_verified',
};

/// Shows what cancelling costs before the customer commits.
Future<void> _confirmCancelMove(BuildContext context, WidgetRef ref) async {
  final notifier = ref.read(rideProvider.notifier);
  final messenger = ScaffoldMessenger.of(context);
  CancellationPreview? preview;
  try {
    preview = await notifier.cancellationPreview();
  } catch (_) {
    messenger.showSnackBar(
      const SnackBar(
        content: Text('Could not check the cancellation fee. Try again.'),
      ),
    );
    return;
  }
  if (preview == null || !context.mounted) return;
  if (!preview.cancellable) {
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          preview.message ?? 'This move can no longer be cancelled in the app.',
        ),
      ),
    );
    return;
  }
  final fee = preview.fee.round();
  final freeUntil = preview.freeUntil?.toLocal();
  final body = fee > 0
      ? 'Your driver is already assigned, so a cancellation fee of '
            '${preview.currencyCode} ${_tzs.format(fee)} applies.'
      : freeUntil != null
      ? 'You can cancel for free until '
            '${DateFormat('h:mm a').format(freeUntil)}.'
      : 'You can cancel this move for free.';
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Cancel this move?'),
      content: Text(body),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Keep move'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(dialogContext).colorScheme.error,
          ),
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(fee > 0 ? 'Cancel and pay fee' : 'Cancel move'),
        ),
      ],
    ),
  );
  if (confirmed != true) return;
  await notifier.cancelSearch();
}

/// Countdown of the driver's free waiting time at the pickup.
class _PickupWaitBanner extends StatefulWidget {
  const _PickupWaitBanner({required this.endsAt});

  final DateTime endsAt;

  @override
  State<_PickupWaitBanner> createState() => _PickupWaitBannerState();
}

class _PickupWaitBannerState extends State<_PickupWaitBanner> {
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
    final color = over ? context.colors.error : context.colors.primary;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.timer_outlined, color: color, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              over
                  ? 'Your driver has waited the full free time. Please meet '
                        'them now, or they may cancel the move.'
                  : 'Your driver is waiting at the pickup. Free waiting '
                        'ends in $mm:$ss.',
              style: TextStyles.caption.copyWith(
                color: context.colors.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// "Who receives it?" on the booking sheet.
class _RecipientCard extends ConsumerWidget {
  const _RecipientCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ride = ref.watch(rideProvider);
    final has = ride.hasRecipient;
    return InkWell(
      onTap: () => _editRecipient(context, ref),
      borderRadius: BorderRadius.circular(18),
      child: InfoCard(
        selected: has,
        child: Row(
          children: [
            Icon(
              has ? Icons.person_pin_circle_rounded : Icons.person_outline,
              color: context.colors.primary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Who receives it?',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    has
                        ? '${ride.recipientName} · ${ride.recipientPhone}'
                        : "You. Tap if someone else will receive it.",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyles.caption.copyWith(
                      color: context.colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: context.colors.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> _editRecipient(BuildContext context, WidgetRef ref) async {
  final ride = ref.read(rideProvider);
  final result = await showDialog<({String name, String phone})>(
    context: context,
    builder: (_) => _RecipientDialog(
      initialName: ride.recipientName ?? '',
      initialPhone: ride.recipientPhone ?? '',
    ),
  );
  if (result == null) return;
  ref
      .read(rideProvider.notifier)
      .setRecipient(name: result.name, phone: result.phone);
}

class _RecipientDialog extends StatefulWidget {
  const _RecipientDialog({
    required this.initialName,
    required this.initialPhone,
  });

  final String initialName;
  final String initialPhone;

  @override
  State<_RecipientDialog> createState() => _RecipientDialogState();
}

class _RecipientDialogState extends State<_RecipientDialog> {
  late final _name = TextEditingController(text: widget.initialName);
  late final _phone = TextEditingController(
    text: widget.initialPhone.isEmpty
        ? ''
        : formatPhoneInternational(widget.initialPhone),
  );

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  /// Checked against the country's plan; must be a mobile to get the SMS.
  PhoneCheck get _phoneCheck => checkPhone(_phone.text);

  bool get _valid => _name.text.trim().isNotEmpty && _phoneCheck.isValid;

  @override
  Widget build(BuildContext context) {
    final valid = _valid;
    return Dialog(
      // Narrow side margins, like the parcel dialog.
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 480),
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(26),
          boxShadow: AppColors.cardShadow,
        ),
        child: SingleChildScrollView(
          // Scrolls when the keyboard leaves little room for the fields.
          padding: const EdgeInsets.fromLTRB(20, 14, 12, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      gradient: AppColors.brandGradient,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: AppColors.cardShadow,
                    ),
                    child: const Icon(
                      Icons.person_pin_circle_rounded,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Who receives it?', style: TextStyles.title),
                        Text(
                          'Gets a tracking link and the delivery code by SMS',
                          style: TextStyle(
                            fontSize: 11,
                            color: context.colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 16),
                    TextField(
                      controller: _name,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Recipient name',
                        prefixIcon: Icon(Icons.person_outline_rounded),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 12),
                    PhoneNumberField(
                      controller: _phone,
                      label: 'Recipient mobile',
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 20),
                    PrimaryButton(
                      label: 'Save recipient',
                      icon: Icons.check_rounded,
                      onPressed: valid
                          ? () => Navigator.of(context).pop((
                              name: _name.text.trim(),
                              phone: _phoneCheck.e164!,
                            ))
                          : null,
                    ),
                    const SizedBox(height: 4),
                    TextButton(
                      onPressed: () =>
                          Navigator.of(context).pop((name: '', phone: '')),
                      child: const Text("I'm receiving it myself"),
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
}

class _DoneView extends ConsumerWidget {
  const _DoneView({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ride = ref.watch(rideProvider);
    return Column(
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: context.colors.secondary.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.check_rounded,
            color: context.colors.secondary,
            size: 38,
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'Delivered',
          style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
        ),
        Text(
          '${ride.pickup?.name ?? ride.pickupAddress ?? ''} to ${ride.destination?.name ?? ride.destinationAddress ?? ''}',
          textAlign: TextAlign.center,
          style: TextStyles.body.copyWith(
            color: context.colors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        PrimaryButton(
          label: 'Book another move',
          onPressed: () => ref.read(rideProvider.notifier).reset(),
        ),
      ],
    );
  }
}
