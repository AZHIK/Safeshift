import 'dart:math' as math;
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/mock/mock_cargo_categories.dart';
import '../../../shared/mock/mock_locations.dart';
import '../../../shared/mock/mock_vehicle_classes.dart';

class QuoteSnapshot {
  const QuoteSnapshot({
    required this.quoteId,
    required this.total,
    required this.subtotal,
    required this.vat,
    required this.baseFee,
    required this.distanceFee,
    required this.timeFee,
    required this.distanceKm,
    required this.durationMin,
    required this.currencyCode,
    required this.expiresAt,
  });

  final String quoteId;
  final double total;
  final double subtotal;
  final double vat;
  final double baseFee;
  final double distanceFee;
  final double timeFee;
  final double distanceKm;
  final int durationMin;
  final String currencyCode;
  final DateTime? expiresAt;
}

class CustomerJobSnapshot {
  const CustomerJobSnapshot({
    required this.id,
    required this.status,
    required this.pickupAddress,
    required this.destinationAddress,
    required this.amount,
    required this.distanceKm,
    required this.createdAt,
    required this.completedAt,
    this.driverId,
    this.driverName,
    this.driverPhone,
    this.driverRating = 0,
    this.driverVerified = false,
    this.driverLat,
    this.driverLng,
    this.vehicleType,
    this.cargoType,
    this.paymentMethod,
  });

  final String id;
  final String status;
  final String pickupAddress;
  final String destinationAddress;
  final double amount;
  final double distanceKm;
  final DateTime? createdAt;
  final DateTime? completedAt;
  final String? driverId;
  final String? driverName;
  final String? driverPhone;
  final double driverRating;
  final bool driverVerified;
  final double? driverLat;
  final double? driverLng;
  final String? vehicleType;
  final String? cargoType;
  final String? paymentMethod;

  bool get isTerminal => status == 'completed' || status == 'cancelled';
  bool get isDelivered => status == 'delivered' || status == 'completed';
}

class DispatchResult {
  const DispatchResult({required this.count, required this.reason});
  final int count;
  final String? reason;
}

class RideRepository {
  RideRepository(this._client);

  final SupabaseClient _client;

  static const Map<String, String> _cargoCodeByMockId = <String, String>{
    'household': 'household_goods',
    'furniture': 'furniture',
    'appliances': 'appliances',
    'building_materials': 'building_materials',
    'commercial_goods': 'electronics',
  };

  Future<QuoteSnapshot> requestQuote({
    required String customerId,
    required MockLocation pickup,
    required MockLocation destination,
    required MockVehicleClass vehicle,
    MockCargoCategory? cargo,
    double? weightKg,
    int? valueTzs,
  }) async {
    final vehicleType = await _client
        .from('vehicle_types')
        .select('id')
        .eq('code', vehicle.id)
        .maybeSingle();
    if (vehicleType == null) {
      throw StateError('Vehicle type ${vehicle.id} is not configured.');
    }

    String? cargoTypeId;
    final cargoCode = _cargoCodeByMockId[cargo?.id];
    if (cargoCode != null) {
      final cargoType = await _client
          .from('cargo_types')
          .select('id')
          .eq('code', cargoCode)
          .maybeSingle();
      cargoTypeId = cargoType?['id'] as String?;
    }

    final route = _routeMetrics(pickup, destination);

    final quoteId = await _client.rpc<String>(
      'quote_calculate_and_persist',
      params: <String, dynamic>{
        'p_customer_id': customerId,
        'p_pickup_location': _point(pickup),
        'p_pickup_address': pickup.name,
        'p_destination_location': _point(destination),
        'p_destination_address': destination.name,
        'p_vehicle_type_id': vehicleType['id'],
        'p_cargo_type_id': cargoTypeId,
        'p_cargo_weight_kg': weightKg,
        'p_distance_km': route.distanceKm,
        'p_duration_min': route.durationMin,
      },
    );

    final snapshot = await _client.rpc<Map<String, dynamic>>(
      'quote_get_breakdown',
      params: <String, dynamic>{'p_quote_id': quoteId},
    );
    final finalPart =
        (snapshot['final'] as Map?)?.cast<String, dynamic>() ??
        <String, dynamic>{};
    final calculation =
        (snapshot['calculation'] as Map?)?.cast<String, dynamic>() ??
        <String, dynamic>{};

    double money(Object? value) => (value as num?)?.toDouble() ?? 0;

    return QuoteSnapshot(
      quoteId: quoteId,
      total: money(finalPart['total']),
      subtotal: money(finalPart['subtotal']),
      vat: money(finalPart['vat']),
      baseFee: money(calculation['base_fare']),
      distanceFee: money(calculation['distance_charge']),
      timeFee: money(calculation['time_charge']),
      distanceKm: money(calculation['distance_km'] ?? route.distanceKm),
      durationMin:
          (calculation['duration_min'] as num?)?.toInt() ?? route.durationMin,
      currencyCode: (finalPart['currency_code'] as String?) ?? 'TZS',
      expiresAt: DateTime.tryParse('${finalPart['expires_at'] ?? ''}'),
    );
  }

  Future<CustomerJobSnapshot> createJob(String quoteId) async {
    final row = await _client
        .from('jobs')
        .insert(<String, dynamic>{'quote_id': quoteId})
        .select('id')
        .single();
    final id = row['id'] as String;
    final snapshot = await getJob(id);
    if (snapshot == null) {
      throw StateError('Job was created but could not be loaded.');
    }
    return snapshot;
  }

  Future<DispatchResult> dispatch(String jobId) async {
    final response = await _client.rpc<Map<String, dynamic>>(
      'match_dispatch',
      params: <String, dynamic>{
        'p_job_id': jobId,
        'p_radius_km': 15,
        'p_limit': 5,
        'p_timeout_seconds': 45,
      },
    );
    return DispatchResult(
      count: (response['count'] as num?)?.toInt() ?? 0,
      reason: response['reason'] as String?,
    );
  }

  Future<CustomerJobSnapshot?> getJob(String jobId) async {
    final rows = await _client.rpc<List<dynamic>>(
      'customer_job',
      params: <String, dynamic>{'p_job_id': jobId},
    );
    if (rows.isEmpty) return null;
    return _jobFromRow((rows.first as Map).cast<String, dynamic>());
  }

  Future<List<CustomerJobSnapshot>> getJobs() async {
    final rows = await _client.rpc<List<dynamic>>(
      'customer_jobs',
      params: <String, dynamic>{'p_limit': 100},
    );
    return rows
        .map((row) => _jobFromRow((row as Map).cast<String, dynamic>()))
        .toList(growable: false);
  }

  Future<String> issueDeliveryOtp(String jobId) {
    return _client.rpc<String>(
      'job_issue_delivery_otp',
      params: <String, dynamic>{'p_job_id': jobId},
    );
  }

  Future<void> cancelJob(String jobId, String customerId) {
    return _client.rpc<void>(
      'job_cancel',
      params: <String, dynamic>{
        'p_job_id': jobId,
        'p_cancelled_by': customerId,
        'p_reason': 'Customer cancelled while searching',
      },
    );
  }

  /// Uploads proof (pickup/delivery photo, signature, document) for a job.
  Future<void> uploadJobEvidence({
    required String jobId,
    required String evidenceType,
    required List<int> bytes,
    required String fileName,
    String? mimeType,
    String? stopId,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw StateError('Authentication required.');
    final path = _storagePath(jobId, fileName);
    await _client.storage
        .from('job-evidence')
        .uploadBinary(
          path,
          Uint8List.fromList(bytes),
          fileOptions: FileOptions(contentType: mimeType, upsert: false),
        );
    await _client.from('job_evidence').insert(<String, dynamic>{
      'job_id': jobId,
      'stop_id': stopId,
      'evidence_type': evidenceType,
      'storage_path': path,
      'file_mime_type': mimeType,
      'file_size_bytes': bytes.length,
      'created_by': userId,
    });
  }

  /// Ensures the job chat thread exists and returns its id.
  Future<String> ensureChatThread(String jobId) {
    return _client.rpc<String>(
      'ensure_job_chat_thread',
      params: <String, dynamic>{'p_job_id': jobId},
    );
  }

  /// Sends an image/file message in the job chat.
  Future<void> sendChatAttachment({
    required String jobId,
    required List<int> bytes,
    required String fileName,
    String? mimeType,
    String? caption,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw StateError('Authentication required.');
    final threadId = await ensureChatThread(jobId);
    final path = _storagePath(jobId, fileName);
    await _client.storage
        .from('chat-attachments')
        .uploadBinary(
          path,
          Uint8List.fromList(bytes),
          fileOptions: FileOptions(contentType: mimeType, upsert: false),
        );
    final message = await _client
        .from('chat_messages')
        .insert(<String, dynamic>{
          'thread_id': threadId,
          'sender_profile_id': userId,
          'message_type': 'image',
          'body': caption?.trim().isEmpty == true ? null : caption?.trim(),
        })
        .select('id')
        .single();
    await _client.from('chat_attachments').insert(<String, dynamic>{
      'message_id': message['id'],
      'thread_id': threadId,
      'storage_path': path,
      'file_mime_type': mimeType,
      'file_size_bytes': bytes.length,
    });
  }

  static String _storagePath(String jobId, String fileName) {
    final safe = fileName.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    return '$jobId/${DateTime.now().microsecondsSinceEpoch}_$safe';
  }

  CustomerJobSnapshot _jobFromRow(Map<String, dynamic> row) {
    double money(Object? value) => (value as num?)?.toDouble() ?? 0;
    return CustomerJobSnapshot(
      id: row['job_id'] as String,
      status: row['status'] as String? ?? 'requested',
      pickupAddress: row['pickup_address'] as String? ?? '',
      destinationAddress: row['destination_address'] as String? ?? '',
      amount: money(row['final_amount']),
      distanceKm: money(row['distance_km']),
      createdAt: DateTime.tryParse('${row['created_at'] ?? ''}'),
      completedAt: DateTime.tryParse('${row['completed_at'] ?? ''}'),
      driverId: row['driver_id'] as String?,
      driverName: row['driver_name'] as String?,
      driverPhone: row['driver_phone'] as String?,
      driverRating: money(row['driver_rating']),
      driverVerified: row['driver_verified'] as bool? ?? false,
      driverLat: money(row['driver_lat']) == 0
          ? null
          : money(row['driver_lat']),
      driverLng: money(row['driver_lng']) == 0
          ? null
          : money(row['driver_lng']),
      vehicleType: row['vehicle_type'] as String?,
      cargoType: row['cargo_type'] as String?,
      paymentMethod: row['payment_method'] as String?,
    );
  }

  static String _point(MockLocation location) =>
      'SRID=4326;POINT(${location.longitude} ${location.latitude})';

  static _RouteMetrics _routeMetrics(
    MockLocation pickup,
    MockLocation destination,
  ) {
    const earthRadiusKm = 6371.0;
    final dLat = _radians(destination.latitude - pickup.latitude);
    final dLng = _radians(destination.longitude - pickup.longitude);
    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_radians(pickup.latitude)) *
            math.cos(_radians(destination.latitude)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    final straightKm =
        earthRadiusKm * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    // Road distance is typically ~30% longer than the straight line in Dar.
    final distanceKm = math.max(1.0, straightKm * 1.3);
    final durationMin = math.max(8, (distanceKm / 24 * 60).ceil());
    return _RouteMetrics(distanceKm, durationMin);
  }

  static double _radians(double degrees) => degrees * math.pi / 180;
}

class _RouteMetrics {
  const _RouteMetrics(this.distanceKm, this.durationMin);
  final double distanceKm;
  final int durationMin;
}
