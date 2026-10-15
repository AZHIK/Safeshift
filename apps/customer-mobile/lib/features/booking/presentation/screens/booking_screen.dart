import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/theme/text_styles.dart';
import '../../../../core/widgets/buttons/primary_button.dart';
import '../../../../core/widgets/cards/info_card.dart';
import '../../../../core/widgets/sheets/address_suggestion_sheet.dart';
import '../../../../shared/mock/mock_cargo_categories.dart';
import '../../../../shared/mock/mock_locations.dart';
import '../../../../shared/mock/mock_vehicle_classes.dart';
import '../../providers/booking_provider.dart';

class BookingScreen extends ConsumerStatefulWidget {
  const BookingScreen({super.key});

  @override
  ConsumerState<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends ConsumerState<BookingScreen> {
  MockLocation? _pickup;
  MockLocation? _destination;
  MockCargoCategory? _cargo;
  late MockVehicleClass _vehicle;
  DateTime? _scheduledTime;

  @override
  void initState() {
    super.initState();
    final draft = ref.read(bookingProvider);
    _pickup = draft?.pickup;
    _destination = draft?.destination;
    _cargo = draft?.cargoCategory;
    _vehicle = draft?.vehicleClass ?? mockVehicleClasses.first;
    _scheduledTime = draft?.scheduledTime;
  }

  Future<void> _chooseAddress({required bool pickup}) async {
    await showAddressSuggestionSheet(
      context: context,
      onSelected: (location) => setState(() {
        if (pickup) {
          _pickup = location;
        } else {
          _destination = location;
        }
      }),
    );
  }

  Future<void> _chooseSchedule() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSizes.lg,
            0,
            AppSizes.lg,
            AppSizes.lg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ListTile(
                title: const Text('Now'),
                leading: const Icon(Icons.bolt_rounded),
                onTap: () => Navigator.pop(context, 'now'),
              ),
              ListTile(
                title: const Text('In 1 hour'),
                leading: const Icon(Icons.schedule_rounded),
                onTap: () => Navigator.pop(context, 'hour'),
              ),
              ListTile(
                title: const Text('Custom time'),
                leading: const Icon(Icons.calendar_month_rounded),
                onTap: () => Navigator.pop(context, 'custom'),
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted || choice == null) return;
    if (choice == 'custom') {
      final date = await showDatePicker(
        context: context,
        firstDate: DateTime.now(),
        lastDate: DateTime.now().add(const Duration(days: 90)),
        initialDate: DateTime.now(),
      );
      if (!mounted || date == null) return;
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
      );
      if (!mounted || time == null) return;
      setState(
        () => _scheduledTime = DateTime(
          date.year,
          date.month,
          date.day,
          time.hour,
          time.minute,
        ),
      );
    } else {
      setState(
        () => _scheduledTime = choice == 'hour'
            ? DateTime.now().add(const Duration(hours: 1))
            : DateTime.now(),
      );
    }
  }

  void _getQuote() {
    final pickup = _pickup;
    final destination = _destination;
    if (pickup == null || destination == null) return;
    ref
        .read(bookingProvider.notifier)
        .save(
          BookingDraft(
            pickup: pickup,
            destination: destination,
            cargoCategory: _cargo,
            vehicleClass: _vehicle,
            scheduledTime: _scheduledTime,
          ),
        );
    context.push('/quote');
  }

  @override
  Widget build(BuildContext context) {
    final canContinue = _pickup != null && _destination != null;
    return Scaffold(
      appBar: AppBar(
        title: const Text('New Booking'),
        leading: BackButton(onPressed: () => context.pop()),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSizes.lg,
          AppSizes.sm,
          AppSizes.lg,
          AppSizes.xl,
        ),
        children: <Widget>[
          const _SectionTitle(
            title: 'Where are we going?',
            subtitle: 'Choose your pickup and destination.',
          ),
          const SizedBox(height: AppSizes.md),
          _AddressCard(
            label: 'Pickup address',
            location: _pickup,
            icon: Icons.trip_origin_rounded,
            color: AppColors.success,
            onTap: () => _chooseAddress(pickup: true),
          ),
          const SizedBox(height: AppSizes.sm),
          _AddressCard(
            label: 'Destination',
            location: _destination,
            icon: Icons.location_on_rounded,
            color: AppColors.error,
            onTap: () => _chooseAddress(pickup: false),
          ),
          const SizedBox(height: AppSizes.lg),
          const _SectionTitle(
            title: 'What are you moving?',
            subtitle: 'Choose the closest cargo type.',
          ),
          const SizedBox(height: AppSizes.md),
          SizedBox(
            height: 42,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: mockCargoCategories.length,
              separatorBuilder: (_, _) => const SizedBox(width: AppSizes.sm),
              itemBuilder: (context, index) {
                final category = mockCargoCategories[index];
                final selected = category.id == _cargo?.id;
                return ChoiceChip(
                  avatar: Icon(
                    category.icon,
                    size: 17,
                    color: selected ? Colors.white : AppColors.textSecondary,
                  ),
                  label: Text(category.name),
                  selected: selected,
                  showCheckmark: false,
                  selectedColor: AppColors.primary,
                  labelStyle: TextStyle(
                    color: selected ? Colors.white : AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                  onSelected: (_) => setState(() => _cargo = category),
                );
              },
            ),
          ),
          const SizedBox(height: AppSizes.lg),
          const _SectionTitle(
            title: 'Choose a vehicle',
            subtitle: 'Pick a size that fits your load.',
          ),
          const SizedBox(height: AppSizes.md),
          for (final vehicle in mockVehicleClasses) ...<Widget>[
            _VehicleOption(
              vehicle: vehicle,
              selected: _vehicle.id == vehicle.id,
              onTap: () => setState(() => _vehicle = vehicle),
            ),
            const SizedBox(height: AppSizes.sm),
          ],
          const SizedBox(height: AppSizes.md),
          InkWell(
            onTap: _chooseSchedule,
            borderRadius: BorderRadius.circular(AppSizes.borderRadius),
            child: InfoCard(
              child: Row(
                children: <Widget>[
                  const Icon(
                    Icons.calendar_month_outlined,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: AppSizes.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        const Text(
                          'Schedule your move',
                          style: TextStyles.title,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          _scheduledTime == null
                              ? 'As soon as possible'
                              : DateFormat('EEE, d MMM · h:mm a')
                                    .format(_scheduledTime!),
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
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSizes.lg,
            AppSizes.sm,
            AppSizes.lg,
            AppSizes.md,
          ),
          child: PrimaryButton(
            label: 'Get Quote',
            onPressed: canContinue ? _getQuote : null,
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.subtitle});
  final String title;
  final String subtitle;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      Text(title, style: TextStyles.title),
      const SizedBox(height: 3),
      Text(
        subtitle,
        style: TextStyles.caption.copyWith(color: AppColors.textSecondary),
      ),
    ],
  );
}

class _AddressCard extends StatelessWidget {
  const _AddressCard({
    required this.label,
    required this.location,
    required this.icon,
    required this.color,
    required this.onTap,
  });
  final String label;
  final MockLocation? location;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(16),
    child: InfoCard(
      child: Row(
        children: <Widget>[
          Icon(icon, color: color, size: 24),
          const SizedBox(width: AppSizes.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  label,
                  style: TextStyles.caption.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  location?.name ?? 'Select a location',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyles.title.copyWith(
                    color: location == null
                        ? AppColors.textDisabled
                        : AppColors.textPrimary,
                    fontSize: 12,
                  ),
                ),
                if (location != null)
                  Text(
                    location!.district,
                    style: TextStyles.caption.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
          const Icon(
            Icons.search_rounded,
            color: AppColors.textSecondary,
            size: 20,
          ),
        ],
      ),
    ),
  );
}

class _VehicleOption extends StatelessWidget {
  const _VehicleOption({
    required this.vehicle,
    required this.selected,
    required this.onTap,
  });
  final MockVehicleClass vehicle;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(16),
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      padding: const EdgeInsets.all(AppSizes.md),
      decoration: BoxDecoration(
        color: selected
            ? AppColors.primary.withValues(alpha: 0.07)
            : AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: selected ? AppColors.primary : AppColors.divider,
          width: selected ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: selected
                  ? AppColors.primary.withValues(alpha: 0.14)
                  : AppColors.background,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(vehicle.icon, color: AppColors.primaryDark),
          ),
          const SizedBox(width: AppSizes.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(vehicle.name, style: TextStyles.title),
                Text(
                  vehicle.capacityLabel,
                  style: TextStyles.caption.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                Text(
                  vehicle.description,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyles.caption.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSizes.sm),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Text(
                'From',
                style: TextStyles.caption.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              Text(
                'TZS ${NumberFormat('#,##0').format(vehicle.basePriceTzs)}',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(width: AppSizes.xs),
          Icon(
            selected
                ? Icons.radio_button_checked_rounded
                : Icons.radio_button_off_rounded,
            color: selected ? AppColors.primary : AppColors.textDisabled,
            size: 20,
          ),
        ],
      ),
    ),
  );
}
