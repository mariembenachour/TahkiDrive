import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tahki_drive1/pages/Admin/AdminLoginPage.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:tahki_drive1/pages/DashboardCar/Accueil.dart';
import 'package:tahki_drive1/pages/DashboardCar/DailyReportPage.dart';
import 'package:tahki_drive1/pages/DashboardCar/diagnostic_detail_page.dart';
import 'package:tahki_drive1/pages/Main_screen.dart';
import 'package:tahki_drive1/pages/Auth/LoginPage.dart';
import 'package:tahki_drive1/pages/Auth/PendingPage.dart';
import 'package:tahki_drive1/pages/Admin/AdminDashboardPage.dart';
import 'services/notification_service.dart';
import 'services/auth_service.dart';
import 'services/theme_service.dart';
import 'theme/app_theme.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// ✅ CORRIGÉ — doit être une fonction TOP-LEVEL (pas dans une classe)
// et doit appeler Firebase.initializeApp() avant tout
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print("🌙 [BG] Message reçu: type=${message.data['type']}");
  await NotificationService.onBackgroundMessage(message);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();

  if (!kIsWeb) {
    await Firebase.initializeApp();
    // ✅ Enregistrer le handler background AVANT runApp, APRÈS initializeApp
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  }

  final prefs    = await SharedPreferences.getInstance();
  final savedLang = prefs.getString('app_language') ?? 'fr';

  Widget home;

  if (kIsWeb) {
    home = const AdminLoginPage();
  } else {
    final token      = await AuthService.getAuthToken();
    final setupToken = await AuthService.getSetupToken();

    if (token != null && token.isNotEmpty) {
      final cin = await AuthService.getCin();
      if (cin != null && cin.isNotEmpty) {
        NotificationService.navigatorKey = navigatorKey;
        await NotificationService.init(cin);
      }
      home = const MainScreen();
    } else if (setupToken != null && setupToken.isNotEmpty) {
      home = const PendingPage();
    } else {
      home = const HomePage();
    }
  }

  runApp(
    EasyLocalization(
      supportedLocales: const [Locale('fr'), Locale('ar'), Locale('en')],
      path: 'translations',
      fallbackLocale: const Locale('fr'),
      startLocale: Locale(savedLang),
      child: ChangeNotifierProvider(
        create: (_) => ThemeService(),
        child: MyApp(home: home),
      ),
    ),
  );
}

class MyApp extends StatefulWidget {
  final Widget home;
  const MyApp({super.key, required this.home});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    _setupFcmTapHandlers();
  }

  void _setupFcmTapHandlers() {
    if (kIsWeb) return;

    // App ouverte depuis background via tap notif
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('>>> [TAP] onMessageOpenedApp: type=${message.data['type']}');
      _handleNotificationTap(message);
    });

    // App lancée depuis killed via tap notif
    FirebaseMessaging.instance.getInitialMessage().then((message) {
      if (message != null) {
        print('>>> [TAP] getInitialMessage: type=${message.data['type']}');
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _handleNotificationTap(message);
        });
      }
    });
  }

  void _handleNotificationTap(RemoteMessage message) async {
    final data = message.data;
    final type = data['type'];
    final cin  = data['driver_cin'] ?? await AuthService.getCin() ?? '';

    print('>>> [NAV] _handleNotificationTap type=$type cin=$cin');

    if (type == 'daily_report') {
      // ✅ Petit délai pour que le navigator soit prêt si l'app vient d'être lancée
      await Future.delayed(const Duration(milliseconds: 500));
      navigatorKey.currentState?.push(MaterialPageRoute(
        builder: (_) => DailyReportPage(cin: cin),
      ));
    } else if (type == 'panne') {
      final eventId = int.tryParse(data['event_id']?.toString() ?? '');
      if (eventId != null) {
        await Future.delayed(const Duration(milliseconds: 500));
        navigatorKey.currentState?.push(MaterialPageRoute(
          builder: (_) => DiagnosticDetailPage(
            eventId:   eventId,
            cin:       cin,
            quickData: data,
          ),
        ));
      }
    } else if (type == 'danger_pattern' || type == 'movement_alert') {
      await Future.delayed(const Duration(milliseconds: 500));
      final ctx = navigatorKey.currentContext;
      if (ctx != null) {
        showDialog(
          context: ctx,
          builder: (_) => AlertDialog(
            backgroundColor: const Color(0xFF1A0A2E),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20)),
            title: Text(
              data['pattern'] ?? 'Alerte véhicule',
              style: const TextStyle(color: Colors.white, fontSize: 16,
                  fontWeight: FontWeight.w700),
            ),
            content: Text(
              data['car_voice'] ?? '',
              style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 14, height: 1.6),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Compris',
                    style: TextStyle(color: Color(0xFFB450FF))),
              ),
            ],
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeService = context.watch<ThemeService>();

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'TahkiDrive App',
      navigatorKey: navigatorKey,
      locale: context.locale,
      supportedLocales: context.supportedLocales,
      localizationsDelegates: context.localizationDelegates,
      themeMode: themeService.mode,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      home: widget.home,
    );
  }
}
