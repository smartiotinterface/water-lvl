// lib/services/notification_service.dart
// v13.1.1 — [FIX] onTokenRefresh also uploads to RTDB
// ─────────────────────────────────────────────────────────────────────────────
// [FIX] onTokenRefresh callback এ নতুন token RTDB-তেও update হয়।
//       আগে শুধু SecureStorage-এ save হতো। Firebase মাঝে মাঝে token rotate
//       করে — সেক্ষেত্রে push notification বন্ধ হয়ে যেত।

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';
import '../core/secure_storage.dart';
import 'firebase_service.dart';

// Top-level handler required by Firebase (must be outside any class)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('[FCM] Background message: ${message.messageId}');
}

class NotificationService {
  NotificationService._();

  static final _messaging = FirebaseMessaging.instance;
  static final _localNotif = FlutterLocalNotificationsPlugin();
  static final _fbService = FirebaseService();

  static const _channelId   = 'smartiot_alerts';
  static const _channelName = 'SmartIoT Alerts';
  static const _channelDesc = 'Water tank level and pump alerts';

  // ── Init ─────────────────────────────────────────────────────────────
  static Future<void> init() async {
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    debugPrint('[FCM] Permission: ${settings.authorizationStatus}');

    const androidChannel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: _channelDesc,
      importance: Importance.high,
      playSound: true,
    );

    final androidPlugin =
        _localNotif.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(androidChannel);

    const initSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    );
    await _localNotif.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    // Save FCM token locally
    final token = await _messaging.getToken();
    if (token != null) {
      await SecureStorage.setFcmToken(token);
      debugPrint('[FCM] Token saved (${token.length} chars)');
    }

    // [FIX] onTokenRefresh: save locally AND upload to RTDB if user logged in
    _messaging.onTokenRefresh.listen((newToken) async {
      await SecureStorage.setFcmToken(newToken);
      // Upload to RTDB if user is currently logged in
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        try {
          await _fbService.uploadFcmToken(uid, newToken);
          debugPrint('[FCM] Refreshed token uploaded to RTDB for uid=$uid');
        } catch (e) {
          debugPrint('[FCM] Token refresh upload failed (non-fatal): $e');
        }
      }
    });

    FirebaseMessaging.onMessage.listen(_handleForeground);
  }

  // ── Handlers ──────────────────────────────────────────────────────────
  static void _handleForeground(RemoteMessage message) {
    final notif = message.notification;
    if (notif == null) return;

    _localNotif.show(
      message.hashCode,
      notif.title ?? 'SmartIoT Alert',
      notif.body ?? '',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDesc,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: DarwinNotificationDetails(),
      ),
    );
  }

  static void _onNotificationTap(NotificationResponse response) {
    debugPrint('[FCM] Notification tapped: ${response.payload}');
  }

  // ── Helpers ───────────────────────────────────────────────────────────
  static Future<String?> getToken() => SecureStorage.getFcmToken();

  static Future<void> showLocalAlert({
    required String title,
    required String body,
  }) async {
    await _localNotif.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
      ),
    );
  }
}
