import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/mock/mock_jobs.dart';

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
  const DailyEarning({required this.day, required this.date, required this.amount});
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
    this.make,
    this.model,
    this.year,
    this.color,
    this.capacityKg,
    this.photoUrls = const <String>[],
  });

  final String id;
  final String registrationNumber;
  final String vehicleType;
  final String verificationStatus;
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

  Future<void> updateLocation({
    required double latitude,
    required double longitude,
    String? jobId,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;
    final point = 'SRID=4326;POINT($longitude $latitude)';
    await _client
        .from('drivers')
        .update(<String, dynamic>{
          'current_location': point,
          'location_updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', userId);
    await _client.from('driver_locations').insert(<String, dynamic>{
      'driver_id': userId,
      'job_id': jobId,
      'location': point,
    });
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
      verificationStatus: raw['verification_status'] as String? ?? 'pending',
      make: raw['make'] as String?,
      model: raw['model'] as String?,
      year: (raw['year'] as num?)?.toInt(),
      color: raw['color'] as String?,
      capacityKg: (raw['capacity_kg'] as num?)?.toInt(),
      photoUrls: photos is List ? photos.whereType<String>().toList() : const [],
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
    return DriverJob(
      id: row['job_id'] as String,
      pickup: row['pickup_address'] as String? ?? '',
      destination: row['destination_address'] as String? ?? '',
      distanceKm: numOf(row['distance_km']),
      estimatedFareTzs: numOf(row['estimated_fare']).round(),
      cargoClass: row['cargo_type'] as String? ?? 'Cargo',
      customerName: row['customer_name'] as String? ?? 'SafeShift customer',
      pickupDistanceKm: numOf(row['distance_to_pickup_km']),
      offerId: row['offer_id'] as String?,
      status: row['status'] as String?,
      customerPhone: row['customer_phone'] as String?,
      expiresAt: DateTime.tryParse('${row['expires_at'] ?? ''}'),
      completedAt: DateTime.tryParse('${row['completed_at'] ?? ''}'),
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
      customerName: row['customer_name'] as String? ?? 'SafeShift customer',
      pickupDistanceKm: 0,
      status: row['status'] as String?,
      completedAt: DateTime.tryParse('${row['completed_at'] ?? ''}'),
    );
  }
}
