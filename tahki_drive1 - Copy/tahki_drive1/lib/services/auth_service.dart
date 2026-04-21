import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  static const String _keyUserId = 'user_id';
  static const String _keyDriverId = 'driver_id';  // ← AJOUTÉ
  static const String _keyToken = 'auth_token';

  // ============ NOUVELLES MÉTHODES POUR DRIVER ============

  // Sauvegarder driver_id après connexion
  static Future<void> setDriverId(int driverId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyDriverId, driverId);
  }

  // Récupérer driver_id
  static Future<int?> getDriverId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyDriverId);
  }

  // ============ ANCIENNES MÉTHODES (gardées pour compatibilité) ============

  // Sauvegarder user_id après connexion
  static Future<void> setUserId(int userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyUserId, userId);
    // Optionnel: sauvegarder aussi dans driver_id pour synchronisation
    await prefs.setInt(_keyDriverId, userId);
  }

  // Récupérer user_id
  static Future<int?> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyUserId);
  }

  // Sauvegarder token
  static Future<void> setAuthToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyToken, token);
  }

  // Récupérer token
  static Future<String?> getAuthToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyToken);
  }

  // Déconnexion
  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyUserId);
    await prefs.remove(_keyDriverId);  // ← AJOUTÉ
    await prefs.remove(_keyToken);
  }
}