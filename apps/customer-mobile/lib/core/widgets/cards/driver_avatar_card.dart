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
            backgroundColor: context.colors.primary.withValues(alpha: 0.12),
            child: Text(
              driver.initials,
              style: TextStyles.title.copyWith(color: context.colors.primary),
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
                      Tooltip(
                        message: 'Verified driver',
                        child: Icon(
                          Icons.verified_rounded,
                          size: 16,
                          color: context.colors.primary,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 3),
                Row(
                  children: <Widget>[
                    Icon(
                      Icons.star_rounded,
                      size: 16,
                      color: context.colors.tertiary,
                    ),
                    Expanded(
                      child: Text(
                        ' ${driver.rating > 0 ? driver.rating.toStringAsFixed(1) : 'New'}  ·  ${driver.vehicleClass}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyles.caption.copyWith(
                          color: context.colors.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  '${driver.completedTrips} completed trips',
                  style: TextStyles.caption.copyWith(
                    color: context.colors.onSurfaceVariant,
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
              onPressed: () =>
                  AppSnackbar.showInfo(context, 'Calling is not available yet'),
              icon: const Icon(Icons.call_outlined),
            ),
            IconButton(
              tooltip: 'Message driver',
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints.tightFor(width: 36, height: 36),
              onPressed: () => AppSnackbar.showInfo(
                context,
                'Messaging is not available yet',
              ),
              icon: const Icon(Icons.chat_bubble_outline_rounded),
            ),
          ],
        ],
      ),
    ),
  );
}
