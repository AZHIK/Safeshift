import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:safeshift_shared/safeshift_shared.dart';

import '../../../../core/config/env_config.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/widgets/cards/status_pill.dart';
import '../../../booking/domain/entities/job.dart';

/// Supabase project URL used to resolve the icons the catalogue serves.
final _iconBaseUrl = EnvConfig.current.supabaseUrl;

class HistoryJobTile extends StatelessWidget {
  const HistoryJobTile({super.key, required this.job, required this.onTap});
  final Job job;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Container(
              width: 42,
              height: 42,
              decoration: const BoxDecoration(
                color: Color(0xFFE8F4FD),
                shape: BoxShape.circle,
              ),
              // The icon comes from the vehicle category row in the database.
              child: CatalogIcon(
                iconUrl: job.vehicleClassIconUrl,
                supabaseUrl: _iconBaseUrl,
                fallbackIcon: Icons.local_shipping_rounded,
                color: AppColors.primaryDark,
                size: 21,
              ),
            ),
            const SizedBox(width: AppSizes.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    job.pickupAddress,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: <Widget>[
                      const Icon(
                        Icons.south_rounded,
                        size: 13,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          job.destinationAddress,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSizes.sm),
                  Text(
                    DateFormat('d MMM yyyy')
                        .format(job.createdAt ?? DateTime.now()),
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'TZS ${NumberFormat('#,##0').format(job.quoteAmount)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSizes.xs),
            StatusPill(status: job.status),
          ],
        ),
      ),
    ),
  );
}
