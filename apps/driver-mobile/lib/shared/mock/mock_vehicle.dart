// Mock driver vehicle. No backend — demo data only.

class MockVehicle {
  const MockVehicle({
    required this.make,
    required this.model,
    required this.year,
    required this.plateNumber,
    required this.color,
    required this.vehicleClass,
    required this.capacityKg,
  });

  final String make;
  final String model;
  final int year;
  final String plateNumber;
  final String color;
  final String vehicleClass;
  final int capacityKg;
}

const MockVehicle mockVehicle = MockVehicle(
  make: 'Toyota',
  model: 'Hilux Pickup',
  year: 2019,
  plateNumber: 'T 452 DEF',
  color: 'White',
  vehicleClass: 'Pickup',
  capacityKg: 1000,
);
