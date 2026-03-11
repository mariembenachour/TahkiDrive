import 'package:flutter/material.dart';
import 'package:tahki_drive1/pages/DashboardCar/Accueil.dart';
import 'package:tahki_drive1/pages/Main_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// 1️⃣ Initialiser le plugin de notifications locales
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
FlutterLocalNotificationsPlugin();

// 2️⃣ Canal de notification Android
const AndroidNotificationChannel channel = AndroidNotificationChannel(
  'alerts', // ID du canal
  'Alerts', // Nom du canal
  description: 'Channel for important alerts',
  importance: Importance.high,
);

// 3️⃣ Fonction pour gérer les messages en arrière-plan
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print("Message en arrière-plan reçu: ${message.messageId}");

  // Afficher notification locale même en background
  RemoteNotification? notification = message.notification;
  AndroidNotification? android = message.notification?.android;
  if (notification != null && android != null) {
    flutterLocalNotificationsPlugin.show(
      id: notification.hashCode,      // ✅ id obligatoire maintenant
      title: notification.title,
      body: notification.body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          channel.id,
          channel.name,
          channelDescription: channel.description,
          icon: '@mipmap/ic_launcher',
        ),
      ),
    );
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 4️⃣ Initialisation Firebase
  await Firebase.initializeApp();

  // 5️⃣ Créer le canal de notification Android
  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
      AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  // 6️⃣ Gestion des messages en arrière-plan
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // 7️⃣ Demande de permission pour notifications
  await _requestNotificationPermission();

  // 8️⃣ Récupération du token FCM
  await _getToken();

  // 9️⃣ Gestion des messages en foreground
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    print('Message reçu en foreground: ${message.notification?.title}');
    RemoteNotification? notification = message.notification;
    AndroidNotification? android = message.notification?.android;

    if (notification != null && android != null) {
      flutterLocalNotificationsPlugin.show(
        id: notification.hashCode,      // ✅ id obligatoire maintenant
        title: notification.title,
        body: notification.body,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            channel.id,
            channel.name,
            channelDescription: channel.description,
            icon: '@mipmap/ic_launcher',
          ),
        ),
      );
    }
  });

  runApp(const MyApp());
}

// Fonction pour demander la permission de notifications
Future<void> _requestNotificationPermission() async {
  FirebaseMessaging messaging = FirebaseMessaging.instance;
  NotificationSettings settings = await messaging.requestPermission(
    alert: true,
    badge: true,
    sound: true,
  );

  if (settings.authorizationStatus == AuthorizationStatus.authorized) {
    print('Notifications autorisées');
  } else {
    print('Notifications non autorisées');
  }
}

// Fonction pour récupérer le token FCM
Future<void> _getToken() async {
  String? token = await FirebaseMessaging.instance.getToken();
  print("FCM Token: $token"); // À utiliser pour envoyer une notification de test
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'TahkiDrive App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        fontFamily: 'Inter',
      ),
      home: const HomePage(), // Ta page d'accueil
    );
  }
}