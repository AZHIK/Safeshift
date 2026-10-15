import 'package:flutter/material.dart';

class MockPaymentMethod {
  const MockPaymentMethod({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
  });

  final String id;
  final String name;
  final IconData icon;
  final Color color;
}

const List<MockPaymentMethod> mockPaymentMethods = <MockPaymentMethod>[
  MockPaymentMethod(
    id: 'mpesa',
    name: 'M-Pesa',
    icon: Icons.phone_android_rounded,
    color: Color(0xFFE53935),
  ),
  MockPaymentMethod(
    id: 'tigopesa',
    name: 'Tigo Pesa',
    icon: Icons.phone_android_rounded,
    color: Color(0xFF1565C0),
  ),
  MockPaymentMethod(
    id: 'airtelmoney',
    name: 'Airtel Money',
    icon: Icons.phone_android_rounded,
    color: Color(0xFFC62828),
  ),
  MockPaymentMethod(
    id: 'cash',
    name: 'Cash',
    icon: Icons.payments_outlined,
    color: Color(0xFF2E7D32),
  ),
];
