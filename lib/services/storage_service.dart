import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  static const String _keyToken = 'auth_token';
  static const String _keyRole = 'user_role';
  static const String _keyUsername = 'username';
  static const String _keyFullName = 'user_fullname';
  static const String _keyEmail = 'user_email';

  // Save auth info
  static Future<void> saveAuthData({
    required String token,
    required String role,
    required String username,
    String? fullName,
    String? email,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyToken, token);
    await prefs.setString(_keyRole, role);
    await prefs.setString(_keyUsername, username);
    if (fullName != null) await prefs.setString(_keyFullName, fullName);
    if (email != null) await prefs.setString(_keyEmail, email);
  }

  // Get token
  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyToken);
  }

  // Get role
  static Future<String?> getRole() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyRole);
  }

  // Get username
  static Future<String?> getUsername() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyUsername);
  }

  // Get Full Name
  static Future<String?> getFullName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyFullName);
  }

  // Clear session on logout
  static Future<void> clearAuth() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyToken);
    await prefs.remove(_keyRole);
    await prefs.remove(_keyUsername);
    await prefs.remove(_keyFullName);
    await prefs.remove(_keyEmail);
  }

  // Check if logged in
  static Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  // Cache trạng thái Face ID
  static Future<void> setFaceRegistered(String username, bool isRegistered) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('face_registered_$username', isRegistered);
  }

  // Lấy trạng thái Face ID đã lưu
  static Future<bool> isFaceRegistered(String username) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('face_registered_$username') ?? false;
  }
}
