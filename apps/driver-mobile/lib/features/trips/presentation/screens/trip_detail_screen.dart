import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/theme/text_styles.dart';
import '../../../../core/widgets/cards/info_card.dart';
import '../../../../core/widgets/cards/receipt_card.dart';
import '../../../../core/widgets/cards/status_pill.dart';
import '../../../../shared/mock/mock_trips.dart';

String _tzs(num amount) => 'TZS ${NumberFormat('#,##0').format(amount)}';

/// Pushed route: full details of one completed trip.
class TripDetailScreen extends StatelessWidget {
  const TripDetailScreen({super.key, required this.tripId});

  final String tripId;

  @override
  Widget build(BuildContext context) {
    final trip = mockTrips.firstWhere(
      (t) => t.id == tripId,
      orElse: () => mockTrips.first,
    );
    return Scaffold(
      appBar: AppBar(title: Text(trip.id)),
      body: ListView(
        padding: const EdgeInsets.all(AppSizes.lg),
        children: [
          InfoCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    StatusPill(status: trip.status),
                    const Spacer(),
                    Text(
                      DateFormat('d MMM yyyy, h:mm a').format(trip.date),
                      style: TextStyles.caption.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSizes.md),
                _Leg(
                  icon: Icons.location_on_rounded,
                  color: AppColors.onlineGreen,
                  label: 'Pickup',
                  value: trip.pickup,
                ),
                const SizedBox(height: AppSizes.sm),
                _Leg(
                  icon: Icons.flag_rounded,
                  color: AppColors.error,
                  label: 'Destination',
                  value: trip.destination,
                ),
                const Divider(height: AppSizes.lg),
                _Row(
                  label: 'Distance',
                  value: '${trip.distanceKm.toStringAsFixed(1)} km',
                ),
                _Row(label: 'Customer', value: trip.customerName),
                _Row(label: 'Payment', value: trip.paymentMethod),
                _Row(
                  label: 'Customer rating',
                  value: '${trip.rating.toStringAsFixed(0)} / 5',
                ),
                _Row(label: 'Fare', value: _tzs(trip.fareTzs), isTotal: true),
              ],
            ),
          ),
          const SizedBox(height: AppSizes.md),
          ReceiptCard(
            jobId: trip.id,
            date: trip.date,
            driverName: 'You',
            pickup: trip.pickup,
            destination: trip.destination,
            total: trip.fareTzs,
            paymentMethod: trip.paymentMethod,
          ),
        ],
      ),
    );
  }
}

class _Leg extends StatelessWidget {
  const _Leg({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final Color color;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: AppSizes.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyles.caption.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              Text(value, style: TextStyles.title),
            ],
          ),
        ),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value, this.isTotal = false});

  final String label;
  final String value;
  final bool isTotal;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyles.caption.copyWith(
                color: AppColors.textSecondary,
                fontSize: isTotal ? 14 : 12,
              ),
            ),
          ),
          Text(
            value,
            style: isTotal
                ? TextStyles.title.copyWith(fontSize: 15)
                : const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
