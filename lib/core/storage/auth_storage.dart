// auth_storage.dart
import 'package:shared_preferences/shared_preferences.dart';

class AuthStorage {
  static const String _keyToken = 'auth_token';
  static const String _keyRefreshToken = 'refresh_token';
  static const String _keyRole = 'user_role';
  static const String _keyUserName = 'user_name';
  static const String _keyEmail = 'user_email';
  static const String _keyDeviceId = 'device_id';

  // حفظ بيانات المستخدم بعد تسجيل الدخول
  static Future<void> saveUserData({
    required String token,
    required String refreshToken,
    required String role,
    required String userName,
    required String email,
    required String deviceId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyToken, token);
    await prefs.setString(_keyRefreshToken, refreshToken);
    await prefs.setString(_keyRole, role);
    await prefs.setString(_keyUserName, userName);
    await prefs.setString(_keyEmail, email);
    await prefs.setString(_keyDeviceId, deviceId);
  }

  // الحصول على بيانات المستخدم المحفوظة
  static Future<Map<String, String>?> getUserData() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_keyToken);
    
    if (token == null || token.isEmpty) return null;

    return {
      'token': token,
      'refreshToken': prefs.getString(_keyRefreshToken) ?? '',
      'role': prefs.getString(_keyRole) ?? '',
      'userName': prefs.getString(_keyUserName) ?? '',
      'email': prefs.getString(_keyEmail) ?? '',
      'deviceId': prefs.getString(_keyDeviceId) ?? '',
    };
  }

  // الحصول على التوكن فقط
  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyToken);
  }

  static Future<String?> getRefreshToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyRefreshToken);
  }

  static Future<void> updateTokens(String token, String refreshToken) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyToken, token);
    await prefs.setString(_keyRefreshToken, refreshToken);
  }

  // مسح البيانات عند تسجيل الخروج
  static Future<void> clearUserData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyToken);
    await prefs.remove(_keyRefreshToken);
    await prefs.remove(_keyRole);
    await prefs.remove(_keyUserName);
    await prefs.remove(_keyEmail);
    await prefs.remove(_keyDeviceId);
  }

  // فحص هل المستخدم مسجل دخول أم لا
  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_keyToken);
    return token != null && token.isNotEmpty;
  }
}
