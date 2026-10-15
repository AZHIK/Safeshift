import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/theme/text_styles.dart';
import '../../../../core/widgets/buttons/primary_button.dart';
import '../../../../core/widgets/cards/info_card.dart';
import '../../providers/booking_provider.dart';
import '../../providers/quote_provider.dart';

class QuoteScreen extends ConsumerWidget {
  const QuoteScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draft = ref.watch(bookingProvider);
    final quote = ref.watch(quoteProvider);
    final currency = NumberFormat('#,##0');
    return Scaffold(
      appBar: AppBar(title: const Text('Your Quote')),
      body: draft == null || quote == null
          ? const Center(child: Text('Start a booking to see your quote.'))
          : ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSizes.lg,
                AppSizes.md,
                AppSizes.lg,
                AppSizes.lg,
              ),
              children: <Widget>[
                InfoCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Text('Your route', style: TextStyles.title),
                      const SizedBox(height: AppSizes.md),
                      _RouteLine(
                        icon: Icons.trip_origin_rounded,
                        color: AppColors.success,
                        label: draft.pickup.name,
                        district: draft.pickup.district,
                      ),
                      Padding(
                        padding: const EdgeInsets.only(left: 11),
                        child: Container(
                          width: 2,
                          height: 18,
                          color: AppColors.divider,
                        ),
                      ),
                      _RouteLine(
                        icon: Icons.location_on_rounded,
                        color: AppColors.error,
                        label: draft.destination.name,
                        district: draft.destination.district,
                      ),
                      const Divider(height: AppSizes.lg),
                      const Row(
                        children: <Widget>[
                          Icon(
                            Icons.route_outlined,
                            size: 18,
                            color: AppColors.textSecondary,
                          ),
                          SizedBox(width: 6),
                          Text('8.2 km'),
                          SizedBox(width: AppSizes.md),
                          Icon(
                            Icons.schedule_outlined,
                            size: 18,
                            color: AppColors.textSecondary,
                          ),
                          SizedBox(width: 6),
                          Text('32 min'),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSizes.md),
                InfoCard(
                  child: Row(
                    children: <Widget>[
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          draft.vehicleClass.icon,
                          color: AppColors.primaryDark,
                        ),
                      ),
                      const SizedBox(width: AppSizes.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              draft.vehicleClass.name,
                              style: TextStyles.title,
                            ),
                            Text(
                              draft.vehicleClass.capacityLabel,
                              style: TextStyles.caption.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        'Vehicle',
                        style: TextStyles.caption.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSizes.md),
                InfoCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Text('Price breakdown', style: TextStyles.title),
                      const SizedBox(height: AppSizes.md),
                      _PriceRow(
                        label: 'Base fee',
                        value: quote.baseFee,
                        format: currency,
                      ),
                      _PriceRow(
                        label: 'Distance (8.2 km)',
                        value: quote.distanceFee,
                        format: currency,
                      ),
                      _PriceRow(
                        label: 'Estimated time',
                        value: quote.timeFee,
                        format: currency,
                      ),
                      _PriceRow(
                        label: 'Cargo handling',
                        value: quote.cargoHandlingFee,
                        format: currency,
                      ),
                      const Divider(height: AppSizes.lg),
                      _PriceRow(
                        label: 'Subtotal',
                        value: quote.subtotal,
                        format: currency,
                      ),
                      _PriceRow(
                        label: 'VAT (18%)',
                        value: quote.vat,
                        format: currency,
                      ),
                      const Divider(height: AppSizes.lg),
                      _PriceRow(
                        label: 'Estimated total',
                        value: quote.total,
                        format: currency,
                        isTotal: true,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSizes.md),
                Text(
                  'This is an estimate. Final price may adjust if cargo details change.',
                  style: TextStyles.caption.copyWith(
                    color: AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
      bottomNavigationBar: draft == null || quote == null
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSizes.lg,
                  AppSizes.sm,
                  AppSizes.lg,
                  AppSizes.md,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    PrimaryButton(
                      label: 'Accept Quote',
                      onPressed: () => context.push('/matching'),
                    ),
                    TextButton(
                      onPressed: () => context.pop(),
                      child: const Text('Edit Booking'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

class _RouteLine extends StatelessWidget {
  const _RouteLine({
    required this.icon,
    required this.color,
    required this.label,
    required this.district,
  });
  final IconData icon;
  final Color color;
  final String label;
  final String district;
  @override
  Widget build(BuildContext context) => Row(
    children: <Widget>[
      Icon(icon, size: 22, color: color),
      const SizedBox(width: AppSizes.sm),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(label, style: TextStyles.title.copyWith(fontSize: 14)),
            Text(
              district,
              style: TextStyles.caption.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

class _PriceRow extends StatelessWidget {
  const _PriceRow({
    required this.label,
    required this.value,
    required this.format,
    this.isTotal = false,
  });
  final String label;
  final num value;
  final NumberFormat format;
  final bool isTotal;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      children: <Widget>[
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: isTotal ? 16 : 13,
              color: isTotal ? AppColors.textPrimary : AppColors.textSecondary,
              fontWeight: isTotal ? FontWeight.w700 : FontWeight.w400,
            ),
          ),
        ),
        Text(
          'TZS ${format.format(value)}',
          style: TextStyle(
            fontSize: isTotal ? 18 : 13,
            color: AppColors.textPrimary,
            fontWeight: isTotal ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
      ],
    ),
  );
}
