import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../../core/constants/app_colors.dart';
import '../../../../../core/constants/app_sizes.dart';
import '../../../../../core/theme/text_styles.dart';
import '../../../../../core/widgets/buttons/primary_button.dart';
import '../../../../../core/widgets/cards/info_card.dart';
import '../../../providers/home_provider.dart';
import 'sheet_handle.dart';

/// Loading checklist sheet.
class LoadingSheet extends ConsumerStatefulWidget {
  const LoadingSheet({super.key});

  @override
  ConsumerState<LoadingSheet> createState() => _LoadingSheetState();
}

class _LoadingSheetState extends ConsumerState<LoadingSheet> {
  final List<bool> _checked = <bool>[false, false, false, false];
  bool _uploading = false;

  static const List<String> _items = <String>[
    'Cargo matches the booking',
    'Fragile items secured',
    'Cargo photos uploaded',
    'Customer confirmed load',
  ];

  Future<void> _uploadPhoto() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
      maxWidth: 2000,
    );
    if (picked == null) return;
    setState(() => _uploading = true);
    final ok = await ref
        .read(homeProvider.notifier)
        .uploadEvidence(
          evidenceType: 'pickup_photo',
          bytes: await picked.readAsBytes(),
          fileName: picked.name,
          mimeType: picked.mimeType ?? 'image/jpeg',
        );
    if (!mounted) return;
    setState(() {
      _uploading = false;
      if (ok) _checked[2] = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final allChecked = _checked.every((c) => c);
    return ListView(
      shrinkWrap: true,
      physics: const ClampingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        AppSizes.lg,
        AppSizes.sm,
        AppSizes.lg,
        AppSizes.lg,
      ),
      children: [
        const SheetHandle(),
        Text('Loading', style: TextStyles.headline.copyWith(fontSize: 18)),
        const SizedBox(height: AppSizes.sm),
        InfoCard(
          child: Column(
            children: [
              for (var i = 0; i < _items.length; i++)
                CheckboxListTile(
                  value: _checked[i],
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  activeColor: AppColors.onlineGreen,
                  title: Text(_items[i], style: TextStyles.body),
                  onChanged: (v) =>
                      setState(() => _checked[i] = v ?? false),
                ),
            ],
          ),
        ),
        const SizedBox(height: AppSizes.sm),
        OutlinedButton.icon(
          onPressed: _uploading ? null : _uploadPhoto,
          icon: const Icon(Icons.photo_camera_outlined),
          label: Text(_uploading ? 'Uploading…' : 'Take cargo photo'),
        ),
        const SizedBox(height: AppSizes.md),
        PrimaryButton(
          label: 'Confirm loaded',
          icon: Icons.inventory_rounded,
          onPressed: allChecked
              ? () => ref.read(homeProvider.notifier).advanceStage()
              : null,
        ),
      ],
    );
  }
}
