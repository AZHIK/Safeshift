import 'dart:async';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

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

  static Future<void> initialize() async {
    if (_apiKey.isEmpty ||
        _appId.isEmpty ||
        _senderId.isEmpty ||
        _projectId.isEmpty) {
      return;
    }
    try {
      await Firebase.initializeApp(
        options: FirebaseOptions(
          apiKey: _apiKey,
          appId: _appId,
          messagingSenderId: _senderId,
          projectId: _projectId,
          storageBucket: _storageBucket.isEmpty ? null : _storageBucket,
        ),
      );
      _firebaseReady = true;

      const settings = InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      );
      await _local.initialize(settings: settings);

      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission(alert: true, badge: true, sound: true);
      FirebaseMessaging.onMessage.listen((message) {
        final notification = message.notification;
        if (notification == null) return;
        unawaited(
          _local.show(
            id: notification.hashCode,
            title: notification.title,
            body: notification.body,
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
          ),
        );
      });
    } catch (error) {
      _firebaseReady = false;
      debugPrint('Push notifications unavailable: $error');
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
      await client.from('user_devices').upsert(<String, dynamic>{
        'profile_id': userId,
        'device_id': deviceId,
        'device_type': type,
        'device_name': Platform.operatingSystem,
        'os_version': Platform.operatingSystemVersion,
        'push_token': token,
        'push_provider': 'fcm',
        'last_seen_at': DateTime.now().toUtc().toIso8601String(),
        'is_active': true,
      }, onConflict: 'profile_id,device_id');
      await _tokenRefreshSubscription?.cancel();
      _tokenRefreshSubscription = FirebaseMessaging.instance.onTokenRefresh
          .listen((fresh) async {
            await client
                .from('user_devices')
                .update(<String, dynamic>{
                  'push_token': fresh,
                  'last_seen_at': DateTime.now().toUtc().toIso8601String(),
                })
                .eq('profile_id', userId)
                .eq('device_id', deviceId);
          });
    } catch (error) {
      debugPrint('Push token registration failed: $error');
    }
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

final pushServiceProvider = Provider<PushService>((ref) => PushService());
