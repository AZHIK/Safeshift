import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';

class TripStatusStepper extends StatelessWidget {
  const TripStatusStepper({super.key, required this.currentStep});
  final int currentStep;

  static const List<String> _labels = <String>[
    'Heading to Pickup',
    'Arrived',
    'Loading',
    'In Transit',
    'Delivered',
  ];

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: Row(
      children: <Widget>[
        for (var index = 0; index < _labels.length; index++) ...<Widget>[
          SizedBox(
            width: 66,
            child: Column(
              children: <Widget>[
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: index < currentStep
                        ? AppColors.success
                        : index == currentStep
                        ? AppColors.primary
                        : AppColors.background,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: index <= currentStep
                          ? Colors.transparent
                          : AppColors.divider,
                    ),
                  ),
                  child: Icon(
                    index < currentStep ? Icons.check_rounded : _iconFor(index),
                    color: index <= currentStep
                        ? Colors.white
                        : AppColors.textDisabled,
                    size: 15,
                  ),
                ),
                const SizedBox(height: AppSizes.xs),
                Text(
                  _labels[index],
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  style: TextStyle(
                    fontSize: 9,
                    height: 1.15,
                    color: index <= currentStep
                        ? AppColors.textPrimary
                        : AppColors.textDisabled,
                    fontWeight: index == currentStep
                        ? FontWeight.w700
                        : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          if (index < _labels.length - 1)
            Container(
              width: 18,
              height: 2,
              margin: const EdgeInsets.only(bottom: 18),
              color: index < currentStep
                  ? AppColors.success
                  : AppColors.divider,
            ),
        ],
      ],
    ),
  );

  IconData _iconFor(int index) => switch (index) {
    0 => Icons.directions_car_rounded,
    1 => Icons.place_rounded,
    2 => Icons.inventory_2_rounded,
    3 => Icons.local_shipping_rounded,
    _ => Icons.check_rounded,
  };
}
