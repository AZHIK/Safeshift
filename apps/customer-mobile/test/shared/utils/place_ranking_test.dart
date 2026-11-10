import 'package:flutter_test/flutter_test.dart';
import 'package:safeshift_customer/shared/models/place_suggestion.dart';
import 'package:safeshift_customer/shared/utils/place_ranking.dart';

PlaceSuggestion _suggestion({
  required String id,
  required String title,
  required String subtitle,
  double? distanceMeters,
}) {
  return PlaceSuggestion(
    placeId: id,
    primaryText: title,
    secondaryText: subtitle,
    description: '$title, $subtitle',
    distanceMeters: distanceMeters,
  );
}

void main() {
  group('rankAndDedupeSuggestions', () {
    test('deduplicates by place id and by visible text', () {
      final results = rankAndDedupeSuggestions(<PlaceSuggestion>[
        _suggestion(
          id: 'p1',
          title: 'Mlimani City',
          subtitle: 'Dar es Salaam, Tanzania',
        ),
        _suggestion(
          id: 'p1',
          title: 'Mlimani City',
          subtitle: 'Dar es Salaam, Tanzania',
        ),
        _suggestion(
          id: 'p2',
          title: 'Mlimani City',
          subtitle: 'Dar es Salaam, Tanzania',
        ),
      ], query: 'Mlimani');

      expect(results, hasLength(1));
      expect(results.single.placeId, 'p1');
    });

    test('ranks an exact/prefix text match above a weak match', () {
      final results = rankAndDedupeSuggestions(<PlaceSuggestion>[
        _suggestion(
          id: 'p1',
          title: 'City Mall',
          subtitle: 'Mlimani area, Dar es Salaam',
        ),
        _suggestion(
          id: 'p2',
          title: 'Mlimani City Shopping Mall',
          subtitle: 'Sam Nujoma Road, Dar es Salaam',
        ),
      ], query: 'Mlimani');

      expect(results.first.placeId, 'p2');
    });

    test('uses provider distance as a proximity tie-breaker', () {
      final results = rankAndDedupeSuggestions(<PlaceSuggestion>[
        _suggestion(
          id: 'far',
          title: 'Dodoma Hotel',
          subtitle: 'Dodoma, Tanzania',
          distanceMeters: 20000,
        ),
        _suggestion(
          id: 'near',
          title: 'Dodoma Lodge',
          subtitle: 'Dodoma, Tanzania',
          distanceMeters: 500,
        ),
      ], query: 'Dodoma');

      expect(results.first.placeId, 'near');
    });

    test('drops ambiguous suggestions with only a place name', () {
      final results = rankAndDedupeSuggestions(const <PlaceSuggestion>[
        PlaceSuggestion(
          placeId: 'bad',
          primaryText: 'Mlimani',
          secondaryText: '',
          description: 'Mlimani',
        ),
        PlaceSuggestion(
          placeId: 'good',
          primaryText: 'Mlimani City Shopping Mall',
          secondaryText: 'Sam Nujoma Road, Dar es Salaam, Tanzania',
          description: 'Mlimani City Shopping Mall, Dar es Salaam',
        ),
      ], query: 'Mlimani');

      expect(results, hasLength(1));
      expect(results.single.placeId, 'good');
    });

    test('keeps the provider order for equal relevance', () {
      final results = rankAndDedupeSuggestions(<PlaceSuggestion>[
        _suggestion(id: 'a', title: 'Place A', subtitle: 'Dar es Salaam'),
        _suggestion(id: 'b', title: 'Place B', subtitle: 'Dar es Salaam'),
      ], query: 'Kariakoo');

      expect(results.map((item) => item.placeId), <String>['a', 'b']);
    });
  });
}
