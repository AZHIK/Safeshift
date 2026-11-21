import 'dart:io';
import 'dart:typed_data';

import 'package:safeshift_shared/safeshift_shared.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/api_config.dart';
import '../../../shared/models/ride_place.dart';

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
    this.pickupLat,
    this.pickupLng,
    this.destinationLat,
    this.destinationLng,
    this.scheduledAt,
    this.acceptedAt,
    this.cancelledAt,
    this.cancellationReason,
    this.cancellationFee,
    this.dispatchAttempts = 0,
    this.lastDispatchedAt,
    this.driverId,
    this.driverName,
    this.driverPhone,
    this.driverRating = 0,
    this.driverVerified = false,
    this.driverLat,
    this.driverLng,
    this.driverLocationUpdatedAt,
    this.driverLocationFresh = false,
    this.vehicleType,
    this.vehicleTypeId,
    this.vehicleTypeIconUrl,
    this.cargoType,
    this.cargoTypeId,
    this.cargoTypeIconUrl,
    this.cargoDescription,
    this.cargoWeightKg,
    this.declaredValueTzs,
    this.cargoPhotoPaths = const <String>[],
    this.paymentMethod,
  });

  final String id;
  final String status;
  final String pickupAddress;
  final String destinationAddress;

  /// Pickup coordinate from `quote_requests.pickup_location`.
  final double? pickupLat;
  final double? pickupLng;

  /// Drop-off coordinate from `quote_requests.destination_location`.
  final double? destinationLat;
  final double? destinationLng;

  final double amount;
  final double distanceKm;
  final DateTime? createdAt;
  final DateTime? scheduledAt;
  final DateTime? acceptedAt;
  final DateTime? completedAt;
  final DateTime? cancelledAt;
  final String? cancellationReason;
  final double? cancellationFee;
  final int dispatchAttempts;
  final DateTime? lastDispatchedAt;
  final String? driverId;
  final String? driverName;
  final String? driverPhone;
  final double driverRating;
  final bool driverVerified;
  final double? driverLat;
  final double? driverLng;
  final DateTime? driverLocationUpdatedAt;
  final bool driverLocationFresh;
  final String? vehicleType;

  /// `public.vehicle_types.id` of the booked vehicle category.
  final String? vehicleTypeId;

  /// Icon path of the vehicle category, served from the catalogue bucket.
  final String? vehicleTypeIconUrl;

  final String? cargoType;

  /// `public.cargo_types.id` of the booked cargo type.
  final String? cargoTypeId;

  /// Icon path of the cargo type, served from the catalogue bucket.
  final String? cargoTypeIconUrl;

  final String? cargoDescription;
  final double? cargoWeightKg;
  final double? declaredValueTzs;

  /// Object paths of the parcel photos in the private `job-evidence` bucket.
  final List<String> cargoPhotoPaths;

  final String? paymentMethod;

  bool get isTerminal => status == 'completed' || status == 'cancelled';
  bool get isDelivered => status == 'delivered' || status == 'completed';
  bool get isScheduledLater =>
      scheduledAt != null &&
      scheduledAt!.isAfter(DateTime.now().add(const Duration(minutes: 45)));

  /// The pickup time the customer actually chose, or null for an ASAP move.
  ///
  /// The server fills `scheduled_at` with the booking time when the customer
  /// asked for "now", so a time within a couple of minutes of `created_at`
  /// is not a real schedule.
  DateTime? get customerPickupTime {
    final at = scheduledAt;
    if (at == null) return null;
    final created = createdAt;
    if (created != null &&
        at.difference(created) < const Duration(minutes: 2)) {
      return null;
    }
    return at;
  }
}

/// How available a vehicle type is near the pickup point.
enum VehicleAvailabilityStatus {
  /// A free driver is close; booking now should match quickly.
  available,

  /// Drivers exist but are busy or further away; the search may take longer.
  limited,

  /// Nobody online nearby; only scheduling for later makes sense.
  none,
}

class VehicleAvailability {
  const VehicleAvailability(this.status, {this.etaMin});

  static const unavailable = VehicleAvailability(
    VehicleAvailabilityStatus.none,
  );

  final VehicleAvailabilityStatus status;

  /// Rounded minutes to the nearest free driver, when one is known.
  final int? etaMin;

  bool get isNone => status == VehicleAvailabilityStatus.none;

  /// Sort key: available first, then limited, then none.
  int get rank => status.index;
}

class DispatchResult {
  const DispatchResult({
    required this.count,
    required this.reason,
    this.diagnostics,
  });

  /// Number of drivers the job was offered to.
  final int count;

  /// Why no driver matched, when [count] is zero.
  final String? reason;

  /// How many drivers survived each dispatch filter, for diagnostics.
  final Map<String, dynamic>? diagnostics;
}

/// What cancelling the move right now would cost, from the server's
/// cancellation policy. Read-only.
class CancellationPreview {
  const CancellationPreview({
    required this.cancellable,
    required this.fee,
    required this.currencyCode,
    this.freeUntil,
    this.message,
  });

  final bool cancellable;
  final double fee;
  final String currencyCode;

  /// When the fee starts applying, if cancelling is still free.
  final DateTime? freeUntil;

  /// Why the move cannot be cancelled in the app, when [cancellable] is false.
  final String? message;
}

class RideRepository {
  RideRepository(this._client);

  final SupabaseClient _client;

  Future<QuoteSnapshot> requestQuote({
    required RidePlace pickup,
    required RidePlace destination,
    required VehicleTypeOption vehicle,
    CargoTypeOption? cargo,
    double? weightKg,
    int? valueTzs,
    DateTime? scheduledAt,
    String? cargoDescription,
  }) async {
    final description = cargoDescription?.trim();
    final response = await _client.functions.invoke(
      ApiConfig.quoteCalculate,
      body: <String, dynamic>{
        'pickup': <String, dynamic>{
          'lat': pickup.latitude,
          'lng': pickup.longitude,
          'address': pickup.formattedAddress ?? pickup.name,
        },
        'destination': <String, dynamic>{
          'lat': destination.latitude,
          'lng': destination.longitude,
          'address': destination.formattedAddress ?? destination.name,
        },
        'vehicle_type_id': vehicle.id,
        'cargo_type_id': ?cargo?.id,
        'cargo_weight_kg': ?weightKg,
        'declared_value_tzs': ?valueTzs,
        if (scheduledAt != null)
          'scheduled_at': scheduledAt.toUtc().toIso8601String(),
        if (description != null && description.isNotEmpty)
          'cargo_description': description,
      },
    );
    final envelope = response.data;
    if (envelope is! Map || envelope['data'] is! Map) {
      throw const FormatException(
        'Quote service returned an invalid response.',
      );
    }
    final result = (envelope['data'] as Map).cast<String, dynamic>();
    final quoteId = result['quote_id'] as String?;
    final snapshot = (result['breakdown'] as Map?)?.cast<String, dynamic>();
    if (quoteId == null || snapshot == null) {
      throw const FormatException(
        'Quote service returned an incomplete quote.',
      );
    }
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
      distanceKm: money(calculation['distance_km']),
      durationMin: (calculation['duration_min'] as num?)?.toInt() ?? 0,
      currencyCode: (finalPart['currency_code'] as String?) ?? 'TZS',
      expiresAt: DateTime.tryParse('${finalPart['expires_at'] ?? ''}'),
    );
  }

  Future<CustomerJobSnapshot> createJob(
    String quoteId, {
    String? paymentMethod,
  }) async {
    final row = await _client
        .from('jobs')
        .insert(<String, dynamic>{
          'quote_id': quoteId,
          'payment_method': ?paymentMethod,
        })
        .select('id')
        .single();
    final id = row['id'] as String;
    final snapshot = await getJob(id);
    if (snapshot == null) {
      throw StateError('Job was created but could not be loaded.');
    }
    return snapshot;
  }

  /// Uploads the customer's parcel photos for a freshly created job and
  /// attaches their object paths so the assigned driver can see them.
  ///
  /// Photos are taken before the job exists (the parcel dialog works on the
  /// confirmation sheet), so they are uploaded only after the job id is known
  /// and before dispatch starts.
  Future<List<String>> uploadParcelPhotos({
    required String jobId,
    required List<String> localPaths,
  }) async {
    if (localPaths.isEmpty) return const <String>[];
    final uploaded = <String>[];
    for (var i = 0; i < localPaths.length; i++) {
      final path = localPaths[i];
      final file = File(path);
      if (!await file.exists()) continue;
      final dot = path.lastIndexOf('.');
      final ext = dot >= 0 ? path.substring(dot + 1).toLowerCase() : 'jpg';
      final mime = _imageMimeType(ext);
      if (mime == null) continue;
      final objectPath = _storagePath(
        jobId,
        'parcel_${i}_${path.split(Platform.pathSeparator).last}',
      );
      await _client.storage
          .from('job-evidence')
          .uploadBinary(
            objectPath,
            await file.readAsBytes(),
            fileOptions: FileOptions(contentType: mime, upsert: false),
          );
      uploaded.add(objectPath);
    }
    if (uploaded.isEmpty) return const <String>[];
    await _client.rpc<void>(
      'job_attach_parcel_photos',
      params: <String, dynamic>{'p_job_id': jobId, 'p_photo_paths': uploaded},
    );
    return uploaded;
  }

  /// Copies parcel photos already stored for another job of this customer
  /// into [jobId]'s folder and attaches them to the new job.
  ///
  /// Used when a resumed search switches vehicle class: the local files are
  /// gone, but the photos are still in storage under the old job. Drivers can
  /// only read photos inside the folder of the job they were offered, so the
  /// objects must be copied rather than referenced.
  Future<List<String>> copyParcelPhotos({
    required String jobId,
    required List<String> sourcePaths,
  }) async {
    if (sourcePaths.isEmpty) return const <String>[];
    final bucket = _client.storage.from('job-evidence');
    final copied = <String>[];
    for (final source in sourcePaths) {
      final name = source.split('/').last;
      final target = _storagePath(jobId, name);
      await bucket.copy(source, target);
      copied.add(target);
    }
    await _client.rpc<void>(
      'job_attach_parcel_photos',
      params: <String, dynamic>{'p_job_id': jobId, 'p_photo_paths': copied},
    );
    return copied;
  }

  /// The most recent job that has not reached a terminal state.
  ///
  /// Used on app start so a customer who closed the app while searching or in
  /// transit lands back on the live tracking screen instead of an empty form.
  Future<CustomerJobSnapshot?> getActiveJob() async {
    final rows = await _client.rpc<List<dynamic>>(
      'customer_jobs',
      params: <String, dynamic>{'p_limit': 20},
    );
    for (final row in rows) {
      final job = _jobFromRow((row as Map).cast<String, dynamic>());
      if (!job.isTerminal) return job;
    }
    return null;
  }

  /// Runs a dispatch round. The server picks the search radius from the
  /// attempt count, rate-limits rounds and retires the move after six
  /// attempts, so the app never sends a radius of its own.
  Future<DispatchResult> dispatch(String jobId) async {
    final response = await _client.rpc<Map<String, dynamic>>(
      'job_request_dispatch',
      params: <String, dynamic>{'p_job_id': jobId},
    );
    return DispatchResult(
      count: (response['count'] as num?)?.toInt() ?? 0,
      reason: response['reason'] as String?,
      diagnostics: (response['diagnostics'] as Map?)?.cast<String, dynamic>(),
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

  /// Sets (or clears, with nulls) the person receiving the goods.
  Future<void> setRecipient(String jobId, {String? name, String? phone}) {
    return _client.rpc<void>(
      'job_set_recipient',
      params: <String, dynamic>{
        'p_job_id': jobId,
        'p_name': name,
        'p_phone': phone,
      },
    );
  }

  Future<({String? name, String? phone})> getRecipient(String jobId) async {
    final row = await _client.rpc<Map<String, dynamic>>(
      'job_recipient',
      params: <String, dynamic>{'p_job_id': jobId},
    );
    return (name: row['name'] as String?, phone: row['phone'] as String?);
  }

  Future<String> issueDeliveryOtp(String jobId) {
    return _client.rpc<String>(
      'job_issue_delivery_otp',
      params: <String, dynamic>{'p_job_id': jobId},
    );
  }

  /// Customer-side confirmation that the goods arrived.
  Future<void> confirmDelivery(String jobId) {
    return _client.rpc<void>(
      'job_confirm_delivery',
      params: <String, dynamic>{'p_job_id': jobId},
    );
  }

  /// Free, online, nearby drivers per vehicle type for [jobId]'s pickup,
  /// keyed by `vehicle_types.id`. Uses the same filters as dispatch except
  /// the vehicle class, so the customer can switch to a class that has
  /// drivers.
  Future<Map<String, int>> availableVehicleTypes(
    String jobId, {
    double radiusKm = 15,
  }) async {
    final rows = await _client.rpc<List<dynamic>>(
      'job_available_vehicle_types',
      params: <String, dynamic>{'p_job_id': jobId, 'p_radius_km': radiusKm},
    );
    final counts = <String, int>{};
    for (final row in rows) {
      final map = (row as Map).cast<String, dynamic>();
      final id = map['vehicle_type_id'] as String?;
      final count = (map['driver_count'] as num?)?.toInt() ?? 0;
      if (id != null && count > 0) counts[id] = count;
    }
    return counts;
  }

  /// Availability per vehicle type id near a pickup point. Types missing from
  /// the map have nobody online within the widest dispatch radius.
  Future<Map<String, VehicleAvailability>> vehicleAvailabilityNear({
    required double lat,
    required double lng,
  }) async {
    final rows = await _client.rpc<List<dynamic>>(
      'vehicle_availability_near',
      params: <String, dynamic>{'p_lat': lat, 'p_lng': lng},
    );
    final result = <String, VehicleAvailability>{};
    for (final row in rows) {
      final map = (row as Map).cast<String, dynamic>();
      final id = map['vehicle_type_id'] as String?;
      if (id == null) continue;
      final status = switch (map['status']) {
        'available' => VehicleAvailabilityStatus.available,
        'limited' => VehicleAvailabilityStatus.limited,
        _ => VehicleAvailabilityStatus.none,
      };
      result[id] = VehicleAvailability(
        status,
        etaMin: (map['eta_min'] as num?)?.toInt(),
      );
    }
    return result;
  }

  Future<CancellationPreview> cancellationPreview(String jobId) async {
    final row = await _client.rpc<Map<String, dynamic>>(
      'job_cancellation_preview',
      params: <String, dynamic>{'p_job_id': jobId},
    );
    return CancellationPreview(
      cancellable: row['cancellable'] == true,
      fee: (row['fee'] as num?)?.toDouble() ?? 0,
      currencyCode: (row['currency_code'] as String?) ?? 'TZS',
      freeUntil: DateTime.tryParse('${row['free_until'] ?? ''}'),
      message: row['message'] as String?,
    );
  }

  /// End of the driver's free waiting window at pickup, or null when the
  /// driver is not waiting.
  Future<DateTime?> pickupFreeWaitEndsAt(String jobId) async {
    final row = await _client.rpc<Map<String, dynamic>>(
      'job_pickup_wait',
      params: <String, dynamic>{'p_job_id': jobId},
    );
    if (row['waiting'] != true) return null;
    return DateTime.tryParse('${row['free_wait_ends_at'] ?? ''}');
  }

  Future<void> cancelJob(
    String jobId,
    String customerId, {
    String reason = 'Customer cancelled while searching',
  }) {
    return _client.rpc<void>(
      'job_cancel',
      params: <String, dynamic>{
        'p_job_id': jobId,
        'p_cancelled_by': customerId,
        'p_reason': reason,
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
    double? optionalMoney(Object? value) =>
        value == null ? null : (value as num?)?.toDouble();
    double? coordinate(Object? value) =>
        value == null ? null : (value as num).toDouble();
    final photos = row['cargo_photo_paths'];
    return CustomerJobSnapshot(
      id: row['job_id'] as String,
      status: row['status'] as String? ?? 'requested',
      pickupAddress: row['pickup_address'] as String? ?? '',
      destinationAddress: row['destination_address'] as String? ?? '',
      pickupLat: coordinate(row['pickup_lat']),
      pickupLng: coordinate(row['pickup_lng']),
      destinationLat: coordinate(row['destination_lat']),
      destinationLng: coordinate(row['destination_lng']),
      amount: money(row['final_amount']),
      distanceKm: money(row['distance_km']),
      createdAt: DateTime.tryParse('${row['created_at'] ?? ''}'),
      scheduledAt: DateTime.tryParse('${row['scheduled_at'] ?? ''}'),
      acceptedAt: DateTime.tryParse('${row['accepted_at'] ?? ''}'),
      completedAt: DateTime.tryParse('${row['completed_at'] ?? ''}'),
      cancelledAt: DateTime.tryParse('${row['cancelled_at'] ?? ''}'),
      cancellationReason: row['cancellation_reason'] as String?,
      cancellationFee: optionalMoney(row['cancellation_fee']),
      dispatchAttempts: (row['dispatch_attempts'] as num?)?.toInt() ?? 0,
      lastDispatchedAt: DateTime.tryParse('${row['last_dispatched_at'] ?? ''}'),
      driverId: row['driver_id'] as String?,
      driverName: row['driver_name'] as String?,
      driverPhone: row['driver_phone'] as String?,
      driverRating: money(row['driver_rating']),
      driverVerified: row['driver_verified'] as bool? ?? false,
      driverLat: coordinate(row['driver_lat']),
      driverLng: coordinate(row['driver_lng']),
      driverLocationUpdatedAt: DateTime.tryParse(
        '${row['driver_location_updated_at'] ?? ''}',
      ),
      driverLocationFresh: row['driver_location_fresh'] as bool? ?? false,
      vehicleType: row['vehicle_type'] as String?,
      vehicleTypeId: row['vehicle_type_id'] as String?,
      vehicleTypeIconUrl: row['vehicle_type_icon_url'] as String?,
      cargoType: row['cargo_type'] as String?,
      cargoTypeId: row['cargo_type_id'] as String?,
      cargoTypeIconUrl: row['cargo_type_icon_url'] as String?,
      cargoDescription: row['cargo_description'] as String?,
      cargoWeightKg: optionalMoney(row['cargo_weight_kg']),
      declaredValueTzs: optionalMoney(row['declared_value_tzs']),
      cargoPhotoPaths: photos is List
          ? photos.whereType<String>().toList(growable: false)
          : const <String>[],
      paymentMethod: row['payment_method'] as String?,
    );
  }

  static String? _imageMimeType(String extension) {
    switch (extension) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      default:
        return null;
    }
  }
}
