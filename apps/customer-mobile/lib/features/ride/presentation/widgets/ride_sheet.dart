import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/theme/text_styles.dart';
import '../../../../core/widgets/buttons/primary_button.dart';
import '../../../../core/widgets/cards/info_card.dart';
import '../../../../core/widgets/sheets/address_suggestion_sheet.dart';
import '../../../../shared/mock/mock_cargo_categories.dart';
import '../../../../shared/mock/mock_drivers.dart';
import '../../../../shared/mock/mock_locations.dart';
import '../../../../shared/mock/mock_quotes.dart';
import '../../../../shared/mock/mock_vehicle_classes.dart';
import '../../providers/ride_provider.dart';
import 'parcel_dialog.dart';
import 'payment_dialog.dart';

final _tzs = NumberFormat('#,##0');

int _totalFor(String vehicleId) {
  for (final q in mockQuotes) {
    if (q.vehicleClassId == vehicleId) return q.total.round();
  }
  return mockVehicleClasses.first.basePriceTzs;
}

/// The morphing bottom sheet content. One widget, all stages.
class RideSheetBody extends ConsumerWidget {
  const RideSheetBody({super.key, required this.scrollController});

  final ScrollController scrollController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ride = ref.watch(rideProvider);
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
              color: AppColors.divider,
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
            RideStage.confirm => const _RouteAndVehicles(
              key: ValueKey('route'),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Karibu back', style: TextStyles.headline),
        const SizedBox(height: 4),
        Text(
          'Your next move, made easy.',
          style: TextStyles.body.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 14),
        _RouteInputs(
          onPickup: () => showAddressSuggestionSheet(
            context: context,
            onSelected: notifier.setPickup,
          ),
          onDestination: () => showAddressSuggestionSheet(
            context: context,
            onSelected: notifier.setDestination,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Saved places',
          style: TextStyles.caption.copyWith(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 8),
        _SavedPlaceTile(
          icon: Icons.home_rounded,
          title: 'Home',
          subtitle: 'Tabata Kimanga, Ilala',
          onTap: () => notifier.setDestination(_byId('tabata') ?? _first()),
        ),
        const SizedBox(height: 8),
        _SavedPlaceTile(
          icon: Icons.work_rounded,
          title: 'Work',
          subtitle: 'Kariakoo Market, Ilala',
          onTap: () => notifier.setDestination(_byId('kariakoo') ?? _first()),
        ),
        const SizedBox(height: 8),
        _SavedPlaceTile(
          icon: Icons.flight_rounded,
          title: 'Airport',
          subtitle: 'Julius Nyerere International, Ilala',
          onTap: () => notifier.setDestination(_byId('airport') ?? _first()),
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

class _RouteAndVehicles extends ConsumerWidget {
  const _RouteAndVehicles({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ride = ref.watch(rideProvider);
    final notifier = ref.read(rideProvider.notifier);
    final total = _totalFor(ride.vehicleClass.id);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _RouteInputs(
          onPickup: () => showAddressSuggestionSheet(
            context: context,
            onSelected: notifier.setPickup,
          ),
          onDestination: () => showAddressSuggestionSheet(
            context: context,
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
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 10),
        // Cargo chips.
        SizedBox(
          height: 38,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: mockCargoCategories.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              final c = mockCargoCategories[i];
              final sel = c.id == ride.cargo?.id;
              return ChoiceChip(
                label: Text(c.name),
                avatar: Icon(
                  c.icon,
                  size: 16,
                  color: sel ? Colors.white : AppColors.textSecondary,
                ),
                selected: sel,
                showCheckmark: false,
                selectedColor: AppColors.primaryDeep,
                labelStyle: TextStyle(
                  color: sel ? Colors.white : AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                ),
                onSelected: (_) => notifier.selectCargo(c),
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        _ParcelCard(onTap: () => showParcelDialog(context, ref)),
        const SizedBox(height: 16),
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
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 10),
        for (final v in mockVehicleClasses)
          _VehicleTile(
            vehicle: v,
            selected: v.id == ride.vehicleClass.id,
            price: _totalFor(v.id),
            onTap: () => notifier.selectVehicle(v),
          ),
        const SizedBox(height: 12),
        // Quote preview (always visible once route set — Bolt style).
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
                    'TZS ${_tzs.format(total)}',
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
                  Icon(
                    ride.vehicleClass.icon,
                    size: 16,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '${ride.vehicleClass.name} · ${ride.vehicleClass.capacityLabel} · ${ride.scheduledLabel}',
                      style: TextStyles.caption.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
              if (ride.hasParcelDetails) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(
                      Icons.inventory_2_outlined,
                      size: 14,
                      color: AppColors.textSecondary,
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
                          color: AppColors.textSecondary,
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
        const SizedBox(height: 12),
        _PaymentTile(onTap: () => showPaymentDialog(context)),
        const SizedBox(height: 12),
        PrimaryButton(
          label: 'Confirm Move · TZS ${_tzs.format(total)}',
          icon: Icons.bolt_rounded,
          onPressed: ride.hasRoute
              ? () => ref.read(rideProvider.notifier).confirmAndFindDriver()
              : null,
        ),
        const SizedBox(height: 4),
        Center(
          child: Text(
            'Final price may adjust if cargo changes',
            style: TextStyles.caption.copyWith(
              color: AppColors.textSecondary,
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
                color: method.color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(method.icon, color: method.color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Payment · mock, no charge',
                    style: TextStyle(
                      fontSize: 10,
                      color: AppColors.textSecondary,
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
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Text(
                          'Change',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primaryDark,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textSecondary,
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.divider),
        boxShadow: AppColors.cardShadow,
      ),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          const SizedBox(width: 6),
          const Column(
            children: [
              Icon(Icons.trip_origin_rounded,
                  color: Color(0xFF34D17B), size: 26),
              SizedBox(
                height: 30,
                child: VerticalDivider(width: 2, thickness: 2),
              ),
              Icon(Icons.location_on_rounded,
                  color: Color(0xFFFF5A5A), size: 26),
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
                backgroundColor: AppColors.background,
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
                    ? AppColors.textDisabled
                    : AppColors.textPrimary,
              ),
            ),
          ),
          const Icon(Icons.search_rounded,
              size: 20, color: AppColors.textSecondary),
        ],
      ),
    ),
  );
}

/// Bolt-style large saved-place row: full-width, 52px icon tile,
/// 13px title + 11px subtitle. Replaces the old small chips whose
/// 11px label was getting lost.
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
    color: Colors.white,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(18),
      side: const BorderSide(color: AppColors.divider),
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
                color: AppColors.background,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, size: 26, color: AppColors.primaryDark),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textSecondary,
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
    required this.selected,
    required this.price,
    required this.onTap,
  });
  final MockVehicleClass vehicle;
  final bool selected;
  final int price;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: selected ? AppColors.brandGradient : null,
          color: selected ? null : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? Colors.transparent : AppColors.divider,
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
                    : AppColors.background,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                vehicle.icon,
                color: selected ? Colors.white : AppColors.primaryDark,
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
                      color: selected ? Colors.white : AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    '${vehicle.capacityLabel} · ${vehicle.description}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      color: selected
                          ? Colors.white.withValues(alpha: 0.85)
                          : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'TZS ${_tzs.format(price)}',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                    color: selected ? Colors.white : AppColors.textPrimary,
                  ),
                ),
                Text(
                  selected ? 'Selected' : '7 min away',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: selected
                        ? AppColors.lime
                        : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
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
                color: done ? null : AppColors.background,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                done
                    ? Icons.check_rounded
                    : Icons.inventory_2_outlined,
                color: done ? Colors.white : AppColors.primaryDark,
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
                            color: const Color(0xFFE8F7F3),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: const Text(
                            'ADDED',
                            style: TextStyle(
                              fontSize: 8,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF166B4D),
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
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}

class _SchedulePill extends ConsumerWidget {  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final label = ref.watch(rideProvider).scheduledLabel;
    return InkWell(
      onTap: () async {
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
                  onTap: () => Navigator.pop(context, 'Now'),
                ),
                ListTile(
                  leading: const Icon(Icons.schedule_rounded),
                  title: const Text('In 1 hour'),
                  onTap: () => Navigator.pop(context, 'In 1 hour'),
                ),
                ListTile(
                  leading: const Icon(Icons.calendar_month_rounded),
                  title: const Text('Tomorrow morning'),
                  onTap: () => Navigator.pop(context, 'Tomorrow 8:00 AM'),
                ),
              ],
            ),
          ),
        );
        if (choice != null) ref.read(rideProvider.notifier).setSchedule(choice);
      },
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: AppColors.primaryDeep,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.schedule_rounded, size: 14, color: Colors.white),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
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
                      color: AppColors.primary.withValues(
                        alpha: (0.28 * (1 - ((_c.value + i / 3) % 1)))
                            .clamp(0.0, 0.3),
                      ),
                    ),
                  ),
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
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
        const Text('Finding nearby drivers…',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text('Verified vehicles within 5 km',
            style:
                TextStyles.body.copyWith(color: AppColors.textSecondary)),
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

class _TrackingView extends ConsumerWidget {
  const _TrackingView({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ride = ref.watch(rideProvider);
    final driver = ride.driver ?? mockDrivers.first;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F7F3),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Color(0xFF22B07D),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Driver on the way · ${ride.etaMin} min',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF166B4D),
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            Text(
              '${ride.distanceKm.toStringAsFixed(1)} km · ${ride.durationMin} min',
              style: TextStyles.caption.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: const LinearProgressIndicator(
            value: 0.68,
            minHeight: 6,
            backgroundColor: Color(0xFFEDF2F6),
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: 12),
        InfoCard(
          child: Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                child: Text(
                  driver.name.split(' ').map((e) => e[0]).take(2).join(),
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
                          child: Text(driver.name,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w800, fontSize: 13)),
                        ),
                        const Icon(Icons.verified_rounded,
                            size: 16, color: AppColors.primary),
                      ],
                    ),
                    Text(
                      '${driver.rating.toStringAsFixed(1)} · ${driver.vehicleClass} · TZS ${_tzs.format(_totalFor(ride.vehicleClass.id))}',
                      style: TextStyles.caption.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(
                          ride.paymentMethod.icon,
                          size: 13,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            'Paying with ${ride.paymentMethod.name} (mock)',
                            style: TextStyles.caption.copyWith(
                              color: AppColors.textSecondary,
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
                  SnackBar(content: Text('Calling ${driver.name} (mock)')),
                ),
                icon: const Icon(Icons.call_rounded, size: 20),
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.primaryDeep,
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
                onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Share link copied (mock)')),
                ),
                icon: const Icon(Icons.share_outlined, size: 18),
                label: const Text('Share'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Emergency calling is not available yet'),
                  ),
                ),
                icon: const Icon(Icons.emergency_outlined,
                    size: 18, color: AppColors.error),
                label: const Text('SOS',
                    style: TextStyle(color: AppColors.error)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        PrimaryButton(
          label: 'Confirm Delivery',
          icon: Icons.check_rounded,
          onPressed: () => ref.read(rideProvider.notifier).complete(),
        ),
      ],
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
            color: AppColors.success.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.check_rounded,
              color: AppColors.success, size: 38),
        ),
        const SizedBox(height: 10),
        const Text('Delivered',
            style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
        Text(
          '${ride.pickup?.name ?? ''} to ${ride.destination?.name ?? ''}',
          textAlign: TextAlign.center,
          style: TextStyles.body.copyWith(color: AppColors.textSecondary),
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

MockLocation _first() => mockLocations.first;

MockLocation? _byId(String id) {
  for (final l in mockLocations) {
    if (l.id == id) return l;
  }
  return null;
}
