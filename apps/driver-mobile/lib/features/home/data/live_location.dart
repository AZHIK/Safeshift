import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:safeshift_shared/safeshift_shared.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// One accepted GPS fix.
class LiveFix {
  const LiveFix({
    required this.lat,
    required this.lng,
    required this.at,
    this.heading,
    this.speedKmh,
    this.accuracyM,
  });

  final double lat;
  final double lng;
  final DateTime at;

  /// Direction of travel, 0–359. Null when the device is not moving enough
  /// for the sensor heading to mean anything.
  final double? heading;
  final double? speedKmh;
  final double? accuracyM;

  GeoPoint get point => (lat: lat, lng: lng);

  Map<String, dynamic> toBroadcast() => <String, dynamic>{
    'lat': lat,
    'lng': lng,
    'heading': ?heading?.round(),
    if (speedKmh != null)
      'speed_kmh': double.parse(speedKmh!.toStringAsFixed(1)),
    'accuracy_m': ?accuracyM?.round(),
    'at': at.toUtc().toIso8601String(),
  };
}

/// Drops GPS fixes that would make the marker jump: poor accuracy, physically
/// impossible jumps, and out-of-order timestamps.
class GpsFilter {
  GpsFilter({this.maxAccuracyM = 50, this.maxSpeedMps = 55});

  /// Fixes less accurate than this are ignored (metres).
  final double maxAccuracyM;

  /// About 200 km/h; anything faster between two fixes is a GPS jump.
  final double maxSpeedMps;

  LiveFix? _last;
  LiveFix? get last => _last;

  /// Returns the fix when it should be used, or null to discard it.
  LiveFix? accept(LiveFix fix) {
    final accuracy = fix.accuracyM;
    if (accuracy != null && accuracy > maxAccuracyM) return null;
    final previous = _last;
    if (previous != null) {
      final seconds = fix.at.difference(previous.at).inMilliseconds / 1000.0;
      if (seconds <= 0) return null;
      final metres = distanceMeters(previous.point, fix.point);
      if (metres / seconds > maxSpeedMps) return null;
    }
    _last = fix;
    return fix;
  }

  void reset() => _last = null;
}

/// Streams the driver's position to the job's private Realtime channel.
///
/// Broadcast messages are not stored, so a fix every few seconds costs no
/// database writes. The database only authorises the channel: the assigned
/// driver may send on `job-location:<job id>` while the job is live.
class LiveLocationBroadcaster {
  LiveLocationBroadcaster(
    this._client, {
    this.minInterval = const Duration(seconds: 3),
  });

  final SupabaseClient _client;
  final Duration minInterval;

  RealtimeChannel? _channel;
  String? _jobId;
  bool _joined = false;
  DateTime? _lastSentAt;
  GeoPoint? _lastSentPoint;

  String? get jobId => _jobId;

  /// Opens the channel for [jobId], or closes it when null.
  void attach(String? jobId) {
    if (jobId == _jobId) return;
    detach();
    if (jobId == null) return;
    _jobId = jobId;
    _channel = _client.channel(
      'job-location:$jobId',
      opts: const RealtimeChannelConfig(private: true),
    );
    _channel!.subscribe((status, error) {
      _joined = status == RealtimeSubscribeStatus.subscribed;
      if (error != null) debugPrint('Live location channel: $error');
    });
  }

  /// Sends [fix] unless one was sent moments ago and the driver barely moved.
  Future<void> send(LiveFix fix) async {
    final channel = _channel;
    if (channel == null || !_joined) return;
    final now = DateTime.now();
    final lastAt = _lastSentAt;
    final lastPoint = _lastSentPoint;
    if (lastAt != null && now.difference(lastAt) < minInterval) return;
    // Standing still: a heartbeat every 15 s is enough.
    if (lastAt != null &&
        lastPoint != null &&
        distanceMeters(lastPoint, fix.point) < 3 &&
        now.difference(lastAt) < const Duration(seconds: 15)) {
      return;
    }
    _lastSentAt = now;
    _lastSentPoint = fix.point;
    try {
      await channel.sendBroadcastMessage(
        event: 'position',
        payload: fix.toBroadcast(),
      );
    } catch (_) {
      // Live updates are best effort; the 30 s history write still lands.
    }
  }

  void detach() {
    final channel = _channel;
    _channel = null;
    _jobId = null;
    _joined = false;
    _lastSentAt = null;
    _lastSentPoint = null;
    if (channel != null) unawaited(_client.removeChannel(channel));
  }
}
