import 'package:supabase/supabase.dart';

import 'catalog_option.dart';

/// Reads the vehicle and cargo catalogues from the database.
///
/// Both catalogues are country-aware: a row with `country_id = NULL` is
/// global, a row with a country id only applies to that market. The apps
/// never hard-code vehicle classes or cargo types — they ask this repository.
///
/// When the signed-in profile has no `default_country_id`, every active row
/// is returned. The catalogues are small (single digits), so showing the full
/// catalogue is better than showing nothing.
class CatalogRepository {
  CatalogRepository(this._client);

  final SupabaseClient _client;

  static const String _vehicleTypeColumns =
      'id, code, name, description, icon_url, capacity_kg_min, '
      'capacity_kg_max, display_order, requires_special_licence, '
      'number_of_wheels';

  static const String _cargoTypeColumns =
      'id, code, name, description, icon_url, display_order, category_id, '
      'requires_special_handling, requires_declared_value, '
      'requires_insurance, max_value_tzs, allowed_vehicle_type_codes, '
      'prohibited_vehicle_type_codes';

  /// The country the signed-in profile operates in, if any.
  Future<String?> currentCountryId() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return null;
    final row = await _client
        .from('profiles')
        .select('default_country_id')
        .eq('id', userId)
        .maybeSingle();
    return row?['default_country_id'] as String?;
  }

  /// Active vehicle categories visible in [countryId].
  ///
  /// Pass null to use the signed-in profile's country, or the empty string to
  /// return every active row.
  Future<List<VehicleTypeOption>> getVehicleTypes({String? countryId}) async {
    final scope = countryId ?? await currentCountryId();
    var query = _client
        .from('vehicle_types')
        .select(_vehicleTypeColumns)
        .eq('is_active', true);
    if (scope != null && scope.isNotEmpty) {
      query = query.or('country_id.is.null,country_id.eq.$scope');
    }
    final rows = await query.order('display_order', ascending: true);
    return rows.map(_vehicleFromRow).toList(growable: false);
  }

  /// Active cargo types visible in [countryId].
  ///
  /// Pass null to use the signed-in profile's country, or the empty string to
  /// return every active row.
  Future<List<CargoTypeOption>> getCargoTypes({String? countryId}) async {
    final scope = countryId ?? await currentCountryId();
    var query = _client
        .from('cargo_types')
        .select(_cargoTypeColumns)
        .eq('is_active', true);
    if (scope != null && scope.isNotEmpty) {
      query = query.or('country_id.is.null,country_id.eq.$scope');
    }
    final rows = await query.order('display_order', ascending: true);
    return rows.map(_cargoFromRow).toList(growable: false);
  }

  /// Looks a vehicle category up by its durable code.
  Future<VehicleTypeOption?> vehicleTypeByCode(String code) async {
    final rows = await _client
        .from('vehicle_types')
        .select(_vehicleTypeColumns)
        .eq('code', code)
        .eq('is_active', true)
        .limit(1);
    if (rows.isEmpty) return null;
    return _vehicleFromRow(rows.first);
  }

  /// Looks a cargo type up by its durable code.
  Future<CargoTypeOption?> cargoTypeByCode(String code) async {
    final rows = await _client
        .from('cargo_types')
        .select(_cargoTypeColumns)
        .eq('code', code)
        .eq('is_active', true)
        .limit(1);
    if (rows.isEmpty) return null;
    return _cargoFromRow(rows.first);
  }

  VehicleTypeOption _vehicleFromRow(Map<String, dynamic> row) {
    double numOf(Object? value) => (value as num?)?.toDouble() ?? 0;
    return VehicleTypeOption(
      id: row['id'] as String,
      code: row['code'] as String? ?? '',
      name: row['name'] as String? ?? 'Vehicle',
      description: row['description'] as String? ?? '',
      iconUrl: row['icon_url'] as String?,
      capacityKgMin: numOf(row['capacity_kg_min']),
      capacityKgMax: numOf(row['capacity_kg_max']),
      displayOrder: (row['display_order'] as num?)?.toInt() ?? 0,
      requiresSpecialLicence: row['requires_special_licence'] == true,
      numberOfWheels: (row['number_of_wheels'] as num?)?.toInt(),
    );
  }

  CargoTypeOption _cargoFromRow(Map<String, dynamic> row) {
    return CargoTypeOption(
      id: row['id'] as String,
      code: row['code'] as String? ?? '',
      name: row['name'] as String? ?? 'Cargo',
      description: row['description'] as String? ?? '',
      iconUrl: row['icon_url'] as String?,
      displayOrder: (row['display_order'] as num?)?.toInt() ?? 0,
      categoryId: row['category_id'] as String?,
      requiresSpecialHandling: row['requires_special_handling'] == true,
      requiresDeclaredValue: row['requires_declared_value'] == true,
      requiresInsurance: row['requires_insurance'] == true,
      maxValueTzs: (row['max_value_tzs'] as num?)?.toDouble(),
      allowedVehicleTypeCodes: _codesOf(row['allowed_vehicle_type_codes']),
      prohibitedVehicleTypeCodes: _codesOf(row['prohibited_vehicle_type_codes']),
    );
  }

  List<String> _codesOf(Object? value) {
    if (value is! List) return const <String>[];
    return value.whereType<String>().toList(growable: false);
  }
}
