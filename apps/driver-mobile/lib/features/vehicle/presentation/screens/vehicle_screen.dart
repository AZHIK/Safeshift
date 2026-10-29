import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_sizes.dart';
import '../../../../core/errors/error_handler.dart';
import '../../../../core/theme/text_styles.dart';
import '../../../../core/widgets/buttons/primary_button.dart';
import '../../../../core/widgets/cards/info_card.dart';
import '../../providers/vehicle_provider.dart';

/// Pushed route: driver's registered vehicle.
class VehicleScreen extends ConsumerWidget {
  const VehicleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vehicleAsync = ref.watch(vehicleStateProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Vehicle')),
      body: vehicleAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) {
          final failure = ErrorHandler.map(error, stackTrace: stack);
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSizes.xl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(failure.message, textAlign: TextAlign.center),
                  const SizedBox(height: AppSizes.md),
                  PrimaryButton(
                    label: 'Try again',
                    onPressed: () =>
                        ref.read(vehicleStateProvider.notifier).refresh(),
                  ),
                ],
              ),
            ),
          );
        },
        data: (vehicle) {
          if (vehicle == null) {
            return const Center(child: Text('No vehicle assigned yet.'));
          }
          return RefreshIndicator(
            onRefresh: () => ref.read(vehicleStateProvider.notifier).refresh(),
            child: ListView(
              padding: const EdgeInsets.all(AppSizes.lg),
              children: [
                InfoCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0B63D6).withValues(
                                alpha: 0.1,
                              ),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Icon(
                              Icons.local_shipping_rounded,
                              size: 32,
                            ),
                          ),
                          const SizedBox(width: AppSizes.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${vehicle.make ?? ''} ${vehicle.model ?? ''}'
                                      .trim(),
                                  style: TextStyles.title.copyWith(
                                    fontSize: 16,
                                  ),
                                ),
                                Text(
                                  '${vehicle.year ?? ''} · ${vehicle.color ?? ''}'
                                      .trim(),
                                  style: TextStyles.body,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: AppSizes.lg),
                      _Row(
                        label: 'Plate number',
                        value: vehicle.registrationNumber,
                      ),
                      _Row(label: 'Class', value: vehicle.vehicleType),
                      _Row(
                        label: 'Capacity',
                        value: '${vehicle.capacityKg ?? 0} kg',
                      ),
                      _Row(
                        label: 'Verification',
                        value: vehicle.verificationStatus,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(child: Text(label, style: TextStyles.caption)),
          Text(value, style: TextStyles.title),
        ],
      ),
    );
  }
}
