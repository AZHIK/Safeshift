import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safeshift_shared/safeshift_shared.dart';

void main() {
  testWidgets('an empty vehicle catalogue explains itself', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: CatalogEmptyNotice(kind: CatalogKind.vehicles),
        ),
      ),
    );

    expect(find.text('No vehicles available yet'), findsOneWidget);
    expect(
      find.textContaining('No vehicle categories are published'),
      findsOneWidget,
    );
  });

  testWidgets('an empty cargo catalogue explains itself', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: CatalogEmptyNotice(kind: CatalogKind.cargo),
        ),
      ),
    );

    expect(find.text('No cargo types available yet'), findsOneWidget);
    expect(find.textContaining('No cargo types are published'), findsOneWidget);
  });

  testWidgets('the wording can be overridden', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: CatalogEmptyNotice(
            kind: CatalogKind.vehicles,
            message: 'Contact support to get one added.',
          ),
        ),
      ),
    );

    expect(find.text('Contact support to get one added.'), findsOneWidget);
    expect(find.text('No vehicles available yet'), findsOneWidget);
  });
}
