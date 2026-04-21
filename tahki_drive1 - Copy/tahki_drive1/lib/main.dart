import 'package:flutter/material.dart';
import 'package:tahki_drive1/pages/DashboardCar/Accueil.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:tahki_drive1/pages/Main_screen.dart';
import 'services/notification_service.dart';
import 'services/auth_service.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  await NotificationService.onBackgroundMessage(message);  // ← Ajouter await
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  // CHANGE 1: driverId au lieu de userId
  int? driverId = await AuthService.getDriverId();  // ← Changer la méthode
  if (driverId == null) {
    driverId = 6;  // ID par défaut pour les tests
    await AuthService.setDriverId(driverId);  // ← Changer la méthode
    print('✅ ID driver temporaire sauvegardé: $driverId');
  } else {
    print('✅ ID driver récupéré: $driverId');
  }

  // CHANGE 2: Passer driverId au lieu de userId
  await NotificationService.init(driverId);

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  runApp(const MyApp());
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
      home: const MainScreen(),
    );
  }
}