import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/entities/driver_job.dart';

class DriverEarningsSnapshot {
  const DriverEarningsSnapshot({
    required this.todayAmount,
    required this.todayTrips,
    required this.weekAmount,
    required this.weekTrips,
    required this.monthAmount,
    required this.monthTrips,
    required this.last7Days,
  });

  final int todayAmount;
  final int todayTrips;
  final int weekAmount;
  final int weekTrips;
  final int monthAmount;
  final int monthTrips;
  final List<DailyEarning> last7Days;

  static const empty = DriverEarningsSnapshot(
    todayAmount: 0,
    todayTrips: 0,
    weekAmount: 0,
    weekTrips: 0,
    monthAmount: 0,
    monthTrips: 0,
    last7Days: <DailyEarning>[],
  );
}

class DailyEarning {
  const DailyEarning({
    required this.day,
    required this.date,
    required this.amount,
  });
  final String day;
  final DateTime? date;
  final int amount;
}

class DriverDocumentSnapshot {
  const DriverDocumentSnapshot({
    required this.id,
    required this.documentTypeId,
    required this.title,
    required this.status,
    this.expiresAt,
    this.filePath,
    this.rejectionReason,
  });

  final String id;
  final String documentTypeId;
  final String title;
  final String status;
  final DateTime? expiresAt;
  final String? filePath;
  final String? rejectionReason;
}

class DriverVehicleSnapshot {
  const DriverVehicleSnapshot({
    required this.id,
    required this.registrationNumber,
    required this.vehicleType,
    required this.verificationStatus,
    this.vehicleTypeId,
    this.vehicleTypeCode,
    this.vehicleTypeIconUrl,
    this.make,
    this.model,
    this.year,
    this.color,
    this.capacityKg,
    this.photoUrls = const <String>[],
  });

  final String id;
  final String registrationNumber;

  /// Display name of the vehicle category (`public.vehicle_types.name`).
  final String vehicleType;

  final String verificationStatus;

  /// `public.vehicle_types.id` of the vehicle category.
  final String? vehicleTypeId;

  /// Durable code of the vehicle category, e.g. `pickup`.
  final String? vehicleTypeCode;

  /// Icon path of the vehicle category, served from the catalogue bucket.
  final String? vehicleTypeIconUrl;

  final String? make;
  final String? model;
  final int? year;
  final String? color;
  final int? capacityKg;
  final List<String> photoUrls;
}

class DriverRatingSnapshot {
  const DriverRatingSnapshot({
    required this.id,
    required this.score,
    required this.raterName,
    this.comment,
    this.createdAt,
    this.jobId,
  });

  final String id;
  final int score;
  final String raterName;
  final String? comment;
  final DateTime? createdAt;
  final String? jobId;
}

class DriverRepository {
  DriverRepository(this._client);

  final SupabaseClient _client;

  Future<void> setAvailability(bool available) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;
    await _client
        .from('drivers')
        .update(<String, dynamic>{'is_available': available})
        .eq('id', userId);
  }

  /// The vehicle this driver currently operates, if any.
  ///
  /// Dispatch joins on `drivers.current_vehicle_id`, so it must be set before
  /// the driver can be matched to a job.
  Future<String?> currentVehicleId() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return null;
    final rows = await _client
        .from('drivers')
        .select('current_vehicle_id')
        .eq('id', userId)
        .maybeSingle();
    return rows?['current_vehicle_id'] as String?;
  }

  /// The driver's own active, verified vehicles.
  ///
  /// Covers both ownership paths: a vehicle whose `primary_driver_id` is the
  /// driver, and a fleet vehicle linked through an active
  /// `vehicle_assignments` row.
  Future<List<String>> myReadyVehicleIds() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return const <String>[];

    final candidateIds = <String>{};
    final owned = await _client
        .from('vehicles')
        .select('id')
        .eq('primary_driver_id', userId)
        .eq('is_active', true)
        .eq('verification_status', 'verified');
    candidateIds.addAll(owned.map((row) => row['id']).whereType<String>());

    final assignments = await _client
        .from('vehicle_assignments')
        .select('vehicle_id')
        .eq('driver_id', userId)
        .eq('is_active', true)
        .isFilter('unassigned_at', null);
    candidateIds.addAll(
      assignments.map((row) => row['vehicle_id']).whereType<String>(),
    );

    if (candidateIds.isEmpty) return const <String>[];

    // Re-check the assignment path: an assignment can outlive the vehicle's
    // active/verified state.
    final ready = await _client
        .from('vehicles')
        .select('id')
        .inFilter('id', candidateIds.toList(growable: false))
        .eq('is_active', true)
        .eq('verification_status', 'verified');
    return ready
        .map((row) => row['id'] as String?)
        .whereType<String>()
        .toList(growable: false);
  }

  /// Points the driver at a vehicle. The server validates ownership.
  Future<void> setCurrentVehicle(String? vehicleId) async {
    await _client.rpc<void>(
      'driver_set_current_vehicle',
      params: <String, dynamic>{'p_vehicle_id': vehicleId},
    );
  }

  /// Ensures the driver has a current vehicle, picking one if needed.
  ///
  /// Returns false when the driver has no active, verified vehicle at all,
  /// in which case dispatch can never match them.
  Future<bool> ensureCurrentVehicle() async {
    final current = await currentVehicleId();
    if (current != null) return true;
    final ready = await myReadyVehicleIds();
    final picked = selectCurrentVehicle(
      currentVehicleId: current,
      readyVehicleIds: ready,
    );
    if (picked == null) return false;
    await setCurrentVehicle(picked);
    return true;
  }

  /// Chooses which vehicle a driver should operate.
  ///
  /// An already-assigned vehicle always wins. Otherwise the first active,
  /// verified vehicle is used, and `null` means the driver cannot be matched
  /// to any job.
  @visibleForTesting
  static String? selectCurrentVehicle({
    required String? currentVehicleId,
    required List<String> readyVehicleIds,
  }) {
    if (currentVehicleId != null) return currentVehicleId;
    if (readyVehicleIds.isEmpty) return null;
    return readyVehicleIds.first;
  }

  /// Stores a position: one row in `driver_locations`.
  ///
  /// The `trg_driver_locations_sync_current` trigger copies it onto
  /// `drivers.current_location`, so dispatch and the customer's fallback
  /// poll see it without a second write. Called every ~30 s; the live
  /// trail goes over Realtime Broadcast instead.
  Future<void> updateLocation({
    required double latitude,
    required double longitude,
    String? jobId,
    double? heading,
    double? speedKmh,
    double? accuracyM,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;
    final row = <String, dynamic>{
      'driver_id': userId,
      'location': 'SRID=4326;POINT($longitude $latitude)',
      if (heading != null) 'heading_degrees': heading.round() % 360,
      if (speedKmh != null && speedKmh >= 0)
        'speed_kmh': double.parse(speedKmh.toStringAsFixed(2)),
      if (accuracyM != null && accuracyM >= 0)
        'accuracy_m': double.parse(accuracyM.toStringAsFixed(2)),
    };
    try {
      await _client.from('driver_locations').insert(<String, dynamic>{
        ...row,
        'job_id': jobId,
      });
    } on PostgrestException {
      if (jobId == null) rethrow;
      // The job ended or moved to another driver moments ago; RLS refuses
      // the job tag. Keep the driver dispatchable with an untagged fix.
      await _client.from('driver_locations').insert(row);
    }
  }

  Future<DriverJob?> nextOffer() async {
    final rows = await _client.rpc<List<dynamic>>('driver_pending_offers');
    if (rows.isEmpty) return null;
    return _offerFromRow((rows.first as Map).cast<String, dynamic>());
  }

  Future<DriverJob?> activeJob() async {
    final rows = await _client.rpc<List<dynamic>>('driver_active_job');
    if (rows.isEmpty) return null;
    return _offerFromRow((rows.first as Map).cast<String, dynamic>());
  }

  Future<void> acceptOffer(String offerId) {
    return _client.rpc<void>(
      'accept_job_offer',
      params: <String, dynamic>{'p_offer_id': offerId},
    );
  }

  /// Hands the active job back before the cargo is verified. The server
  /// re-dispatches it to another driver.
  Future<void> releaseJob(String jobId, String reason) {
    return _client.rpc<void>(
      'job_driver_release',
      params: <String, dynamic>{'p_job_id': jobId, 'p_reason': reason},
    );
  }

  Future<void> reportCustomerNoShow(String jobId) {
    return _client.rpc<void>(
      'job_report_customer_no_show',
      params: <String, dynamic>{'p_job_id': jobId},
    );
  }

  Future<void> reportCargoMismatch(String jobId, String reason) {
    return _client.rpc<void>(
      'job_report_cargo_mismatch',
      params: <String, dynamic>{'p_job_id': jobId, 'p_reason': reason},
    );
  }

  /// End of the free waiting window at pickup, or null when not waiting.
  Future<DateTime?> pickupFreeWaitEndsAt(String jobId) async {
    final row = await _client.rpc<Map<String, dynamic>>(
      'job_pickup_wait',
      params: <String, dynamic>{'p_job_id': jobId},
    );
    if (row['waiting'] != true) return null;
    return DateTime.tryParse('${row['free_wait_ends_at'] ?? ''}');
  }

  /// Why a job is no longer on this driver's screen: `cancelled`,
  /// `released`, `unassigned` or `assigned`, with a reason when known.
  Future<({String outcome, String? reason})> jobOutcome(String jobId) async {
    final row = await _client.rpc<Map<String, dynamic>>(
      'driver_job_outcome',
      params: <String, dynamic>{'p_job_id': jobId},
    );
    return (
      outcome: (row['outcome'] as String?) ?? 'unassigned',
      reason: row['reason'] as String?,
    );
  }

  Future<void> declineOffer(String offerId) {
    return _client.rpc<void>(
      'decline_job_offer',
      params: <String, dynamic>{
        'p_offer_id': offerId,
        'p_reason': 'Declined by driver',
      },
    );
  }

  Future<void> advanceJob(String jobId, String status) {
    return _client.rpc<void>(
      'job_advance_status',
      params: <String, dynamic>{
        'p_job_id': jobId,
        'p_new_status': status,
        'p_reason': 'Driver app status update',
      },
    );
  }

  Future<bool> verifyDeliveryOtp(String jobId, String code) {
    return _client.rpc<bool>(
      'job_verify_delivery_otp',
      params: <String, dynamic>{'p_job_id': jobId, 'p_code': code},
    );
  }

  Future<DriverEarningsSnapshot> earnings() async {
    final raw = await _client.rpc<Map<String, dynamic>>(
      'driver_earnings_summary',
    );
    int money(Object? value) => (value as num?)?.toInt() ?? 0;
    final days = <DailyEarning>[];
    final rawDays = raw['last_7_days'];
    if (rawDays is List) {
      for (final item in rawDays) {
        if (item is! Map) continue;
        days.add(
          DailyEarning(
            day: item['day'] as String? ?? '',
            date: DateTime.tryParse('${item['date'] ?? ''}'),
            amount: money(item['amount']),
          ),
        );
      }
    }
    return DriverEarningsSnapshot(
      todayAmount: money(raw['today_amount']),
      todayTrips: money(raw['today_trips']),
      weekAmount: money(raw['week_amount']),
      weekTrips: money(raw['week_trips']),
      monthAmount: money(raw['month_amount']),
      monthTrips: money(raw['month_trips']),
      last7Days: days,
    );
  }

  Future<List<DriverJob>> trips({int limit = 100}) async {
    final rows = await _client.rpc<List<dynamic>>(
      'driver_trips',
      params: <String, dynamic>{'p_limit': limit},
    );
    return rows
        .map((row) => _tripFromRow((row as Map).cast<String, dynamic>()))
        .toList(growable: false);
  }

  /// One finished trip owned by the signed-in driver.
  ///
  /// Unlike [trips], this is keyed by id, so it still resolves trips older than
  /// the history page. Foreign, active, and unknown jobs return null.
  Future<DriverJob?> trip(String jobId) async {
    final rows = await _client.rpc<List<dynamic>>(
      'driver_trip_detail',
      params: <String, dynamic>{'p_job_id': jobId},
    );
    if (rows.isEmpty) return null;
    return _tripFromRow((rows.first as Map).cast<String, dynamic>());
  }

  Future<List<DriverDocumentSnapshot>> documents() async {
    final rows = await _client.rpc<List<dynamic>>('driver_documents_list');
    return rows
        .map((row) {
          final map = (row as Map).cast<String, dynamic>();
          return DriverDocumentSnapshot(
            id: map['document_id'] as String,
            documentTypeId: map['document_type_id'] as String,
            title: map['title'] as String? ?? 'Document',
            status: map['status'] as String? ?? 'pending',
            expiresAt: DateTime.tryParse('${map['expires_at'] ?? ''}'),
            filePath: map['file_path'] as String?,
            rejectionReason: map['rejection_reason'] as String?,
          );
        })
        .toList(growable: false);
  }

  Future<void> uploadDocument({
    required String documentTypeId,
    required List<int> bytes,
    required String fileName,
    String? mimeType,
    DateTime? expiresAt,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw StateError('Authentication required.');
    final dot = fileName.lastIndexOf('.');
    final ext = dot >= 0 ? fileName.substring(dot + 1) : 'bin';
    final path =
        '$userId/${documentTypeId}_${DateTime.now().millisecondsSinceEpoch}.$ext';
    await _client.storage
        .from('driver-documents')
        .uploadBinary(
          path,
          Uint8List.fromList(bytes),
          fileOptions: FileOptions(contentType: mimeType, upsert: false),
        );
    await _client.from('driver_documents').insert(<String, dynamic>{
      'driver_id': userId,
      'document_type_id': documentTypeId,
      'file_path': path,
      'file_mime_type': mimeType,
      'file_size_bytes': bytes.length,
      'expires_at': expiresAt?.toIso8601String().split('T').first,
    });
  }

  /// Uploads proof (pickup/delivery photo, signature, document) for the
  /// driver's active job.
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

  Future<String> ensureChatThread(String jobId) {
    return _client.rpc<String>(
      'ensure_job_chat_thread',
      params: <String, dynamic>{'p_job_id': jobId},
    );
  }

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

  Future<DriverVehicleSnapshot?> vehicle() async {
    final raw = await _client.rpc<Map<String, dynamic>>('driver_vehicle_info');
    if (raw.isEmpty) return null;
    final photos = raw['photo_urls'];
    return DriverVehicleSnapshot(
      id: raw['id'] as String,
      registrationNumber: raw['registration_number'] as String? ?? '',
      vehicleType: raw['vehicle_type'] as String? ?? 'Vehicle',
      vehicleTypeId: raw['vehicle_type_id'] as String?,
      vehicleTypeCode: raw['vehicle_type_code'] as String?,
      vehicleTypeIconUrl: raw['vehicle_type_icon_url'] as String?,
      verificationStatus: raw['verification_status'] as String? ?? 'pending',
      make: raw['make'] as String?,
      model: raw['model'] as String?,
      year: (raw['year'] as num?)?.toInt(),
      color: raw['color'] as String?,
      capacityKg: (raw['capacity_kg'] as num?)?.toInt(),
      photoUrls: photos is List
          ? photos.whereType<String>().toList()
          : const [],
    );
  }

  Future<List<DriverRatingSnapshot>> ratings({int limit = 50}) async {
    final rows = await _client.rpc<List<dynamic>>(
      'driver_ratings_list',
      params: <String, dynamic>{'p_limit': limit},
    );
    return rows
        .map((row) {
          final map = (row as Map).cast<String, dynamic>();
          return DriverRatingSnapshot(
            id: map['rating_id'] as String,
            score: (map['score'] as num?)?.toInt() ?? 0,
            raterName: map['rater_name'] as String? ?? 'Customer',
            comment: map['comment'] as String?,
            createdAt: DateTime.tryParse('${map['created_at'] ?? ''}'),
            jobId: map['job_id'] as String?,
          );
        })
        .toList(growable: false);
  }

  DriverJob _offerFromRow(Map<String, dynamic> row) {
    double numOf(Object? value) => (value as num?)?.toDouble() ?? 0;
    double? optionalNum(Object? value) =>
        value == null ? null : (value as num?)?.toDouble();
    final photos = row['cargo_photo_paths'];
    return DriverJob(
      id: row['job_id'] as String,
      pickup: row['pickup_address'] as String? ?? '',
      destination: row['destination_address'] as String? ?? '',
      distanceKm: numOf(row['distance_km']),
      estimatedFareTzs: numOf(row['estimated_fare']).round(),
      cargoClass: row['cargo_type'] as String? ?? 'Cargo',
      cargoTypeId: row['cargo_type_id'] as String?,
      cargoIconUrl: row['cargo_type_icon_url'] as String?,
      vehicleTypeId: row['vehicle_type_id'] as String?,
      vehicleIconUrl: row['vehicle_type_icon_url'] as String?,
      customerName: row['customer_name'] as String? ?? 'SafeShift customer',
      pickupDistanceKm: numOf(row['distance_to_pickup_km']),
      offerId: row['offer_id'] as String?,
      status: row['status'] as String?,
      customerPhone: row['customer_phone'] as String?,
      expiresAt: DateTime.tryParse('${row['expires_at'] ?? ''}'),
      completedAt: DateTime.tryParse('${row['completed_at'] ?? ''}'),
      scheduledAt: DateTime.tryParse('${row['scheduled_at'] ?? ''}'),
      acceptedAt: DateTime.tryParse('${row['accepted_at'] ?? ''}'),
      cargoDescription: row['cargo_description'] as String?,
      cargoWeightKg: optionalNum(row['cargo_weight_kg']),
      declaredValueTzs: optionalNum(row['declared_value_tzs']),
      cargoPhotoPaths: photos is List
          ? photos.whereType<String>().toList(growable: false)
          : const <String>[],
      offerTtlSeconds: (row['offer_ttl_seconds'] as num?)?.toInt(),
      pickupLat: optionalNum(row['pickup_lat']),
      pickupLng: optionalNum(row['pickup_lng']),
      destinationLat: optionalNum(row['destination_lat']),
      destinationLng: optionalNum(row['destination_lng']),
    );
  }

  DriverJob _tripFromRow(Map<String, dynamic> row) {
    double numOf(Object? value) => (value as num?)?.toDouble() ?? 0;
    return DriverJob(
      id: row['job_id'] as String,
      pickup: row['pickup_address'] as String? ?? '',
      destination: row['destination_address'] as String? ?? '',
      distanceKm: numOf(row['distance_km']),
      estimatedFareTzs: numOf(row['final_amount']).round(),
      cargoClass: row['cargo_type'] as String? ?? 'Cargo',
      cargoTypeId: row['cargo_type_id'] as String?,
      cargoIconUrl: row['cargo_type_icon_url'] as String?,
      vehicleTypeId: row['vehicle_type_id'] as String?,
      vehicleIconUrl: row['vehicle_type_icon_url'] as String?,
      customerName: row['customer_name'] as String? ?? 'SafeShift customer',
      pickupDistanceKm: 0,
      status: row['status'] as String?,
      completedAt: DateTime.tryParse('${row['completed_at'] ?? ''}'),
      scheduledAt: DateTime.tryParse('${row['scheduled_at'] ?? ''}'),
      cargoDescription: row['cargo_description'] as String?,
    );
  }
}
