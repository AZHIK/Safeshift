import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/theme/text_styles.dart';
import '../../../../shared/mock/mock_payment_methods.dart';
import '../../providers/ride_provider.dart';

/// Bolt-like mock payment picker. Dialog only, no backend / real logic.
/// Selection is stored in [rideProvider] and echoed in quote/tracking.
Future<void> showPaymentDialog(BuildContext context) => showDialog<void>(
  context: context,
  barrierDismissible: true,
  builder: (_) => const _PaymentDialog(),
);

class _PaymentDialog extends ConsumerWidget {
  const _PaymentDialog();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(rideProvider).paymentMethod;
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(26),
          boxShadow: AppColors.cardShadow,
        ),
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
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
                    Icons.wallet_rounded,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Payment method', style: TextStyles.title),
                      Text(
                        'Mock UI only — no charge made',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 12),
            for (final m in mockPaymentMethods)
              _MethodTile(
                method: m,
                selected: m.id == selected.id,
                onTap: () {
                  ref
                      .read(rideProvider.notifier)
                      .selectPaymentMethod(m);
                  Navigator.pop(context);
                },
              ),
            // Mock "add card" placeholder — does nothing real.
            InkWell(
              onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Add card is mocked — coming later'),
                ),
              ),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 13,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppColors.divider,
                  ),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.add_card_rounded,
                      color: AppColors.primaryDark,
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Add card (mock)',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: AppColors.textSecondary,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 6),
          ],
        ),
      ),
    );
  }
}

class _MethodTile extends StatelessWidget {
  const _MethodTile({
    required this.method,
    required this.selected,
    required this.onTap,
  });
  final MockPaymentMethod method;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withValues(alpha: 0.08)
              : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.divider,
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: method.color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(method.icon, color: method.color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                method.name,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            if (selected)
              const Icon(
                Icons.check_circle_rounded,
                color: AppColors.primaryDark,
              ),
          ],
        ),
      ),
    ),
  );
}
