import '../models/place_suggestion.dart';

/// Deduplicates and ranks provider suggestions.
///
/// Google already applies the location bias supplied in the request. This
/// client-side pass protects against duplicate rows, gives exact/prefix
/// matches a small boost, and (when the provider returns `distance_meters`)
/// nudges nearby places above equally relevant far-away ones.
List<PlaceSuggestion> rankAndDedupeSuggestions(
  Iterable<PlaceSuggestion> suggestions, {
  required String query,
  int limit = 10,
}) {
  final seenPlaceIds = <String>{};
  final seenText = <String>{};
  final unique = <PlaceSuggestion>[];

  for (final suggestion in suggestions) {
    // Never show an ambiguous "place name only" row. Locally resolved saved
    // places are exempt because the customer already knows what they are.
    if (!suggestion.isResolved && !suggestion.hasUsefulContext) continue;

    final placeId = suggestion.placeId.trim();
    if (placeId.isNotEmpty && !seenPlaceIds.add(placeId)) continue;

    final textKey = _normalize('${suggestion.title}|${suggestion.subtitle}');
    if (!seenText.add(textKey)) continue;
    unique.add(suggestion);
  }

  final scored = <_ScoredSuggestion>[];
  for (var index = 0; index < unique.length; index++) {
    scored.add(
      _ScoredSuggestion(
        suggestion: unique[index],
        score: _score(unique[index], query),
        index: index,
      ),
    );
  }

  scored.sort((a, b) {
    final byScore = b.score.compareTo(a.score);
    if (byScore != 0) return byScore;
    // Keep the provider's relevance order for ties.
    return a.index.compareTo(b.index);
  });

  return scored
      .take(limit)
      .map((entry) => entry.suggestion)
      .toList(growable: false);
}

double _score(PlaceSuggestion suggestion, String query) {
  final normalizedQuery = _normalize(query);
  if (normalizedQuery.isEmpty) return 0;

  final title = _normalize(suggestion.title);
  final subtitle = _normalize(suggestion.subtitle);

  var textScore = 0.0;
  if (title == normalizedQuery) {
    textScore += 6;
  } else if (title.startsWith(normalizedQuery)) {
    textScore += 4;
  } else if (title.contains(normalizedQuery)) {
    textScore += 2.5;
  } else if (subtitle.contains(normalizedQuery)) {
    textScore += 1.2;
  }

  final tokens = normalizedQuery
      .split(RegExp(r'\s+'))
      .where((token) => token.isNotEmpty)
      .toList(growable: false);
  if (tokens.isNotEmpty) {
    final matches = tokens
        .where((token) => title.contains(token) || subtitle.contains(token))
        .length;
    textScore += (matches / tokens.length) * 2;
  }

  var proximityScore = 0.0;
  final distance = suggestion.distanceMeters;
  if (distance != null && distance.isFinite && distance >= 0) {
    // 0 km -> 1.0, 5 km -> 0.5, 20 km -> 0.2.
    proximityScore = 1 / (1 + distance / 5000);
  }

  return textScore * 10 + proximityScore * 3;
}

String _normalize(String value) {
  return value
      .toLowerCase()
      .replaceAll(RegExp(r'[^\w\s]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

class _ScoredSuggestion {
  const _ScoredSuggestion({
    required this.suggestion,
    required this.score,
    required this.index,
  });

  final PlaceSuggestion suggestion;
  final double score;
  final int index;
}
