import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';

class SharedPrefs {
  static const String _keyUser = 'current_user';
  static const String _keyNik = 'current_nik';
  static const String _keyDeviceId = 'device_id';

  static SharedPreferences? _prefs;

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // User
  static Future<bool> saveUser(UserModel user) async {
    await _prefs?.setString(_keyUser, json.encode(user.toJson()));
    await _prefs?.setString(_keyNik, user.nik);
    return true;
  }

  static UserModel? getUser() {
    final userJson = _prefs?.getString(_keyUser);
    if (userJson != null) {
      return UserModel.fromJson(json.decode(userJson));
    }
    return null;
  }

  static String? getNik() {
    return _prefs?.getString(_keyNik);
  }

  static Future<bool> clearUser() async {
    await _prefs?.remove(_keyUser);
    await _prefs?.remove(_keyNik);
    return true;
  }

  // Device ID
  static Future<bool> saveDeviceId(String deviceId) async {
    await _prefs?.setString(_keyDeviceId, deviceId);
    return true;
  }

  static String getDeviceId() {
    return _prefs?.getString(_keyDeviceId) ?? 'Unknown Device';
  }

  // Check if logged in
  static bool get isLoggedIn => getUser() != null;
}
