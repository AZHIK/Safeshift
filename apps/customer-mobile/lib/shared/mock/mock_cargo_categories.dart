import 'package:flutter/material.dart';

class MockCargoCategory {
  const MockCargoCategory({
    required this.id,
    required this.name,
    required this.icon,
  });

  final String id;
  final String name;
  final IconData icon;
}

const List<MockCargoCategory> mockCargoCategories = <MockCargoCategory>[
  MockCargoCategory(
    id: 'household',
    name: 'Household',
    icon: Icons.chair_alt_rounded,
  ),
  MockCargoCategory(
    id: 'furniture',
    name: 'Furniture',
    icon: Icons.weekend_rounded,
  ),
  MockCargoCategory(
    id: 'appliances',
    name: 'Appliances',
    icon: Icons.kitchen_rounded,
  ),
  MockCargoCategory(
    id: 'building_materials',
    name: 'Building Materials',
    icon: Icons.construction_rounded,
  ),
  MockCargoCategory(
    id: 'commercial_goods',
    name: 'Commercial Goods',
    icon: Icons.inventory_2_rounded,
  ),
  MockCargoCategory(id: 'other', name: 'Other', icon: Icons.category_rounded),
];
