import 'dart:async';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Firebase Cloud Messaging + local foreground notifications.
///
/// Firebase options are supplied at build time so no service-account secret or
/// platform config file is committed:
///   `--dart-define=FIREBASE_API_KEY=...`
///   `--dart-define=FIREBASE_APP_ID=...`
///   `--dart-define=FIREBASE_MESSAGING_SENDER_ID=...`
///   `--dart-define=FIREBASE_PROJECT_ID=...`
///
/// When these are absent (local UI work/tests) push is disabled gracefully.
class PushService {
  static bool _firebaseReady = false;
  static final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();
  static const FlutterSecureStorage _storage = FlutterSecureStorage();
  static StreamSubscription<String>? _tokenRefreshSubscription;

  /// Notification taps, as raw links (`safeshift://tracking/<id>`).
  ///
  /// The router is not always listening when a cold start delivers its initial
  /// message, so the first link is parked and drained by the app shell.
  static final StreamController<String> _deepLinks =
      StreamController<String>.broadcast();
  static String? _pendingDeepLink;

  static const String _apiKey = String.fromEnvironment('FIREBASE_API_KEY');
  static const String _appId = String.fromEnvironment('FIREBASE_APP_ID');
  static const String _senderId = String.fromEnvironment(
    'FIREBASE_MESSAGING_SENDER_ID',
  );
  static const String _projectId = String.fromEnvironment(
    'FIREBASE_PROJECT_ID',
  );
  static const String _storageBucket = String.fromEnvironment(
    'FIREBASE_STORAGE_BUCKET',
  );

  static bool get isAvailable => _firebaseReady;

  /// Raw links from tapped notifications.
  static Stream<String> get deepLinks => _deepLinks.stream;

  /// A link delivered before anybody was listening, or null.
  static String? takePendingDeepLink() {
    final link = _pendingDeepLink;
    _pendingDeepLink = null;
    return link;
  }

  static FirebaseOptions? get _options {
    if (_apiKey.isEmpty ||
        _appId.isEmpty ||
        _senderId.isEmpty ||
        _projectId.isEmpty) {
      return null;
    }
    return FirebaseOptions(
      apiKey: _apiKey,
      appId: _appId,
      messagingSenderId: _senderId,
      projectId: _projectId,
      storageBucket: _storageBucket.isEmpty ? null : _storageBucket,
    );
  }

  static Future<void> initialize() async {
    final options = _options;
    if (options == null) return;
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(options: options);
      }
      _firebaseReady = true;

      // Background isolates are separate; this handler must exist before any
      // message can arrive.
      FirebaseMessaging.onBackgroundMessage(_firebaseBackgroundHandler);

      const settings = InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      );
      await _local.initialize(
        settings: settings,
        onDidReceiveNotificationResponse: (response) {
          _emitDeepLink(response.payload);
        },
      );

      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission(alert: true, badge: true, sound: true);

      FirebaseMessaging.onMessage.listen(_showForeground);
      FirebaseMessaging.onMessageOpenedApp.listen((message) {
        _emitDeepLink(message.data['deep_link'] as String?);
      });

      // Cold start from a notification tap.
      final initial = await messaging.getInitialMessage();
      if (initial != null) {
        _emitDeepLink(initial.data['deep_link'] as String?);
      }
    } catch (error) {
      _firebaseReady = false;
      debugPrint('Push notifications unavailable: $error');
    }
  }

  static void _showForeground(RemoteMessage message) {
    final notification = message.notification;
    final data = message.data;
    final title = notification?.title ?? data['title'] as String?;
    final body = notification?.body ?? data['body'] as String?;
    if (title == null && body == null) return;
    unawaited(
      _local.show(
        id: notification?.hashCode ?? message.messageId.hashCode,
        title: title,
        body: body,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'safeshift_jobs',
            'SafeShift jobs',
            channelDescription: 'Job and delivery updates',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        payload: data['deep_link'] as String?,
      ),
    );
  }

  static void _emitDeepLink(String? link) {
    final trimmed = link?.trim();
    if (trimmed == null || trimmed.isEmpty) return;
    if (_deepLinks.hasListener) {
      _deepLinks.add(trimmed);
    } else {
      _pendingDeepLink = trimmed;
    }
  }

  Future<String?> _deviceId() async {
    final existing = await _storage.read(key: 'safeshift_push_device_id');
    if (existing != null && existing.isNotEmpty) return existing;
    final generated =
        '${Platform.operatingSystem}-${DateTime.now().microsecondsSinceEpoch}';
    await _storage.write(key: 'safeshift_push_device_id', value: generated);
    return generated;
  }

  Future<void> registerForUser(String userId, SupabaseClient client) async {
    if (!_firebaseReady) return;
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null || token.isEmpty) return;
      final deviceId = await _deviceId();
      if (deviceId == null) return;
      final type = kIsWeb
          ? 'web'
          : Platform.isIOS
          ? 'ios'
          : 'android';
      final now = DateTime.now().toUtc().toIso8601String();

      // user_devices is the human-readable device registry; push_tokens is
      // what push-send reads, and its device_id is a UUID FK to user_devices.
      final deviceRow = await client
          .from('user_devices')
          .upsert(<String, dynamic>{
            'profile_id': userId,
            'device_id': deviceId,
            'device_type': type,
            'device_name': Platform.operatingSystem,
            'os_version': Platform.operatingSystemVersion,
            'push_token': token,
            'push_provider': 'fcm',
            'last_seen_at': now,
            'is_active': true,
          }, onConflict: 'profile_id,device_id')
          .select('id')
          .single();
      final rowId = deviceRow['id'] as String?;
      if (rowId == null) return;

      await _upsertPushToken(
        client: client,
        profileId: userId,
        deviceRowId: rowId,
        token: token,
        type: type,
        now: now,
      );

      await _tokenRefreshSubscription?.cancel();
      _tokenRefreshSubscription = FirebaseMessaging.instance.onTokenRefresh
          .listen((fresh) async {
            try {
              await _upsertPushToken(
                client: client,
                profileId: userId,
                deviceRowId: rowId,
                token: fresh,
                type: type,
                now: DateTime.now().toUtc().toIso8601String(),
              );
              await client
                  .from('user_devices')
                  .update(<String, dynamic>{
                    'push_token': fresh,
                    'last_seen_at': DateTime.now().toUtc().toIso8601String(),
                  })
                  .eq('id', rowId);
            } catch (error) {
              debugPrint('Push token refresh failed: $error');
            }
          });
    } catch (error) {
      debugPrint('Push token registration failed: $error');
    }
  }

  Future<void> _upsertPushToken({
    required SupabaseClient client,
    required String profileId,
    required String deviceRowId,
    required String token,
    required String type,
    required String now,
  }) async {
    await client.from('push_tokens').upsert(<String, dynamic>{
      'profile_id': profileId,
      'device_id': deviceRowId,
      'token': token,
      'provider': 'fcm',
      'platform': type,
      'is_active': true,
      'last_used_at': now,
    }, onConflict: 'profile_id,device_id');
  }

  Future<void> unregister() async {
    if (!_firebaseReady) return;
    await _tokenRefreshSubscription?.cancel();
    _tokenRefreshSubscription = null;
    try {
      await FirebaseMessaging.instance.deleteToken();
    } catch (_) {
      // Best effort on sign-out.
    }
  }
}

/// Runs in a background isolate, so Firebase has to be bootstrapped again.
@pragma('vm:entry-point')
Future<void> _firebaseBackgroundHandler(RemoteMessage message) async {
  final options = PushService._options;
  if (options != null && Firebase.apps.isEmpty) {
    await Firebase.initializeApp(options: options);
  }
}

final pushServiceProvider = Provider<PushService>((ref) => PushService());
