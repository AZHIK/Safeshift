import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/theme/text_styles.dart';
import '../../../../core/widgets/buttons/primary_button.dart';
import '../../../../core/widgets/cards/info_card.dart';
import '../../../../core/widgets/cards/receipt_card.dart';
import '../../../../core/widgets/feedback/app_snackbar.dart';
import '../../../../core/widgets/feedback/rating_dialog.dart';
import '../../../../core/widgets/inputs/otp_boxes.dart';
import '../../../booking/providers/booking_provider.dart';
import '../../../booking/providers/quote_provider.dart';
import '../../../../shared/mock/mock_drivers.dart';
import '../../providers/delivery_provider.dart';

class DeliveryConfirmationScreen extends ConsumerStatefulWidget {
  const DeliveryConfirmationScreen({super.key});

  @override
  ConsumerState<DeliveryConfirmationScreen> createState() =>
      _DeliveryConfirmationScreenState();
}

class _DeliveryConfirmationScreenState
    extends ConsumerState<DeliveryConfirmationScreen> {
  late final TextEditingController _codeController = TextEditingController();
  String _code = '';

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _rateDriver() async {
    await showDialog<void>(
      context: context,
      builder: (_) => RatingDialog(
        driverName: mockDrivers.first.name,
        onRatingSubmitted: (rating) => AppSnackbar.showSuccess(
          context,
          'Thanks for rating ${mockDrivers.first.name} $rating stars.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final delivery = ref.watch(deliveryProvider);
    final booking = ref.watch(bookingProvider);
    final quote = ref.watch(quoteProvider);
    final isReceipt = delivery.phase == DeliveryPhase.receipt;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Confirm Delivery'),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSizes.lg,
            AppSizes.lg,
            AppSizes.lg,
            AppSizes.xl,
          ),
          children: isReceipt
              ? <Widget>[
                  Center(
                    child: TweenAnimationBuilder<double>(
                      tween: Tween<double>(begin: 0.45, end: 1),
                      duration: const Duration(milliseconds: 550),
                      curve: Curves.elasticOut,
                      builder: (context, scale, child) =>
                          Transform.scale(scale: scale, child: child),
                      child: Container(
                        width: 88,
                        height: 88,
                        decoration: const BoxDecoration(
                          color: Color(0xFFE6F4EC),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check_rounded,
                          size: 48,
                          color: AppColors.success,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSizes.md),
                  Text(
                    'Delivery Confirmed',
                    textAlign: TextAlign.center,
                    style: TextStyles.headline.copyWith(fontSize: 21),
                  ),
                  const SizedBox(height: AppSizes.lg),
                  ReceiptCard(
                    jobId: 'SF-2026-001234',
                    date: DateTime.now(),
                    driverName: mockDrivers.first.name,
                    pickup: booking?.pickup.name ?? 'Morocco Junction',
                    destination:
                        booking?.destination.name ?? 'Mlimani City Mall',
                    total: quote?.total ?? 52000,
                    paymentMethod: 'M-Pesa',
                  ),
                ]
              : <Widget>[
                  const SizedBox(height: AppSizes.lg),
                  Center(
                    child: Container(
                      width: 88,
                      height: 88,
                      decoration: const BoxDecoration(
                        color: Color(0xFFE6F4EC),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check_rounded,
                        size: 48,
                        color: AppColors.success,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSizes.lg),
                  Text(
                    'Your delivery has arrived',
                    textAlign: TextAlign.center,
                    style: TextStyles.headline.copyWith(fontSize: 21),
                  ),
                  const SizedBox(height: AppSizes.xs),
                  Text(
                    'Please confirm to complete the job',
                    textAlign: TextAlign.center,
                    style: TextStyles.body.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSizes.xl),
                  InfoCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        const Text('Delivery code', style: TextStyles.title),
                        const SizedBox(height: AppSizes.xs),
                        Text(
                          'Enter the 6-digit code shown by the driver',
                          style: TextStyles.body.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: AppSizes.lg),
                        OtpBoxes(
                          controller: _codeController,
                          length: 6,
                          onChanged: (value) => setState(() => _code = value),
                          onCompleted: (value) => setState(() => _code = value),
                        ),
                      ],
                    ),
                  ),
                ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSizes.lg,
            AppSizes.sm,
            AppSizes.lg,
            AppSizes.md,
          ),
          child: isReceipt
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    PrimaryButton(label: 'Rate Driver', onPressed: _rateDriver),
                    TextButton(
                      onPressed: () => context.go('/home'),
                      child: const Text('Back to Home'),
                    ),
                  ],
                )
              : PrimaryButton(
                  label: delivery.isLoading
                      ? 'Confirming…'
                      : 'Confirm Delivery',
                  isLoading: delivery.isLoading,
                  onPressed: _code.length == 6 && !delivery.isLoading
                      ? () => ref
                            .read(deliveryProvider.notifier)
                            .confirmDelivery()
                      : null,
                ),
        ),
      ),
    );
  }
}
