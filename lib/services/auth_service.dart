import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
class AuthService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static const String _keyCin        = 'driver_cin';
  static const String _keyToken      = 'auth_token';
  static const String _keySetupToken = 'setup_token';
  static const String _base          = 'http://10.0.2.2:8000';
  static const String _keyHasCam     = 'has_cam';
  static const String _keyHasBoitier = 'has_boitier';

  // ─── FIREBASE ─────────────────────────────────────────────────────────────

  static Future<bool> isEmailVerified() async {
    User? user = _auth.currentUser;
    await user?.reload();
    return user?.emailVerified ?? false;
  }

  static Future<void> requireEmailVerified() async {
    User? user = _auth.currentUser;
    await user?.reload();
    if (user == null || user.emailVerified != true) {
      throw Exception("Veuillez vérifier votre email avant de continuer");
    }
  }

  // ─── SHARED PREFERENCES ───────────────────────────────────────────────────

  static Future<void> setCin(String cin) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyCin, cin);
  }

  static Future<String?> getCin() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyCin);
  }

  static Future<void> setAuthToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyToken, token);
  }

  static Future<String?> getAuthToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyToken);
  }

  static Future<void> setSetupToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    bool success = await prefs.setString(_keySetupToken, token);
    print("Token sauvegardé: $success");
  }

  static Future<String?> getSetupToken() async {
    final prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString(_keySetupToken);
    print("Token récupéré: ${token != null ? 'OUI' : 'NON'}");
    return token;
  }

  static Future<void> clearSetupToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keySetupToken);
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyCin);
    await prefs.remove(_keyToken);
    await prefs.remove(_keySetupToken);
    await prefs.remove(_keyHasCam);
    await prefs.remove(_keyHasBoitier);
  }

  static Future<Map<String, String>> authHeaders() async {
    final token = await getAuthToken() ?? await getSetupToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // ─── LOGIN DRIVER ─────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> loginDriver({
    required String email,
    required String password,
  }) async {
    // ✅ AJOUT : récupérer le token FCM avant d'appeler le backend
    String? fcmToken;
    try {
      fcmToken = await FirebaseMessaging.instance.getToken();
      print('>>> [LOGIN] FCM token récupéré: ${fcmToken?.substring(0, 20)}...');
    } catch (e) {
      print('>>> [LOGIN] Impossible de récupérer FCM token: $e');
    }

    final res = await http.post(
      Uri.parse('$_base/auth/login/driver'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'password': password,
        if (fcmToken != null) 'fcm_token': fcmToken,  // ✅ AJOUT
      }),
    );

    // ... reste inchangé
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      if (data['access_token'] != null) {
        await setAuthToken(data['access_token']);
      }
      if (data['cin'] != null) {
        await setCin(data['cin']);
        await setDeviceMode(
          hasCam:     data['has_cam']     == true,
          hasBoitier: data['has_boitier'] == true,
        );
      }
      return data;
    }

    final err = jsonDecode(res.body);
    throw Exception(err['detail'] ?? 'Erreur de connexion');
  }

  // ─── SCAN REGISTER ────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> scanRegister({
    required String cin,
    required String deviceQrData,
    required String vendorQrData,
    required String email,
    required String password,
    String? camQrData,
  }) async {

    UserCredential? firebaseUser;
    try {
      firebaseUser = await _auth.createUserWithEmailAndPassword(
          email: email, password: password);
      await firebaseUser.user?.sendEmailVerification();
      print("✅ Compte Firebase créé et mail envoyé à $email");
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        throw Exception("Cet email est déjà utilisé. Veuillez vous connecter depuis la page login.");
      } else {
        throw Exception("Erreur Firebase: ${e.message}");
      }
    } catch (e) {
      throw Exception("Erreur Firebase inattendue: $e");
    }

    final res = await http.post(
      Uri.parse('$_base/auth/scan-register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'cin': cin,
        'device_qr_data': deviceQrData,
        'vendor_qr_data': vendorQrData,
        'email': email,
        'password': password,
        if (camQrData != null) 'cam_qr_data': camQrData,
      }),
    );

    final data = jsonDecode(res.body);

    // ── Supprimer Firebase si backend échoue ──
    if (res.statusCode != 200) {
      await firebaseUser?.user?.delete();
      print("🧹 Compte Firebase supprimé (erreur HTTP)");
      throw Exception(data['detail'] ?? 'Erreur inscription');
    }

    // ── Supprimer Firebase si véhicule déjà lié ──
    final status = data['status']?.toString() ?? '';
    if (status == 'already_linked' || status == 'error') {
      await firebaseUser?.user?.delete();
      print("🧹 Compte Firebase supprimé (status: $status)");
      throw Exception(data['message'] ?? 'Erreur inscription');
    }

    final setupToken = data['setup_token']?.toString() ?? '';
    if (setupToken.isEmpty) {
      await firebaseUser?.user?.delete();
      throw Exception('Token manquant');
    }

    await setCin(cin);
    await setSetupToken(setupToken);

    return data;
  }

  // ─── SETUP PROFILE ────────────────────────────────────────────────────────

  static Future<void> setupProfile({
    required String setupToken,
    required String cin,
    required String firstName,
    required String lastName,
    required String telephone,
    String language = 'fr',
  }) async {
    final res = await http.patch(
      Uri.parse('$_base/auth/setup-profile'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $setupToken',
      },
      body: jsonEncode({
        'first_name': firstName,
        'last_name':  lastName,
        'cin':        cin,
        'telephone':  telephone,
        'language':   language,
      }),
    );

    if (res.statusCode != 200) {
      final err = jsonDecode(res.body);
      throw Exception(err['detail'] ?? 'Erreur setup profile');
    }
  }

  // ─── CHECK ACTIVATION ─────────────────────────────────────────────────────

  static Future<bool> checkActivationStatus() async {
    final headers = await authHeaders();
    try {
      final res = await http.get(
        Uri.parse('$_base/auth/status'),
        headers: headers,
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        if (data['activated'] == true) {
          await setAuthToken(data['access_token']);
          if (data['cin'] != null) await setCin(data['cin']);
          await clearSetupToken();
          return true;
        }
      }
    } catch (_) {}
    return false;
  }

  // ─── LOGOUT ───────────────────────────────────────────────────────────────

  static Future<void> logout() async {
    try {
      await _auth.signOut();
    } catch (_) {}
    await clear();
  }

  static Future<bool> isLoggedIn() async {
    final token = await getAuthToken();
    return token != null && token.isNotEmpty;
  }

  // ─── DEVICE MODE ──────────────────────────────────────────────────────────

  static Future<void> setDeviceMode({required bool hasCam, required bool hasBoitier}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyHasCam,     hasCam);
    await prefs.setBool(_keyHasBoitier, hasBoitier);
  }

  static Future<bool> getHasCam() async {
    final prefs = await SharedPreferences.getInstance();
    // ✅ CHANGEMENT : false par défaut (plus true)
    // → sans login ou sans device, on n'affiche rien plutôt que tout
    return prefs.getBool(_keyHasCam) ?? false;
  }

  static Future<bool> getHasBoitier() async {
    final prefs = await SharedPreferences.getInstance();
    // ✅ CHANGEMENT : false par défaut (plus true)
    return prefs.getBool(_keyHasBoitier) ?? false;
  }
}
