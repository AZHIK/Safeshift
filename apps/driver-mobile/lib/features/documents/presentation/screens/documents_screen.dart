import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/theme/text_styles.dart';
import '../../../../core/widgets/cards/info_card.dart';
import '../../../../core/widgets/feedback/app_snackbar.dart';
import '../../providers/documents_provider.dart';

/// Pushed route: driver documents with verification statuses.
class DocumentsScreen extends ConsumerWidget {
  const DocumentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final docs = ref.watch(documentsStateProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Documents')),
      body: ListView.separated(
        padding: const EdgeInsets.all(AppSizes.lg),
        itemCount: docs.length,
        separatorBuilder: (_, _) => const SizedBox(height: AppSizes.sm),
        itemBuilder: (context, i) {
          final doc = docs[i];
          final color = switch (doc.status) {
            'verified' => AppColors.success,
            'pending' => AppColors.warning,
            _ => AppColors.error,
          };
          return InfoCard(
            padding: 14,
            child: Row(
              children: [
                Icon(Icons.badge_rounded, color: color),
                const SizedBox(width: AppSizes.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(doc.title, style: TextStyles.title),
                      Text(
                        '${doc.status} · ${doc.expiry}',
                        style: TextStyles.caption.copyWith(color: color),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () => AppSnackbar.showInfo(
                    context,
                    'Re-upload ${doc.title} (mock)',
                  ),
                  child: const Text('Re-upload'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
