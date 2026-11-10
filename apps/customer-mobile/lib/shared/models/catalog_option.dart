import 'package:flutter/material.dart';

IconData _vehicleIcon(String code, String name) {
  final key = '${code.toLowerCase()} ${name.toLowerCase()}';
  if (key.contains('truck') && key.contains('large')) {
    return Icons.rv_hookup_rounded;
  }
  if (key.contains('truck') || key.contains('lorry')) {
    return Icons.fire_truck_rounded;
  }
  if (key.contains('pickup')) return Icons.local_shipping_rounded;
  if (key.contains('van')) return Icons.airport_shuttle_rounded;
  if (key.contains('bike') || key.contains('boda')) {
    return Icons.two_wheeler_rounded;
  }
  return Icons.local_shipping_outlined;
}

IconData _cargoIcon(String code, String name) {
  final key = '${code.toLowerCase()} ${name.toLowerCase()}';
  if (key.contains('household')) return Icons.chair_alt_rounded;
  if (key.contains('furniture')) return Icons.weekend_rounded;
  if (key.contains('appliance')) return Icons.kitchen_rounded;
  if (key.contains('building') || key.contains('material')) {
    return Icons.construction_rounded;
  }
  if (key.contains('commercial') ||
      key.contains('good') ||
      key.contains('electronic')) {
    return Icons.inventory_2_rounded;
  }
  if (key.contains('food')) return Icons.restaurant_rounded;
  return Icons.category_rounded;
}

@immutable
class VehicleTypeOption {
  const VehicleTypeOption({
    required this.id,
    required this.code,
    required this.name,
    required this.description,
    required this.capacityKgMin,
    required this.capacityKgMax,
    required this.displayOrder,
    this.iconUrl,
  });

  final String id;
  final String code;
  final String name;
  final String description;
  final double capacityKgMin;
  final double capacityKgMax;
  final int displayOrder;
  final String? iconUrl;

  IconData get icon => _vehicleIcon(code, name);

  String get capacityLabel {
    final kg = capacityKgMax.round();
    if (kg >= 1000) {
      final tonnes = kg ~/ 1000;
      return 'Up to $tonnes tonne${tonnes >= 2 ? 's' : ''}';
    }
    return 'Up to $kg kg';
  }

  /// Used for display when no quote is available yet.
  String get indicativeLabel => capacityLabel;
}

@immutable
class CargoTypeOption {
  const CargoTypeOption({
    required this.id,
    required this.code,
    required this.name,
    required this.description,
    required this.displayOrder,
    this.iconUrl,
  });

  final String id;
  final String code;
  final String name;
  final String description;
  final int displayOrder;
  final String? iconUrl;

  IconData get icon => _cargoIcon(code, name);
}
