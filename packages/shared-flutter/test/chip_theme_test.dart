import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safeshift_shared/safeshift_shared.dart';

void main() {
  // Regression: the chip theme's labelStyle had no colour, so labels rendered
  // white on the white light-mode chip (rating quick tags were invisible).
  for (final theme in [AppTheme.lightTheme, AppTheme.darkTheme]) {
    final mode = theme.brightness.name;

    testWidgets('chip labels use the on-surface colour ($mode)', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: Scaffold(
            body: Wrap(
              children: [
                FilterChip(
                  label: const Text('Unselected'),
                  selected: false,
                  onSelected: (_) {},
                ),
                FilterChip(
                  label: const Text('Selected'),
                  selected: true,
                  onSelected: (_) {},
                ),
              ],
            ),
          ),
        ),
      );

      for (final label in ['Unselected', 'Selected']) {
        final style = DefaultTextStyle.of(tester.element(find.text(label)))
            .style;
        expect(style.color, theme.colorScheme.onSurface, reason: label);
        expect(style.color, isNot(theme.chipTheme.backgroundColor));
      }
    });
  }
}
