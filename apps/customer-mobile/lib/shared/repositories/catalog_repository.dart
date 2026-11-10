import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/catalog_option.dart';

class CatalogRepository {
  CatalogRepository(this._client);

  final SupabaseClient _client;

  Future<List<VehicleTypeOption>> getVehicleTypes() async {
    final rows = await _client
        .from('vehicle_types')
        .select(
          'id, code, name, description, capacity_kg_min, capacity_kg_max, display_order, icon_url',
        )
        .eq('is_active', true)
        .order('display_order', ascending: true);

    return rows.map((row) => _vehicleFromRow(row)).toList(growable: false);
  }

  Future<List<CargoTypeOption>> getCargoTypes() async {
    final rows = await _client
        .from('cargo_types')
        .select('id, code, name, description, display_order, icon_url')
        .eq('is_active', true)
        .order('display_order', ascending: true);

    return rows.map((row) => _cargoFromRow(row)).toList(growable: false);
  }

  VehicleTypeOption _vehicleFromRow(Map<String, dynamic> row) {
    double numVal(Object? v) => (v as num?)?.toDouble() ?? 0;
    return VehicleTypeOption(
      id: row['id'] as String,
      code: row['code'] as String? ?? '',
      name: row['name'] as String? ?? 'Vehicle',
      description: row['description'] as String? ?? '',
      capacityKgMin: numVal(row['capacity_kg_min']),
      capacityKgMax: numVal(row['capacity_kg_max']),
      displayOrder: (row['display_order'] as num?)?.toInt() ?? 0,
      iconUrl: row['icon_url'] as String?,
    );
  }

  CargoTypeOption _cargoFromRow(Map<String, dynamic> row) {
    return CargoTypeOption(
      id: row['id'] as String,
      code: row['code'] as String? ?? '',
      name: row['name'] as String? ?? 'Cargo',
      description: row['description'] as String? ?? '',
      displayOrder: (row['display_order'] as num?)?.toInt() ?? 0,
      iconUrl: row['icon_url'] as String?,
    );
  }
}
