import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class NotificationService {
  static const String baseUrl = 'http://10.0.2.2:8000';
  static final FlutterLocalNotificationsPlugin _local = FlutterLocalNotificationsPlugin();
  static int? _currentDriverId;

  static Future<void> init(int driverId) async {
    _currentDriverId = driverId;

    // Config local notifications
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: android);
    await _local.initialize(settings);

    // Créer channel Android
    const channel = AndroidNotificationChannel(
      'alerts_channel',
      'Alertes Véhicule',
      description: 'Notifications de sécurité et alertes véhicule',
      importance: Importance.high,
    );

    final AndroidFlutterLocalNotificationsPlugin? androidImpl =
    _local.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await androidImpl?.createNotificationChannel(channel);

    // Demander permission
    final messaging = FirebaseMessaging.instance;
    await messaging.requestPermission(alert: true, badge: true, sound: true);

    // Récupérer et envoyer le token FCM
    final token = await messaging.getToken();
    if (token != null) await _sendTokenToBackend(token, driverId);

    // Écouter les messages foreground
    FirebaseMessaging.onMessage.listen((message) {
      _showLocalNotification(message);
    });

    // Token refresh
    messaging.onTokenRefresh.listen((token) => _sendTokenToBackend(token, driverId));
  }

  static void _showLocalNotification(RemoteMessage message) {
    final notification = message.notification;
    if (notification == null) return;

    _local.show(
      notification.hashCode,
      notification.title,
      notification.body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'alerts_channel',
          'Alertes Véhicule',
          channelDescription: 'Notifications de sécurité',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
      ),
    );
  }

  static Future<void> _sendTokenToBackend(String token, int driverId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/update-fcm-token'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "driver_id": driverId,
          "fcm_token": token,
        }),
      );

      if (response.statusCode == 200) {
        print('✅ Token FCM envoyé pour driver $driverId');
      } else {
        print('❌ Erreur envoi token: ${response.statusCode}');
      }
    } catch (e) {
      print("Erreur envoi token: $e");
    }
  }

  // Récupérer tous les events (pannes + documents)
  static Future<List<dynamic>> fetchAllEvents(int driverId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/events/all?driver_id=$driverId'),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['events'] ?? [];
      }
      return [];
    } catch (e) {
      print("Erreur fetch all events: $e");
      return [];
    }
  }

  // Marquer un event comme notifié (lu)
  static Future<void> markEventAsNotified(int eventId, int driverId) async {
    try {
      await http.post(
        Uri.parse('$baseUrl/api/events/$eventId/mark-notified?driver_id=$driverId'),
      );
    } catch (e) {
      print("Erreur mark event: $e");
    }
  }

  @pragma('vm:entry-point')
  static Future<void> onBackgroundMessage(RemoteMessage message) async {
    print('Background message: ${message.notification?.title}');
  }
}