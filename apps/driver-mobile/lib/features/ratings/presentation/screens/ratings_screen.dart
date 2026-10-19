import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/theme/text_styles.dart';
import '../../../../core/widgets/cards/info_card.dart';
import '../../../../shared/mock/mock_driver.dart';
import '../../providers/ratings_provider.dart';

/// Pushed route: recent customer ratings.
class RatingsScreen extends ConsumerWidget {
  const RatingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ratings = ref.watch(ratingsStateProvider);
    final average =
        ref.read(ratingsStateProvider.notifier).averageRating();
    return Scaffold(
      appBar: AppBar(title: const Text('Ratings')),
      body: ListView(
        padding: const EdgeInsets.all(AppSizes.lg),
        children: [
          InfoCard(
            child: Row(
              children: [
                Text(
                  average.toStringAsFixed(1),
                  style: TextStyles.display.copyWith(fontSize: 40),
                ),
                const SizedBox(width: AppSizes.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: List.generate(
                          5,
                          (i) => Icon(
                            Icons.star_rounded,
                            size: 20,
                            color: average.round() > i
                                ? const Color(0xFFFFB300)
                                : AppColors.divider,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${ratings.length} recent ratings · ${mockDriver.completedTrips} trips',
                        style: TextStyles.caption.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSizes.md),
          for (final rating in ratings) ...[
            InfoCard(
              padding: 14,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          rating.customerName,
                          style: TextStyles.title,
                        ),
                      ),
                      Row(
                        children: List.generate(
                          5,
                          (i) => Icon(
                            Icons.star_rounded,
                            size: 14,
                            color: rating.stars > i
                                ? const Color(0xFFFFB300)
                                : AppColors.divider,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(rating.comment, style: TextStyles.body),
                  const SizedBox(height: 4),
                  Text(
                    DateFormat('d MMM yyyy').format(rating.date),
                    style: TextStyles.caption.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSizes.sm),
          ],
        ],
      ),
    );
  }
}
