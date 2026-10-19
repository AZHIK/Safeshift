import 'package:flutter/material.dart';

import '../../constants/app_colors.dart';
import '../../constants/app_sizes.dart';
import '../../theme/text_styles.dart';
import '../../../shared/mock/mock_locations.dart';

Future<void> showAddressSuggestionSheet({
  required BuildContext context,
  required ValueChanged<MockLocation> onSelected,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  backgroundColor: Colors.transparent,
  builder: (_) => AddressSuggestionSheet(onSelected: onSelected),
);

class AddressSuggestionSheet extends StatefulWidget {
  const AddressSuggestionSheet({super.key, required this.onSelected});
  final ValueChanged<MockLocation> onSelected;

  @override
  State<AddressSuggestionSheet> createState() => _AddressSuggestionSheetState();
}

class _AddressSuggestionSheetState extends State<AddressSuggestionSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final matches = mockLocations
        .where(
          (location) => '${location.name} ${location.district}'
              .toLowerCase()
              .contains(_query.toLowerCase()),
        )
        .toList();
    return SafeArea(
      child: Container(
        height: MediaQuery.sizeOf(context).height * 0.78,
        padding: const EdgeInsets.fromLTRB(
          AppSizes.lg,
          AppSizes.md,
          AppSizes.lg,
          AppSizes.md,
        ),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: AppSizes.lg),
            Text(
              'Choose a location',
              style: TextStyles.title.copyWith(fontSize: 18),
            ),
            const SizedBox(height: AppSizes.md),
            TextField(
              autofocus: true,
              onChanged: (value) => setState(() => _query = value),
              decoration: const InputDecoration(
                hintText: 'Search places in Dar es Salaam',
                prefixIcon: Icon(Icons.search_rounded),
              ),
            ),
            const SizedBox(height: AppSizes.sm),
            Expanded(
              child: ListView.separated(
                itemCount: matches.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final location = matches[index];
                  return Material(
                    color: AppColors.surface,
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(
                        Icons.location_on_outlined,
                        color: AppColors.primary,
                      ),
                      title: Text(
                        location.name,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(location.district),
                      onTap: () {
                        widget.onSelected(location);
                        Navigator.pop(context);
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
