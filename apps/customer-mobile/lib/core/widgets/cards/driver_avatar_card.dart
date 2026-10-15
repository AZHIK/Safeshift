import 'package:flutter/material.dart';

import '../../constants/app_colors.dart';
import '../../constants/app_sizes.dart';
import '../../theme/text_styles.dart';
import '../../widgets/feedback/app_snackbar.dart';
import '../../../features/tracking/domain/entities/driver.dart';

class DriverAvatarCard extends StatelessWidget {
  const DriverAvatarCard({
    super.key,
    required this.driver,
    this.showActions = false,
  });
  final Driver driver;
  final bool showActions;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(AppSizes.md),
      child: Row(
        children: <Widget>[
          CircleAvatar(
            radius: 26,
            backgroundColor: AppColors.primary.withValues(alpha: 0.12),
            child: Text(
              driver.initials,
              style: TextStyles.title.copyWith(color: AppColors.primaryDark),
            ),
          ),
          const SizedBox(width: AppSizes.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        driver.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyles.title,
                      ),
                    ),
                    if (driver.verified)
                      const Tooltip(
                        message: 'Verified driver',
                        child: Icon(
                          Icons.verified_rounded,
                          size: 16,
                          color: AppColors.primary,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 3),
                Row(
                  children: <Widget>[
                    const Icon(
                      Icons.star_rounded,
                      size: 16,
                      color: Color(0xFFFFB300),
                    ),
                    Expanded(
                      child: Text(
                        ' ${driver.rating.toStringAsFixed(1)}  ·  ${driver.vehicleClass}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyles.caption.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  '${driver.completedTrips} completed trips',
                  style: TextStyles.caption.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          if (showActions) ...<Widget>[
            IconButton(
              tooltip: 'Call driver',
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints.tightFor(width: 36, height: 36),
              onPressed: () => AppSnackbar.showInfo(
                context,
                'Calling ${driver.name} (mock)',
              ),
              icon: const Icon(Icons.call_outlined),
            ),
            IconButton(
              tooltip: 'Message driver',
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints.tightFor(width: 36, height: 36),
              onPressed: () => AppSnackbar.showInfo(
                context,
                'Messaging ${driver.name} (mock)',
              ),
              icon: const Icon(Icons.chat_bubble_outline_rounded),
            ),
          ],
        ],
      ),
    ),
  );
}
