import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_sizes.dart';
import '../../../../core/theme/text_styles.dart';
import '../../../../core/widgets/cards/info_card.dart';
import '../../providers/vehicle_provider.dart';

/// Pushed route: driver's registered vehicle.
class VehicleScreen extends ConsumerWidget {
  const VehicleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vehicle = ref.watch(vehicleStateProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Vehicle')),
      body: ListView(
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
                        color: const Color(0xFF0B63D6).withValues(alpha: 0.1),
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
                            '${vehicle.make} ${vehicle.model}',
                            style: TextStyles.title.copyWith(fontSize: 16),
                          ),
                          Text(
                            '${vehicle.year} · ${vehicle.color}',
                            style: TextStyles.body,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const Divider(height: AppSizes.lg),
                _Row(label: 'Plate number', value: vehicle.plateNumber),
                _Row(label: 'Class', value: vehicle.vehicleClass),
                _Row(
                  label: 'Capacity',
                  value: '${vehicle.capacityKg} kg',
                ),
              ],
            ),
          ),
        ],
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
