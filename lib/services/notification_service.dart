import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

@pragma('vm:entry-point')
Future<void> _handleBackgroundMessage(RemoteMessage message) async {
  debugPrint("Notification (background): ${message.notification?.title}");
}

class NotificationService {
  static final _messaging = FirebaseMessaging.instance;
  static final _supabase = Supabase.instance.client;

  static Future<void> init() async {
    await _requestPermission();

    final token = await _messaging.getToken();
    await _saveToken(token);

    _messaging.onTokenRefresh.listen(_saveToken);

    FirebaseMessaging.onBackgroundMessage(_handleBackgroundMessage);
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);
  }

  static Future<void> _requestPermission() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    debugPrint("Notification permission: ${settings.authorizationStatus}");
  }

  static Future<void> _saveToken(String? token) async {
    if (token == null) return;
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;
    try {
      await _supabase.from('profiles').upsert({
        'id': userId,
        'fcm_token': token,
      });
      debugPrint("FCM token saved: $token");
    } catch (e) {
      debugPrint("FCM token save error: $e");
    }
  }

  static void _handleForegroundMessage(RemoteMessage message) {
    debugPrint("Notification (foreground): ${message.notification?.title}");
  }

  static void _handleNotificationTap(RemoteMessage message) {
    debugPrint("Notification tap: ${message.notification?.title}");
  }
}
