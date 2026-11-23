import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safeshift_shared/safeshift_shared.dart';

void main() {
  const status = JobRatingStatus(
    canRate: true,
    rated: false,
    positiveTags: ['on_time', 'friendly'],
    negativeTags: ['late', 'rude'],
  );

  test('parses the server status', () {
    final parsed = JobRatingStatus.fromJson(const {
      'can_rate': true,
      'rated': true,
      'score': 4,
      'tags': ['on_time'],
      'comment': 'Nice',
      'positive_tags': ['on_time'],
      'negative_tags': ['late'],
    });
    expect(parsed.rated, isTrue);
    expect(parsed.score, 4);
    expect(parsed.tagsFor(5), ['on_time']);
    expect(parsed.tagsFor(2), ['late']);
    expect(ratingTagLabel('careful_handling'), 'Careful with items');
    expect(ratingTagLabel('some_new_tag'), 'Some new tag');
  });

  Widget host(JobRatingStatus s, List<Object?> sent) => MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        child: RatingPanel(
          title: 'Rate Juma',
          status: s,
          buttonBuilder: (label, onPressed, loading) =>
              FilledButton(onPressed: onPressed, child: Text(label)),
          onSubmit: (score, tags, comment) async => sent.addAll([score, tags]),
        ),
      ),
    ),
  );

  testWidgets('tags follow the score and the rating is sent', (tester) async {
    final sent = <Object?>[];
    await tester.pumpWidget(host(status, sent));
    expect(find.text('Submit rating'), findsNothing);

    await tester.tap(find.byTooltip('2 stars'));
    await tester.pumpAndSettle();
    expect(find.text('Late'), findsOneWidget);
    expect(find.text('Friendly'), findsNothing);

    await tester.tap(find.byTooltip('5 stars'));
    await tester.pumpAndSettle();
    expect(find.text('Late'), findsNothing);
    await tester.tap(find.text('Friendly'));
    await tester.pump();

    await tester.tap(find.text('Submit rating'));
    await tester.pumpAndSettle();
    expect(sent, [
      5,
      ['friendly'],
    ]);
    expect(find.text('Thanks for your rating'), findsOneWidget);
  });

  testWidgets('nothing is shown once rating is closed', (tester) async {
    await tester.pumpWidget(
      host(const JobRatingStatus(canRate: false, rated: false), []),
    );
    expect(find.byType(IconButton), findsNothing);
  });
}
