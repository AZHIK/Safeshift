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

  /// Active vehicle categories that can actually be priced right now.
  ///
  /// The booking flow must not offer a vehicle that has no active plan with a
  /// published version in effect: quoting it raises PostgreSQL `P0002`, which
  /// the customer cannot resolve. Vehicles without pricing are omitted.
  ///
  /// Pricing tables are readable by every authenticated user. If the lookup is
  /// denied, or returns no plans at all (an unconfigured market), the plain
  /// catalogue is returned so a configuration gap cannot empty the screen.
  Future<List<VehicleTypeOption>> getQuotableVehicleTypes({
    String? countryId,
  }) async {
    final vehicles = await getVehicleTypes(countryId: countryId);
    if (vehicles.isEmpty) return vehicles;
    try {
      final quotableIds = await _quotableVehicleIds();
      if (quotableIds.isEmpty) return vehicles;
      final filtered = vehicles
          .where((vehicle) => quotableIds.contains(vehicle.id))
          .toList(growable: false);
      return filtered.isEmpty ? vehicles : filtered;
    } catch (_) {
      return vehicles;
    }
  }

  /// Vehicle ids covered by an active plan whose published version is in
  /// effect now. Mirrors `active_pricing_plan_for` and
  /// `active_pricing_plan_version` on the server.
  Future<Set<String>> _quotableVehicleIds() async {
    final plans = await _client
        .from('pricing_plans')
        .select('id, vehicle_type_id')
        .eq('is_active', true);
    if (plans.isEmpty) return const <String>{};

    final versions = await _client
        .from('pricing_plan_versions')
        .select(
          'id, pricing_plan_id, version_number, published_at, '
          'effective_from, effective_to',
        )
        .inFilter(
          'pricing_plan_id',
          plans.map((plan) => plan['id'] as String).toList(growable: false),
        );

    final now = DateTime.now().toUtc();
    DateTime? parseTime(Object? value) =>
        value is String ? DateTime.tryParse(value)?.toUtc() : null;

    // active_pricing_plan_version() picks the newest published version whose
    // effective window contains the current time.
    final latestLiveVersion = <String, String>{};
    final latestLiveNumber = <String, int>{};
    for (final version in versions) {
      final planId = version['pricing_plan_id'] as String?;
      final versionId = version['id'] as String?;
      if (planId == null || versionId == null) continue;
      if (version['published_at'] == null) continue;
      final from = parseTime(version['effective_from']);
      final to = parseTime(version['effective_to']);
      if (from == null || from.isAfter(now)) continue;
      if (to != null && !to.isAfter(now)) continue;
      final number = (version['version_number'] as num?)?.toInt() ?? 0;
      if ((latestLiveNumber[planId] ?? -1) >= number) continue;
      latestLiveNumber[planId] = number;
      latestLiveVersion[planId] = versionId;
    }
    if (latestLiveVersion.isEmpty) return const <String>{};

    final ids = <String>{};
    for (final plan in plans) {
      final planId = plan['id'] as String?;
      if (planId == null || !latestLiveVersion.containsKey(planId)) continue;
      final vehicleTypeId = plan['vehicle_type_id'] as String?;
      if (vehicleTypeId != null) ids.add(vehicleTypeId);
    }

    // A version can also cover extra vehicle types.
    final mappings = await _client
        .from('pricing_plan_vehicle_types')
        .select('vehicle_type_id')
        .inFilter(
          'pricing_plan_version_id',
          latestLiveVersion.values.toList(growable: false),
        );
    for (final mapping in mappings) {
      final vehicleTypeId = mapping['vehicle_type_id'] as String?;
      if (vehicleTypeId != null) ids.add(vehicleTypeId);
    }
    return ids;
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
      prohibitedVehicleTypeCodes: _codesOf(
        row['prohibited_vehicle_type_codes'],
      ),
    );
  }

  List<String> _codesOf(Object? value) {
    if (value is! List) return const <String>[];
    return value.whereType<String>().toList(growable: false);
  }
}
