import 'dart:ui';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tahki_drive1/pages/DashboardCar/diagnostic_detail_page.dart';
import 'package:tahki_drive1/pages/DashboardCar/DailyReportPage.dart';
import 'package:tahki_drive1/main.dart' show navigatorKey;
import 'package:tahki_drive1/services/notification_mode_service.dart';
import 'dart:async';

class NotificationService {
  static const String baseUrl = 'http://10.0.2.2:8000';

  static const Set<int> criticalCodes = {
    1, 2, 9, 12, 14, 22, 30, 33, 36, 37, 39, 46, 50
  };

  static const Set<String> _diagFallbacks = {
    'Diagnostic en cours de génération par l\'IA...',
    'Analyse en cours',
    'En cours d\'évaluation',
    'Consultez votre mécanicien',
    'Consulter un mécanicien',
    'Analyse des données en cours',
    'Consultez un mécanicien qualifié',
    'Risque inconnu — consultez un professionnel',
    'Risque de dommages si non traité',
  };

  static final FlutterTts _tts = FlutterTts();
  static final FlutterLocalNotificationsPlugin _local =
  FlutterLocalNotificationsPlugin();
  static String? _currentCin;

  static String? _lastCombinedAlertKey;
  static DateTime? _lastCombinedAlertTime;

  static GlobalKey<NavigatorState>? navigatorKey;

  // =========================================
  // AUTH HEADERS
  // =========================================
  static Future<String> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token') ?? prefs.getString('token') ?? '';
  }

  static Future<Map<String, String>> _authHeaders() async {
    final token = await _getToken();
    print(
        '>>> [AUTH] token: ${token.isEmpty ? "VIDE!" : token.substring(0, token.length.clamp(0, 20))}...');
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  // =========================================
  // INIT
  // =========================================
  static Completer<void>? _ttsCompleter;
  static bool _ttsInitialized = false;

  static void _initTtsHandlers() {
    if (_ttsInitialized) return;
    _ttsInitialized = true;

    _tts.setCompletionHandler(() {
      print('>>> [TTS] ✅ completed');
      if (_ttsCompleter != null && !_ttsCompleter!.isCompleted) {
        _ttsCompleter!.complete();
      }
    });

    _tts.setCancelHandler(() {
      print('>>> [TTS] ❌ cancelled');
      if (_ttsCompleter != null && !_ttsCompleter!.isCompleted) {
        _ttsCompleter!.complete();
      }
    });

    _tts.setErrorHandler((msg) {
      print('>>> [TTS] ⚠️ error: $msg');
      if (_ttsCompleter != null && !_ttsCompleter!.isCompleted) {
        _ttsCompleter!.complete();
      }
    });
  }

  static Future<void> init(String cin) async {
    _currentCin = cin;

    await _tts.setLanguage("fr-FR");
    await _tts.setSpeechRate(0.45);
    await _tts.setPitch(1.0);
    await _tts.setVolume(1.0);

    _initTtsHandlers();

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: android);

    await _local.initialize(
      settings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        final payload = response.payload;
        print('>>> [NOTIF TAP] payload: $payload');
        if (payload != null && payload.isNotEmpty) {
          try {
            final data = jsonDecode(payload) as Map<String, dynamic>;
            _navigateFromData(data);
          } catch (e) {
            print('Erreur parse payload notif: $e');
          }
        }
      },
    );

    final AndroidFlutterLocalNotificationsPlugin? androidImpl =
    _local.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    await androidImpl?.createNotificationChannel(
      const AndroidNotificationChannel(
        'alerts_channel',
        'Alertes Véhicule',
        description: 'Notifications de sécurité et alertes véhicule',
        importance: Importance.high,
      ),
    );
    await androidImpl?.createNotificationChannel(
      const AndroidNotificationChannel(
        'reminders_channel',
        'Rappels',
        description: 'Rappels et échéances véhicule',
        importance: Importance.high,
      ),
    );
    // ✅ AJOUT — channel dédié rapport quotidien
    await androidImpl?.createNotificationChannel(
      const AndroidNotificationChannel(
        'daily_report_channel',
        'Rapport Quotidien',
        description: 'Rapport de conduite quotidien',
        importance: Importance.high,
      ),
    );

    final messaging = FirebaseMessaging.instance;
    await messaging.requestPermission(alert: true, badge: true, sound: true);

    final token = await messaging.getToken();
    if (token != null) await _sendTokenToBackend(token, cin);

    FirebaseMessaging.onMessage.listen(_showLocalNotification);
    messaging.onTokenRefresh.listen((t) => _sendTokenToBackend(t, cin));
  }

  // =========================================
  // NOTIFICATION PRINCIPALE
  // =========================================
  static Future<void> _showLocalNotification(RemoteMessage message) async {
    final data         = message.data;
    final notification = message.notification;

    final bool isCombinedAlert = data['type'] == 'danger_pattern';
    final bool isReminder      = data['type'] == 'reminder';
    final bool isMovementAlert = data['type'] == 'movement_alert';
    final bool isDailyReport   = data['type'] == 'daily_report';
    final String alertPattern  = data['pattern'] ?? '';

    final int? code       = int.tryParse(data['code']?.toString() ?? '');
    final bool isCritical = code != null && criticalCodes.contains(code);

    final modes = await NotificationModeService.getModes();
    final String modeKey = isReminder
        ? 'rappels'
        : isCritical || isCombinedAlert || isMovementAlert
        ? 'critique'
        : 'conduite';
    final String mode = modes[modeKey] ?? NotificationModeService.SON;

    final bool withSound     = mode == NotificationModeService.SON ||
        mode == NotificationModeService.SON_VIBRATION;
    final bool withVibration = mode == NotificationModeService.VIBRATION ||
        mode == NotificationModeService.SON_VIBRATION;
    final bool withTts       = withSound;

    print("🔔 type=${data['type']} code=$code isCritical=$isCritical mode=$mode");

    final String body = data['car_voice'] ??
        notification?.body ??
        (isMovementAlert
            ? "Mouvement suspect détecté sur votre véhicule !"
            : isDailyReport
            ? "Viens, j'ai des choses à te raconter sur notre journée..."
            : isReminder
            ? "Vous avez un rappel"
            : "Nouvelle alerte véhicule");

    String title;
    Color? notificationColor;

    if (isReminder) {
      title             = "🔔 ${notification?.title ?? 'Rappel'}";
      notificationColor = const Color(0xFF4CAF50);
    } else if (isDailyReport) {
      // ✅ CORRIGÉ — titre depuis le data backend si dispo
      title             = notification?.title ?? "🚗 Ton rapport du jour est prêt !";
      notificationColor = const Color(0xFF2196F3);
    } else if (isCombinedAlert) {
      title             = "⚠️ ALERTE COMBINÉE";
      notificationColor = const Color(0xFFFFA500);

      final String alertKey = "$alertPattern-${data['driver_cin'] ?? ''}";
      final DateTime now    = DateTime.now();
      if (_lastCombinedAlertKey == alertKey &&
          _lastCombinedAlertTime != null &&
          now.difference(_lastCombinedAlertTime!) < const Duration(seconds: 30)) {
        print("⏱️ Alerte combinée ignorée (trop récente)");
        return;
      }
      _lastCombinedAlertKey  = alertKey;
      _lastCombinedAlertTime = now;
    } else if (isMovementAlert) {
      title             = "🚨 Mouvement suspect !";
      notificationColor = const Color(0xFFFF5722);
    } else if (isCritical) {
      title             = "⚠️ ALERTE CRITIQUE";
      notificationColor = const Color(0xFFFF0000);
    } else {
      title             = notification?.title ?? "Alerte Véhicule";
      notificationColor = const Color(0xFF2979FF);
    }

    // ✅ CORRIGÉ — notifId unique pour daily_report
    final int notifId = isDailyReport
        ? 8888
        : isMovementAlert
        ? 9999
        : isCombinedAlert
        ? 0
        : (code ?? notification.hashCode.abs() % 100000);

    final String payloadJson = jsonEncode(data);

    // ✅ CORRIGÉ — channel dédié pour daily_report
    final String channelId = isDailyReport
        ? 'daily_report_channel'
        : isReminder
        ? 'reminders_channel'
        : 'alerts_channel';

    final String channelName = isDailyReport
        ? 'Rapport Quotidien'
        : isReminder
        ? 'Rappels'
        : 'Alertes Véhicule';

    await _local.show(
      notifId,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          channelName,
          channelDescription: isDailyReport
              ? 'Rapport de conduite quotidien'
              : isReminder
              ? 'Rappels et échéances'
              : 'Notifications de sécurité',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
          color: notificationColor,
          playSound: withSound,
          enableVibration: withVibration,
          silent: mode == NotificationModeService.SILENCIEUX,
        ),
      ),
      payload: payloadJson,
    );

    if (withTts && (isCritical || isCombinedAlert || isMovementAlert)) {
      await _tts.stop();
      await _tts.speak(body);
    }
  }

  // =========================================
  // NAVIGATION DEPUIS UNE NOTIF
  // =========================================
  static void handleNotificationTap(Map<String, dynamic> data) {
    print('>>> [TAP] handleNotificationTap: type=${data['type']}');
    _navigateFromData(data);
  }

  static void _navigateFromData(Map<String, dynamic> data) {
    Future.delayed(const Duration(milliseconds: 400), () {
      final context = navigatorKey?.currentContext;
      if (context == null) {
        print('⚠️ navigatorKey context null — navigation ignorée');
        return;
      }

      final type      = data['type'] ?? '';
      final driverCin = data['driver_cin']?.toString() ?? _currentCin ?? '';

      print('>>> [NAV] type=$type cin=$driverCin');

      if (type == 'panne') {
        final eventId = int.tryParse(data['event_id']?.toString() ?? '');
        if (eventId == null) {
          print('⚠️ event_id manquant dans payload: $data');
          return;
        }
        Navigator.of(context).push(
          PageRouteBuilder(
            pageBuilder: (_, animation, __) => DiagnosticDetailPage(
              eventId:   eventId,
              cin:       driverCin.isNotEmpty ? driverCin : (_currentCin ?? ''),
              quickData: data,
            ),
            transitionsBuilder: (_, animation, __, child) => SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(1.0, 0.0),
                end:   Offset.zero,
              ).animate(CurvedAnimation(
                parent: animation,
                curve:  Curves.easeOutCubic,
              )),
              child: child,
            ),
            transitionDuration: const Duration(milliseconds: 350),
          ),
        );
      } else if (type == 'daily_report') {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => DailyReportPage(cin: driverCin),
          ),
        );
      } else if (type == 'danger_pattern') {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            backgroundColor: const Color(0xFF1A0A2E),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20)),
            title: Text(
              data['pattern'] ?? 'Alerte combinée',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700),
            ),
            content: Text(
              data['car_voice'] ?? '',
              style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 14,
                  height: 1.6),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Compris',
                    style: TextStyle(color: Color(0xFFB450FF))),
              ),
            ],
          ),
        );
      }
    });
  }

  // =========================================
  // FETCH DIAGNOSTIC
  // =========================================
  static Future<Map<String, dynamic>?> fetchDiagnostic(
      int eventId, String cin) async {
    try {
      final headers = await _authHeaders();
      print('>>> [DIAG] fetchDiagnostic eventId=$eventId');

      for (int attempt = 0; attempt < 5; attempt++) {
        if (attempt > 0) {
          print('>>> [DIAG] Retry $attempt/4 — attente 3s...');
          await Future.delayed(const Duration(seconds: 3));
        }

        final response = await http.get(
          Uri.parse('$baseUrl/api/agent/diagnostics/$eventId'),
          headers: headers,
        );

        print('>>> [DIAG] attempt=$attempt status=${response.statusCode}');

        if (response.statusCode != 200) continue;
        final rawBody = response.body;
        if (rawBody.isEmpty) continue;

        final body = jsonDecode(rawBody);
        if (body is! Map<String, dynamic> || body.isEmpty) continue;

        final diag           = Map<String, dynamic>.from(body);
        final diagnosis      = diag['diagnosis']?.toString().trim()       ?? '';
        final cause          = diag['cause']?.toString().trim()           ?? '';
        final actionRequired = diag['action_required']?.toString().trim() ?? '';

        final realDiagnosis = diagnosis.isNotEmpty      && !_diagFallbacks.contains(diagnosis);
        final realCause     = cause.isNotEmpty          && !_diagFallbacks.contains(cause);
        final realAction    = actionRequired.isNotEmpty && !_diagFallbacks.contains(actionRequired);

        if (realDiagnosis && realCause && realAction) {
          final carVoice = diag['car_voice']?.toString().trim() ?? '';
          if (carVoice.isEmpty) {
            diag['car_voice'] = await _fetchCarVoice(eventId, headers);
          }
          print('>>> [DIAG] ✅ Diagnostic IA complet !');
          return diag;
        }
        print('>>> [DIAG] Diagnostic incomplet → retry');
      }

      print('>>> [DIAG] ⚠️ 5 tentatives épuisées');
      final lastResp = await http.get(
        Uri.parse('$baseUrl/api/agent/diagnostics/$eventId'),
        headers: headers,
      );
      if (lastResp.statusCode == 200) {
        final body = jsonDecode(lastResp.body);
        if (body is Map<String, dynamic> && body.isNotEmpty) {
          final diag     = Map<String, dynamic>.from(body);
          final carVoice = diag['car_voice']?.toString().trim() ?? '';
          if (carVoice.isEmpty) {
            diag['car_voice'] = await _fetchCarVoice(eventId, headers);
          }
          return diag;
        }
      }
      return null;
    } catch (e) {
      print('fetchDiagnostic error: $e');
      return null;
    }
  }

  static Future<String> _fetchCarVoice(
      int eventId, Map<String, String> headers) async {
    try {
      final r = await http.get(
        Uri.parse('$baseUrl/api/agent/car-voice/$eventId'),
        headers: headers,
      );
      if (r.statusCode == 200) {
        return jsonDecode(r.body)['car_voice'] ?? '';
      }
    } catch (_) {}
    return '';
  }

  // =========================================
  // DAILY REPORT
  // =========================================
  static Future<Map<String, dynamic>?> getDailyReport(String cin,
      {String? date}) async {
    try {
      String url = '$baseUrl/api/agent/daily-report?cin=$cin';
      if (date != null) url += '&date=$date';
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['report'];
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  static Future<bool> updateReportHour(String cin, int hour) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/api/agent/report-hour?cin=$cin&hour=$hour'),
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  static Future<List<dynamic>> fetchReportsHistory({int limit = 30}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token') ?? '';
      final response = await http.get(
        Uri.parse('$baseUrl/api/agent/daily-reports/history?limit=$limit'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['reports'] ?? [];
      }
      return [];
    } catch (e) {
      print("Erreur fetchReportsHistory: $e");
      return [];
    }
  }

  // =========================================
  // EVENTS — PANNES
  // =========================================
  static Future<List<dynamic>> fetchAllEvents(String cin) async {
    try {
      final headers = await _authHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/api/events/pannes?limit=50'),
        headers: headers,
      );
      print('>>> fetchAllEvents (pannes) status: ${response.statusCode}');
      if (response.statusCode == 200) {
        final decoded         = jsonDecode(response.body);
        final List<dynamic> events = decoded['events'] ?? decoded ?? [];
        return events.map((e) {
          final ev = Map<String, dynamic>.from(e);
          if (ev['date'] != null) ev['date'] = ev['date'].toString();
          ev['doc_type'] = null;
          return ev;
        }).toList();
      }
      print('>>> fetchAllEvents error: ${response.body}');
      return [];
    } catch (e) {
      print('Erreur fetchAllEvents: $e');
      return [];
    }
  }

  static Future<List<dynamic>> fetchAllPannes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token') ?? '';
      final response = await http.get(
        Uri.parse('$baseUrl/api/events/pannes'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['events'] ?? [];
      }
      return [];
    } catch (e) {
      print("Erreur fetchAllPannes: $e");
      return [];
    }
  }

  static Future<List<dynamic>> fetchTodayPannes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token') ?? '';
      final response = await http.get(
        Uri.parse('$baseUrl/api/events/pannes?today_only=true'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['events'] ?? [];
      }
      return [];
    } catch (e) {
      print("Erreur fetchTodayPannes: $e");
      return [];
    }
  }

  static Future<List<dynamic>> getLastPannes() async {
    try {
      final headers = await _authHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/api/vehicle/last-pannes'),
        headers: headers,
      );
      print(">>> getLastPannes status: ${response.statusCode}");
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['pannes'] ?? [];
      }
      return [];
    } catch (e) {
      print("Erreur getLastPannes: $e");
      return [];
    }
  }

  static Future<void> markEventAsNotified(int eventId, String cin) async {
    try {
      final headers = await _authHeaders();
      await http.post(
        Uri.parse('$baseUrl/api/events/$eventId/mark-notified'),
        headers: headers,
      );
    } catch (e) {
      print("Erreur mark event: $e");
    }
  }

  static Future<void> markAsRead(int eventId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token') ?? '';
      await http.post(
        Uri.parse('$baseUrl/api/events/$eventId/mark-notified'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
    } catch (e) {
      print("Erreur markAsRead: $e");
    }
  }

  // =========================================
  // AGENT IA
  // =========================================
  static Future<Map<String, dynamic>> sendChatMessage(
      String cin, String message, List<Map<String, String>> history) async {
    try {
      final headers = await _authHeaders();
      final response = await http.post(
        Uri.parse('$baseUrl/api/agent/chat'),
        headers: headers,
        body: jsonEncode({"message": message, "history": history}),
      );
      if (response.statusCode == 200) return jsonDecode(response.body);
      return {"reply": "Erreur de communication", "history": []};
    } catch (e) {
      return {"reply": "Erreur: $e", "history": []};
    }
  }

  static Future<Map<String, dynamic>> getCurrentScore(String cin) async {
    try {
      final headers  = await _authHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/api/agent/score'),
        headers: headers,
      );
      if (response.statusCode == 200) return jsonDecode(response.body);
      return {};
    } catch (e) {
      return {};
    }
  }

  static Future<List<dynamic>> getScoreHistory(String cin,
      {int weeks = 8}) async {
    try {
      final headers  = await _authHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/api/agent/score/history?weeks=$weeks'),
        headers: headers,
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body)['history'] ?? [];
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  static Future<Map<String, dynamic>> getVehicleStats(String cin,
      {int days = 30}) async {
    try {
      final headers  = await _authHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/api/agent/stats?days=$days'),
        headers: headers,
      );
      if (response.statusCode == 200) return jsonDecode(response.body);
      return {};
    } catch (e) {
      return {};
    }
  }

  static Future<List<dynamic>> getDiagnostics(String cin,
      {int limit = 20}) async {
    try {
      final headers  = await _authHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/api/agent/diagnostics?limit=$limit'),
        headers: headers,
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body)['diagnostics'] ?? [];
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  static Future<String> getCarVoice(int eventId) async {
    try {
      final headers  = await _authHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/api/agent/car-voice/$eventId'),
        headers: headers,
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body)['car_voice'] ??
            "La voiture n'a rien à dire...";
      }
      return "Impossible de générer la voix";
    } catch (e) {
      return "Erreur technique";
    }
  }

  static Future<Map<String, dynamic>> findNearbyGarages(
      double lat, double lon, {int? errorCode}) async {
    try {
      final headers = await _authHeaders();
      String url    = '$baseUrl/api/agent/garages?lat=$lat&lon=$lon';
      if (errorCode != null) url += '&code=$errorCode';
      final response = await http.get(Uri.parse(url), headers: headers);
      if (response.statusCode == 200) return jsonDecode(response.body);
      return {"garages": [], "ai_recommendation": null};
    } catch (e) {
      return {"garages": [], "ai_recommendation": null};
    }
  }

  // =========================================
  // REMINDERS
  // =========================================
  static Future<List<dynamic>> getReminders(String cin) async {
    try {
      final headers  = await _authHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/api/agent/reminders'),
        headers: headers,
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body)['reminders'] ?? [];
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  static Future<Map<String, dynamic>> createReminder(
      String cin, {
        required String title,
        required String description,
        required DateTime remindAt,
        String? vehiculeId,
        int? repeatDays,
      }) async {
    try {
      final headers  = await _authHeaders();
      final response = await http.post(
        Uri.parse('$baseUrl/api/agent/reminders'),
        headers: headers,
        body: jsonEncode({
          "title":       title,
          "description": description,
          "remind_at":   remindAt.toIso8601String(),
          "vehicule_id": vehiculeId,
          "repeat_days": repeatDays,
        }),
      );
      if (response.statusCode == 200) return jsonDecode(response.body);
      return {"success": false};
    } catch (e) {
      return {"success": false};
    }
  }

  static Future<bool> deleteReminder(int reminderId, String cin) async {
    try {
      final headers  = await _authHeaders();
      final response = await http.delete(
        Uri.parse('$baseUrl/api/agent/reminders/$reminderId'),
        headers: headers,
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // =========================================
  // THRESHOLDS
  // =========================================
  static Future<Map<String, dynamic>> getThresholds(String cin) async {
    try {
      final headers  = await _authHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/api/agent/thresholds'),
        headers: headers,
      );
      if (response.statusCode == 200) return jsonDecode(response.body);
      return {
        "max_speed_kmh":      120,
        "min_oil_pressure":   2.5,
        "min_battery_voltage":12.0,
        "max_engine_temp":    100,
        "idle_max_minutes":   30,
      };
    } catch (e) {
      return {};
    }
  }

  static Future<bool> updateThresholds(
      String cin, Map<String, dynamic> thresholds) async {
    try {
      final headers  = await _authHeaders();
      final response = await http.put(
        Uri.parse('$baseUrl/api/agent/thresholds'),
        headers: headers,
        body: jsonEncode(thresholds),
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // =========================================
  // UTILITAIRES VOIX
  // =========================================
  static bool isCriticalCode(int code) => criticalCodes.contains(code);

  static Future<void> speak(String text) async {
    if (_ttsCompleter != null && !_ttsCompleter!.isCompleted) {
      _ttsCompleter!.complete();
    }
    await _tts.stop();
    await Future.delayed(const Duration(milliseconds: 150));

    _ttsCompleter = Completer<void>();
    await _tts.speak(text);
    await _ttsCompleter!.future;
  }

  static Future<void> stopSpeaking() async {
    if (_ttsCompleter != null && !_ttsCompleter!.isCompleted) {
      _ttsCompleter!.complete();
    }
    _ttsCompleter = null;
    await _tts.stop();
  }

  // =========================================
  // TOKEN FCM
  // =========================================
  static Future<void> _sendTokenToBackend(String token, String cin) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/update-fcm-token'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"cin": cin, "fcm_token": token}),
      );
      print(response.statusCode == 200
          ? '✅ Token FCM envoyé pour $cin'
          : '❌ Erreur envoi token: ${response.statusCode}');
    } catch (e) {
      print("Erreur envoi token: $e");
    }
  }

  // =========================================
  // BACKGROUND — ✅ CORRIGÉ
  // =========================================
  @pragma('vm:entry-point')
  static Future<void> onBackgroundMessage(RemoteMessage message) async {
    final data             = message.data;
    final bool isDailyReport = data['type'] == 'daily_report';
    final bool isCombined    = data['type'] == 'danger_pattern';
    final int? code          = int.tryParse(data['code']?.toString() ?? '');
    final bool isCritical    = code != null && criticalCodes.contains(code);

    // ── Initialiser le plugin local (obligatoire dans un isolate background) ──
    const android  = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: android);
    final local    = FlutterLocalNotificationsPlugin();
    await local.initialize(settings);

    final androidImpl = local.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    // Créer les channels (idempotent, sans effet si déjà existants)
    await androidImpl?.createNotificationChannel(
      const AndroidNotificationChannel(
        'daily_report_channel',
        'Rapport Quotidien',
        description: 'Rapport de conduite quotidien',
        importance: Importance.high,
      ),
    );
    await androidImpl?.createNotificationChannel(
      const AndroidNotificationChannel(
        'alerts_channel',
        'Alertes Véhicule',
        importance: Importance.high,
      ),
    );

    // ── ✅ daily_report — afficher la notif locale ──
    if (isDailyReport) {
      final String body = message.notification?.body ??
          data['car_voice'] ??
          "Viens, j'ai des choses à te raconter sur notre journée...";

      final String title = message.notification?.title ??
          "🚗 Ton rapport du jour est prêt !";

      await local.show(
        8888,
        title,
        body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'daily_report_channel',
            'Rapport Quotidien',
            channelDescription: 'Rapport de conduite quotidien',
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
            color: Color(0xFF2196F3),
            playSound: true,
            enableVibration: true,
          ),
        ),
        payload: jsonEncode(data),
      );
      print('>>> [BG] ✅ Notif daily_report affichée');
      return;
    }

    // ── TTS pour critique / combiné (comportement existant) ──
    final modes    = await NotificationModeService.getModes();
    final String modeKey = isCritical || isCombined ? 'critique' : 'conduite';
    final bool withTts   = modes[modeKey] == NotificationModeService.SON ||
        modes[modeKey] == NotificationModeService.SON_VIBRATION;

    if (withTts && (isCritical || isCombined)) {
      final String text = data['car_voice'] ??
          message.notification?.body ??
          (isCombined
              ? "Alerte combinée dangereuse détectée"
              : "Alerte véhicule critique");
      final tts = FlutterTts();
      await tts.setLanguage("fr-FR");
      await tts.setSpeechRate(0.45);
      await tts.speak(text);
    }
  }
}
