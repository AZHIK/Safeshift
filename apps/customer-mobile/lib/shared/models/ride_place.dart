import 'package:flutter/foundation.dart';

/// How a [RidePlace] was obtained.
///
/// This lets courier flows distinguish a provider-verified place from a raw
/// GPS fix or a point the customer pinned manually on the map.
enum RidePlaceSource {
  /// Selected from a provider (for example Google Places). It has a place ID.
  provider,

  /// Loaded from the customer's saved addresses.
  saved,

  /// A SafeShift directory entry (neighbourhood, landmark, terminal, ...).
  catalog,

  /// The device's current GPS coordinate.
  gps,

  /// A coordinate the customer explicitly confirmed on the map.
  map,
}

/// A selectable place/address used by ride and booking flows.
///
/// Replaces mock locations with real data from the mapping provider,
/// `saved_addresses`, or the device GPS.
@immutable
class RidePlace {
  const RidePlace({
    required this.id,
    required this.name,
    required this.district,
    required this.latitude,
    required this.longitude,
    this.addressId,
    this.label,
    this.placeId,
    this.formattedAddress,
    this.street,
    this.neighborhood,
    this.ward,
    this.city,
    this.region,
    this.country,
    this.postalCode,
    this.source = RidePlaceSource.provider,
    this.accuracyMeters,
    this.capturedAt,
    this.types = const <String>[],
  });

  final String id;
  final String name;

  /// Short human-readable context used by legacy UI (neighbourhood or city).
  final String district;
  final double latitude;
  final double longitude;

  /// Underlying `addresses.id` when backed by a saved/database address.
  final String? addressId;

  /// User label (Home, Work, ...) for saved places.
  final String? label;

  /// Provider place ID (Google `place_id`), when available.
  final String? placeId;
  final String? formattedAddress;
  final String? street;
  final String? neighborhood;

  /// Ward / administrative area (Tanzania `administrative_area_level_3`).
  final String? ward;
  final String? city;
  final String? region;
  final String? country;
  final String? postalCode;
  final RidePlaceSource source;

  /// Horizontal GPS accuracy in metres, for [RidePlaceSource.gps].
  final double? accuracyMeters;

  /// When the coordinate was captured, for GPS/map selections.
  final DateTime? capturedAt;

  /// Provider place types (for example `shopping_mall`, `university`).
  final List<String> types;

  bool get hasCoordinates =>
      latitude.isFinite &&
      longitude.isFinite &&
      latitude >= -90 &&
      latitude <= 90 &&
      longitude >= -180 &&
      longitude <= 180;

  bool get isProviderVerified =>
      source == RidePlaceSource.provider &&
      (placeId?.trim().isNotEmpty ?? false);

  bool get isGps => source == RidePlaceSource.gps;
  bool get isMapPoint => source == RidePlaceSource.map;
  bool get isSaved => source == RidePlaceSource.saved;
  bool get isCatalog => source == RidePlaceSource.catalog;

  /// Full readable address assembled from structured components.
  ///
  /// Provider place names are intentionally excluded so a courier sees the
  /// street, neighbourhood, city, and country rather than only the landmark.
  String get addressLine {
    final parts = <String>[];
    void add(String? value) {
      final text = value?.trim() ?? '';
      if (text.isEmpty) return;
      if (parts.isNotEmpty && parts.last.toLowerCase() == text.toLowerCase()) {
        return;
      }
      parts.add(text);
    }

    add(street);
    add(neighborhood);
    add(ward);
    add(city);
    add(region);
    add(country);
    if (parts.isNotEmpty) return parts.join(', ');
    return formattedAddress?.trim() ?? '';
  }

  /// A concise subtitle suitable for compact list tiles.
  String get subtitle {
    if (addressLine.isNotEmpty) return addressLine;
    if (district.isNotEmpty) return district;
    return name;
  }

  /// Human-readable coordinates, used when an address cannot be resolved.
  String get coordinateLabel =>
      '${latitude.toStringAsFixed(5)}, ${longitude.toStringAsFixed(5)}';

  RidePlace copyWith({
    String? id,
    String? name,
    String? district,
    double? latitude,
    double? longitude,
    String? addressId,
    String? label,
    String? placeId,
    String? formattedAddress,
    String? street,
    String? neighborhood,
    String? ward,
    String? city,
    String? region,
    String? country,
    String? postalCode,
    RidePlaceSource? source,
    double? accuracyMeters,
    DateTime? capturedAt,
    List<String>? types,
    bool clearPlaceId = false,
  }) {
    return RidePlace(
      id: id ?? this.id,
      name: name ?? this.name,
      district: district ?? this.district,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      addressId: addressId ?? this.addressId,
      label: label ?? this.label,
      placeId: clearPlaceId ? null : (placeId ?? this.placeId),
      formattedAddress: formattedAddress ?? this.formattedAddress,
      street: street ?? this.street,
      neighborhood: neighborhood ?? this.neighborhood,
      ward: ward ?? this.ward,
      city: city ?? this.city,
      region: region ?? this.region,
      country: country ?? this.country,
      postalCode: postalCode ?? this.postalCode,
      source: source ?? this.source,
      accuracyMeters: accuracyMeters ?? this.accuracyMeters,
      capturedAt: capturedAt ?? this.capturedAt,
      types: types ?? this.types,
    );
  }

  @override
  String toString() => 'RidePlace($name, $latitude, $longitude, $source)';
}
