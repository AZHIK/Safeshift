import 'package:flutter/foundation.dart';

/// A vehicle category — one row of `public.vehicle_types`.
///
/// The catalogue lives in the database, so an app never carries a hard-coded
/// list of vehicle classes. Everything the UI shows (name, description,
/// capacity bounds, icon) comes from the row.
@immutable
class VehicleTypeOption {
  const VehicleTypeOption({
    required this.id,
    required this.code,
    required this.name,
    this.description = '',
    this.iconUrl,
    this.capacityKgMin = 0,
    this.capacityKgMax = 0,
    this.displayOrder = 0,
    this.requiresSpecialLicence = false,
    this.numberOfWheels,
  });

  final String id;
  final String code;
  final String name;
  final String description;

  /// Path of the icon inside the `catalog-icons` bucket, or an absolute URL.
  final String? iconUrl;

  final double capacityKgMin;
  final double capacityKgMax;
  final int displayOrder;
  final bool requiresSpecialLicence;
  final int? numberOfWheels;

  String get capacityLabel {
    final kg = capacityKgMax.round();
    if (kg <= 0) return '';
    if (kg >= 1000) {
      final tonnes = kg ~/ 1000;
      return 'Up to $tonnes tonne${tonnes >= 2 ? 's' : ''}';
    }
    return 'Up to $kg kg';
  }
}

/// A cargo type — one row of `public.cargo_types`.
@immutable
class CargoTypeOption {
  const CargoTypeOption({
    required this.id,
    required this.code,
    required this.name,
    this.description = '',
    this.iconUrl,
    this.displayOrder = 0,
    this.categoryId,
    this.requiresSpecialHandling = false,
    this.requiresDeclaredValue = false,
    this.requiresInsurance = false,
    this.maxValueTzs,
    this.allowedVehicleTypeCodes = const <String>[],
    this.prohibitedVehicleTypeCodes = const <String>[],
  });

  final String id;
  final String code;
  final String name;
  final String description;

  /// Path of the icon inside the `catalog-icons` bucket, or an absolute URL.
  final String? iconUrl;

  final int displayOrder;
  final String? categoryId;
  final bool requiresSpecialHandling;
  final bool requiresDeclaredValue;
  final bool requiresInsurance;
  final double? maxValueTzs;

  /// Vehicle type codes this cargo may travel in.
  final List<String> allowedVehicleTypeCodes;

  /// Vehicle type codes this cargo may never travel in.
  final List<String> prohibitedVehicleTypeCodes;

  /// True when the cargo needs paperwork the customer must provide.
  bool get needsAttention =>
      requiresDeclaredValue || requiresInsurance || requiresSpecialHandling;
}
