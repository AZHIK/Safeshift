import 'package:flutter/material.dart';

class MockVehicleClass {
  const MockVehicleClass({
    required this.id,
    required this.name,
    required this.description,
    required this.capacityKg,
    required this.basePriceTzs,
    required this.icon,
  });

  final String id;
  final String name;
  final String description;
  final int capacityKg;
  final int basePriceTzs;
  final IconData icon;

  String get capacityLabel => capacityKg >= 1000
      ? 'Up to ${capacityKg ~/ 1000} tonne${capacityKg >= 2000 ? 's' : ''}'
      : 'Up to $capacityKg kg';
}

const List<MockVehicleClass> mockVehicleClasses = <MockVehicleClass>[
  MockVehicleClass(
    id: 'small_van',
    name: 'Small Van',
    description: 'Boxes and a few household items',
    capacityKg: 500,
    basePriceTzs: 25000,
    icon: Icons.airport_shuttle_rounded,
  ),
  MockVehicleClass(
    id: 'pickup',
    name: 'Pickup',
    description: 'Furniture and medium-sized loads',
    capacityKg: 1000,
    basePriceTzs: 40000,
    icon: Icons.local_shipping_rounded,
  ),
  MockVehicleClass(
    id: 'medium_truck',
    name: 'Medium Truck',
    description: 'A full home or larger deliveries',
    capacityKg: 3000,
    basePriceTzs: 75000,
    icon: Icons.fire_truck_rounded,
  ),
  MockVehicleClass(
    id: 'large_truck',
    name: 'Large Truck',
    description: 'Heavy commercial and building loads',
    capacityKg: 7000,
    basePriceTzs: 120000,
    icon: Icons.rv_hookup_rounded,
  ),
];
