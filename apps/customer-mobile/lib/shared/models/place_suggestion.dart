import 'package:flutter/foundation.dart';

import 'ride_place.dart';

/// A single autocomplete suggestion returned by the place provider.
///
/// Suggestions intentionally carry both structured text and the provider
/// place ID. Coordinates are resolved through Place Details only after the
/// customer taps a suggestion, which keeps autocomplete calls cheap and avoids
/// treating raw search text as a confirmed location.
@immutable
class PlaceSuggestion {
  const PlaceSuggestion({
    required this.placeId,
    required this.primaryText,
    required this.secondaryText,
    required this.description,
    this.types = const <String>[],
    this.distanceMeters,
    this.resolvedPlace,
  });

  /// Builds a suggestion from a place that is already resolved locally, such
  /// as a saved address or a catalog neighbourhood. These suggestions do not
  /// require a Place Details round-trip.
  factory PlaceSuggestion.fromRidePlace(
    RidePlace place, {
    String? primaryText,
    String? secondaryText,
  }) {
    final title = (primaryText ?? place.name).trim();
    final fallbackSubtitle = place.addressLine.isNotEmpty
        ? place.addressLine
        : place.district.isNotEmpty &&
              place.district.toLowerCase() != title.toLowerCase()
        ? place.district
        : place.isSaved
        ? 'Saved place'
        : place.isCatalog
        ? 'SafeShift area'
        : 'Selected location';
    final subtitle = (secondaryText ?? fallbackSubtitle).trim();
    return PlaceSuggestion(
      placeId: place.placeId ?? '',
      primaryText: title,
      secondaryText: subtitle,
      description: place.formattedAddress ?? subtitle,
      types: place.types.isEmpty
          ? <String>[place.isCatalog ? 'catalog_place' : 'saved_place']
          : place.types,
      resolvedPlace: place,
    );
  }

  /// Provider place ID. Empty for locally resolved saved/catalog places.
  final String placeId;

  /// Main line, for example "Mlimani City Shopping Mall".
  final String primaryText;

  /// Context line, for example "Sam Nujoma Road, Dar es Salaam, Tanzania".
  final String secondaryText;

  /// Full provider description.
  final String description;

  /// Provider types such as `shopping_mall`, `university`, `bus_station`.
  final List<String> types;

  /// Straight-line distance from the search reference, when provided.
  final double? distanceMeters;

  /// Set for saved/catalog places that already have coordinates.
  final RidePlace? resolvedPlace;

  bool get isResolved => resolvedPlace != null;

  bool get hasPlaceId => placeId.trim().isNotEmpty;

  String get title {
    final primary = primaryText.trim();
    if (primary.isNotEmpty) return primary;
    final full = description.trim();
    if (full.isNotEmpty) return full.split(',').first.trim();
    return 'Selected location';
  }

  String get subtitle {
    final secondary = secondaryText.trim();
    if (secondary.isNotEmpty) return secondary;
    final full = description.trim();
    if (full.isNotEmpty && full.toLowerCase() != title.toLowerCase()) {
      return full;
    }
    return 'Tap to see details';
  }

  /// True when the suggestion has enough context to avoid an ambiguous
  /// "place name only" row.
  bool get hasUsefulContext {
    final secondary = subtitle.trim();
    return secondary.isNotEmpty &&
        secondary.toLowerCase() != title.toLowerCase() &&
        secondary.toLowerCase() != 'tap to see details';
  }

  @override
  String toString() => 'PlaceSuggestion($placeId, $title)';
}
