import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/theme/text_styles.dart';
import '../../../../core/widgets/buttons/primary_button.dart';
import '../../providers/ride_provider.dart';

final _tzs = NumberFormat('#,##0');

/// Opens the parcel-details dialog (NOT a new screen): description,
/// photos, weight and approximate value. Stays on top of RideScreen.
Future<void> showParcelDialog(BuildContext context, WidgetRef ref) =>
    showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (_) => const _ParcelDialog(),
    );

class _ParcelDialog extends ConsumerStatefulWidget {
  const _ParcelDialog();

  @override
  ConsumerState<_ParcelDialog> createState() => _ParcelDialogState();
}

class _ParcelDialogState extends ConsumerState<_ParcelDialog> {
  late final TextEditingController _desc;
  late final TextEditingController _weight;
  late final TextEditingController _value;
  final _picker = ImagePicker();
  bool _picking = false;
  static const int _maxPhotos = 4;

  @override
  void initState() {
    super.initState();
    final ride = ref.read(rideProvider);
    _desc = TextEditingController(text: ride.parcelDescription ?? '');
    _weight = TextEditingController(
      text: ride.parcelWeightKg != null
          ? ride.parcelWeightKg!.toStringAsFixed(
              ride.parcelWeightKg! % 1 == 0 ? 0 : 1,
            )
          : '',
    );
    _value = TextEditingController(
      text: ride.parcelValueTzs != null ? '${ride.parcelValueTzs}' : '',
    );
  }

  @override
  void dispose() {
    _desc.dispose();
    _weight.dispose();
    _value.dispose();
    super.dispose();
  }

  Future<void> _pickPhotos() async {
    if (_picking) return;
    final current = ref.read(rideProvider).parcelPhotoPaths;
    final remaining = _maxPhotos - current.length;
    if (remaining <= 0) return;
    setState(() => _picking = true);
    try {
      final files = await _picker.pickMultiImage(
        maxWidth: 1280,
        maxHeight: 1280,
        imageQuality: 82,
      );
      if (files.isNotEmpty) {
        final paths = [
          ...current,
          ...files.take(remaining).map((f) => f.path),
        ];
        ref.read(rideProvider.notifier).setParcelDetails(photoPaths: paths);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open gallery (mock)')),
        );
      }
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  Future<void> _takePhoto() async {
    if (_picking) return;
    final current = ref.read(rideProvider).parcelPhotoPaths;
    if (current.length >= _maxPhotos) return;
    setState(() => _picking = true);
    try {
      final file = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1280,
        maxHeight: 1280,
        imageQuality: 82,
      );
      if (file != null) {
        ref
            .read(rideProvider.notifier)
            .setParcelDetails(photoPaths: [...current, file.path]);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Camera unavailable (mock)')),
        );
      }
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  void _save() {
    final weight = double.tryParse(_weight.text.trim().replaceAll(',', '.'));
    final valueText = _value.text.trim().replaceAll(RegExp(r'[^0-9]'), '');
    final value = valueText.isEmpty ? null : int.tryParse(valueText);
    ref.read(rideProvider.notifier).setParcelDetails(
      description: _desc.text.trim().isEmpty ? null : _desc.text.trim(),
      weightKg: weight != null && weight > 0 ? weight : null,
      valueTzs: value != null && value >= 0 ? value : null,
    );
    // Keep existing photos (already in provider via picker).
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final ride = ref.watch(rideProvider);
    final photos = ride.parcelPhotoPaths;
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 440, maxHeight: 620),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(26),
          boxShadow: AppColors.cardShadow,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header.
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 12, 0),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      gradient: AppColors.brandGradient,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: AppColors.cardShadow,
                    ),
                    child: const Icon(
                      Icons.inventory_2_rounded,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Describe your parcel', style: TextStyles.title),
                        Text(
                          'Photos · weight · value',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                children: [
                  const Text(
                    'What are you moving?',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _desc,
                    maxLines: 3,
                    minLines: 2,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      hintText:
                          'e.g. 2-seater sofa + 4 boxes of kitchenware, fragile glassware on top',
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Photos (up to 4)',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 84,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: photos.length + 1,
                      separatorBuilder: (_, _) => const SizedBox(width: 8),
                      itemBuilder: (context, i) {
                        if (i >= photos.length) {
                          return _AddPhotoTile(
                            loading: _picking,
                            onGallery: _pickPhotos,
                            onCamera: _takePhoto,
                          );
                        }
                        final path = photos[i];
                        return _PhotoThumb(
                          path: path,
                          onRemove: () {
                            final next = [...photos]..removeAt(i);
                            ref
                                .read(rideProvider.notifier)
                                .setParcelDetails(photoPaths: next);
                          },
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Weight (kg)',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _weight,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              decoration: const InputDecoration(
                                hintText: 'e.g. 120',
                                suffixText: 'kg',
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Approx. value (TZS)',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _value,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                hintText: 'e.g. 850000',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (ride.parcelValueTzs != null ||
                      _value.text.trim().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'Declared: TZS ${_tzs.format(int.tryParse(_value.text.trim().replaceAll(RegExp(r'[^0-9]'), '')) ?? ride.parcelValueTzs ?? 0)} · helps with handling & claims',
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
              child: Row(
                children: [
                  if (ride.hasParcelDetails)
                    TextButton(
                      onPressed: () {
                        ref
                            .read(rideProvider.notifier)
                            .clearParcelDetails();
                        _desc.clear();
                        _weight.clear();
                        _value.clear();
                      },
                      child: const Text('Clear'),
                    ),
                  const Spacer(),
                  SizedBox(
                    width: 170,
                    child: PrimaryButton(
                      compact: true,
                      label: 'Save details',
                      onPressed: _save,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddPhotoTile extends StatelessWidget {
  const _AddPhotoTile({
    required this.loading,
    required this.onGallery,
    required this.onCamera,
  });
  final bool loading;
  final VoidCallback onGallery;
  final VoidCallback onCamera;

  @override
  Widget build(BuildContext context) => Container(
    width: 150,
    decoration: BoxDecoration(
      color: AppColors.background,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppColors.divider),
    ),
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
    child: loading
        ? const Center(
            child: SizedBox.square(
              dimension: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          )
        : Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: onGallery,
                  borderRadius: BorderRadius.circular(10),
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.photo_library_outlined,
                        color: AppColors.primaryDark,
                      ),
                      SizedBox(height: 4),
                      Text('Gallery',
                          style: TextStyle(
                              fontSize: 10, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              ),
              const VerticalDivider(width: 8),
              Expanded(
                child: InkWell(
                  onTap: onCamera,
                  borderRadius: BorderRadius.circular(10),
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.photo_camera_outlined,
                        color: AppColors.primaryDark,
                      ),
                      SizedBox(height: 4),
                      Text('Camera',
                          style: TextStyle(
                              fontSize: 10, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              ),
            ],
          ),
  );
}

class _PhotoThumb extends StatelessWidget {
  const _PhotoThumb({required this.path, required this.onRemove});
  final String path;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final file = File(path);
    final exists = file.existsSync();
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: exists
              ? Image.file(
                  file,
                  width: 84,
                  height: 84,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => _fallback(),
                )
              : _fallback(),
        ),
        Positioned(
          top: 4,
          right: 4,
          child: GestureDetector(
            onTap: onRemove,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: AppColors.textPrimary,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.close_rounded,
                size: 14,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _fallback() => Container(
    width: 84,
    height: 84,
    color: AppColors.background,
    child: const Icon(
      Icons.image_outlined,
      color: AppColors.textSecondary,
    ),
  );
}
