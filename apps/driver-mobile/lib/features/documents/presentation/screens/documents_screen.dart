import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/errors/error_handler.dart';
import '../../../../core/theme/text_styles.dart';
import '../../../../core/widgets/buttons/primary_button.dart';
import '../../../../core/widgets/cards/info_card.dart';
import '../../../../core/widgets/feedback/app_snackbar.dart';
import '../../../home/data/driver_repository.dart';
import '../../providers/documents_provider.dart';

/// Pushed route: driver documents with verification statuses.
class DocumentsScreen extends ConsumerWidget {
  const DocumentsScreen({super.key});

  Future<void> _reupload(
    BuildContext context,
    WidgetRef ref,
    DriverDocumentSnapshot doc,
  ) async {
    if (doc.documentTypeId.isEmpty) {
      AppSnackbar.showError(context, 'This document type is unavailable.');
      return;
    }
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 2000,
    );
    if (picked == null) return;
    try {
      final bytes = await picked.readAsBytes();
      await ref
          .read(documentsStateProvider.notifier)
          .upload(
            documentTypeId: doc.documentTypeId,
            bytes: bytes,
            fileName: picked.name,
            mimeType: picked.mimeType ?? 'image/jpeg',
          );
      if (context.mounted) {
        AppSnackbar.showSuccess(context, 'Document uploaded for review.');
      }
    } catch (error, stack) {
      if (context.mounted) {
        AppSnackbar.showError(
          context,
          ErrorHandler.map(error, stackTrace: stack).message,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final docsAsync = ref.watch(documentsStateProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Documents')),
      body: docsAsync.when(
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
                        ref.read(documentsStateProvider.notifier).refresh(),
                  ),
                ],
              ),
            ),
          );
        },
        data: (docs) => docs.isEmpty
            ? const Center(child: Text('No documents uploaded yet.'))
            : RefreshIndicator(
                onRefresh: () =>
                    ref.read(documentsStateProvider.notifier).refresh(),
                child: ListView.separated(
                  padding: const EdgeInsets.all(AppSizes.lg),
                  itemCount: docs.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: AppSizes.sm),
                  itemBuilder: (context, i) {
                    final doc = docs[i];
                    final color = switch (doc.status) {
                      'verified' => AppColors.success,
                      'pending' => AppColors.warning,
                      _ => AppColors.error,
                    };
                    final expiry = doc.expiresAt == null
                        ? 'No expiry'
                        : 'Expires ${doc.expiresAt!.toIso8601String().split('T').first}';
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
                                  '${doc.status} · $expiry',
                                  style: TextStyles.caption.copyWith(
                                    color: color,
                                  ),
                                ),
                                if (doc.rejectionReason != null)
                                  Text(
                                    doc.rejectionReason!,
                                    style: TextStyles.caption.copyWith(
                                      color: AppColors.error,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          TextButton(
                            onPressed: () => _reupload(context, ref, doc),
                            child: const Text('Re-upload'),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
      ),
    );
  }
}
