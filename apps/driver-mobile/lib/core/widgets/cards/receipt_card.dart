import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../constants/app_colors.dart';
import '../../constants/app_sizes.dart';
import '../../theme/text_styles.dart';

String formatTzs(num amount) => 'TZS ${NumberFormat('#,##0').format(amount)}';

class ReceiptCard extends StatelessWidget {
  const ReceiptCard({
    super.key,
    required this.jobId,
    required this.date,
    required this.driverName,
    required this.pickup,
    required this.destination,
    required this.total,
    required this.paymentMethod,
  });

  final String jobId;
  final DateTime date;
  final String driverName;
  final String pickup;
  final String destination;
  final num total;
  final String paymentMethod;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(AppSizes.md),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.divider),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Row(
          children: <Widget>[
            Icon(Icons.receipt_long_rounded, color: AppColors.primary),
            SizedBox(width: AppSizes.sm),
            Text('Trip receipt', style: TextStyles.title),
          ],
        ),
        const SizedBox(height: AppSizes.md),
        _ReceiptRow(label: 'Job ID', value: jobId),
        _ReceiptRow(
          label: 'Date',
          value: DateFormat('d MMM yyyy, h:mm a').format(date),
        ),
        _ReceiptRow(label: 'Driver', value: driverName),
        const Divider(height: AppSizes.lg),
        _ReceiptRow(label: 'Pickup', value: pickup),
        _ReceiptRow(label: 'Destination', value: destination),
        _ReceiptRow(label: 'Payment', value: paymentMethod),
        const Divider(height: AppSizes.lg),
        _ReceiptRow(
          label: 'Total paid',
          value: formatTzs(total),
          isTotal: true,
        ),
      ],
    ),
  );
}

class _ReceiptRow extends StatelessWidget {
  const _ReceiptRow({
    required this.label,
    required this.value,
    this.isTotal = false,
  });
  final String label;
  final String value;
  final bool isTotal;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          child: Text(
            label,
            style: TextStyles.caption.copyWith(
              color: AppColors.textSecondary,
              fontSize: isTotal ? 14 : 12,
            ),
          ),
        ),
        const SizedBox(width: AppSizes.md),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: isTotal
                ? TextStyles.title.copyWith(color: AppColors.textPrimary)
                : const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    ),
  );
}
