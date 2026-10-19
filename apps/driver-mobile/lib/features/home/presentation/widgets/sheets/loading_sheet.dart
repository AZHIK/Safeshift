import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

  static const List<String> _items = <String>[
    'Cargo matches the booking',
    'Fragile items secured',
    'Photos taken (mock)',
    'Customer confirmed load',
  ];

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
