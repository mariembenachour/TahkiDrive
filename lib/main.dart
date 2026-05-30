import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
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
import 'package:tahki_drive1/app_dimensions.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// ✅ CRITIQUE : doit être une fonction TOP-LEVEL (pas dans une classe)
// et doit être la PREMIÈRE chose enregistrée après Firebase.initializeApp()
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
    // ✅ CRITIQUE : enregistrer le handler BG IMMÉDIATEMENT après initializeApp
    // AVANT tout autre appel Firebase
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  }

  final prefs     = await SharedPreferences.getInstance();
  final savedLang = prefs.getString('app_language') ?? 'fr';

  Widget home;

  if (kIsWeb) {
    home = const AdminLoginPage();
  } else {
    final token      = await AuthService.getAuthToken();
    final setupToken = await AuthService.getSetupToken();
    final cin        = await AuthService.getCin();

    if (token != null && token.isNotEmpty) {
      if (cin != null && cin.isNotEmpty) {
        // ✅ CORRIGÉ : init() appelé ici, AVANT runApp — c'est correct
        // mais on catch les erreurs pour ne pas bloquer le démarrage
        try {
          await NotificationService.init(cin);
        } catch (e) {
          print('>>> [MAIN] Erreur init notifications: $e');
        }
      }
      home = const MainScreen();
    } else if (setupToken != null && setupToken.isNotEmpty &&
        cin != null && cin.isNotEmpty) {
      home = PendingPage(cin: cin, setupToken: setupToken);
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

    // ✅ AJOUT : forcer le foreground pour iOS (Android l'ignore, pas de risque)
    FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('>>> [TAP] onMessageOpenedApp: type=${message.data['type']}');
      _handleNotificationTap(message);
    });

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
                borderRadius: BorderRadius.circular(20.r)),
            title: Text(
              data['pattern'] ?? 'Alerte véhicule',
              style:  TextStyle(color: Colors.white, fontSize: 16.sp,
                  fontWeight: FontWeight.w700),
            ),
            content: Text(
              data['car_voice'] ?? '',
              style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 14.sp, height: 1.6),
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

  // ✅ APRÈS — tu wraps juste avec ScreenUtilInit
  @override
  Widget build(BuildContext context) {
    final themeService = context.watch<ThemeService>();

    return ScreenUtilInit(
      designSize: const Size(390, 844), // ← taille de référence iPhone 14
      minTextAdapt: true,
      builder: (context, child) {
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
      },
    );
  }}
