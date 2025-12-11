import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
import '../services/auth.dart';
import 'logger.dart';

/// Singleton class untuk manage user session dan permission
class PermissionManager extends ChangeNotifier {
  static final PermissionManager _instance = PermissionManager._internal();
  factory PermissionManager() => _instance;
  PermissionManager._internal();

  UserModel? _currentUser;
  bool _isLoading = false;

  // Getters
  UserModel? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null;
  bool get isAdmin => _currentUser?.isAdmin ?? false;
  bool get isLoading => _isLoading;
  String get userName => _currentUser?.name ?? '';
  String get userNik => _currentUser?.nik ?? '';
  String get department => _currentUser?.department ?? '';
  List<String> get permissions => _currentUser?.permissions ?? [];

  /// Initialize - load saved user session
  Future<void> init() async {
    logger.info('🔑 [PERMISSION] Initializing PermissionManager');
    await _loadSavedSession();
  }

  /// Load saved session dari SharedPreferences
  Future<void> _loadSavedSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedUserJson = prefs.getString('current_user');

      if (savedUserJson != null) {
        final userData = jsonDecode(savedUserJson);
        _currentUser = UserModel.fromJson(userData);
        logger.info(
          '🔑 [PERMISSION] Loaded saved session: ${_currentUser?.name}',
        );
        notifyListeners();
      }
    } catch (e) {
      logger.warning('🔑 [PERMISSION] Failed to load saved session: $e');
    }
  }

  /// Save current session to SharedPreferences
  Future<void> _saveSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      if (_currentUser != null) {
        await prefs.setString(
          'current_user',
          jsonEncode(_currentUser!.toJson()),
        );
        // Backward compatibility dengan code lama
        await prefs.setString('logged_nik', _currentUser!.nik);
        await prefs.setString('user_name', _currentUser!.name);
        await prefs.setString('department', _currentUser!.department);
        logger.info('🔑 [PERMISSION] Session saved');
      }
    } catch (e) {
      logger.warning('🔑 [PERMISSION] Failed to save session: $e');
    }
  }

  /// Clear session
  Future<void> _clearSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('current_user');
      await prefs.remove('logged_nik');
      await prefs.remove('user_name');
      await prefs.remove('department');
      logger.info('🔑 [PERMISSION] Session cleared');
    } catch (e) {
      logger.warning('🔑 [PERMISSION] Failed to clear session: $e');
    }
  }

  /// Login dengan NIK
  Future<AuthResult<UserModel>> login(String nik) async {
    _isLoading = true;
    notifyListeners();

    try {
      final result = await AuthService.login(nik);

      if (result.isSuccess && result.data != null) {
        _currentUser = result.data;
        await _saveSession();
        logger.info('🔑 [PERMISSION] Login successful: ${_currentUser?.name}');
      }

      return result;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Logout
  Future<void> logout() async {
    _currentUser = null;
    await _clearSession();
    logger.info('🔑 [PERMISSION] Logged out');
    notifyListeners();
  }

  /// Refresh user data dari server
  Future<bool> refreshUser() async {
    if (_currentUser == null) return false;

    _isLoading = true;
    notifyListeners();

    try {
      final result = await AuthService.login(_currentUser!.nik);

      if (result.isSuccess && result.data != null) {
        _currentUser = result.data;
        await _saveSession();
        logger.info('🔑 [PERMISSION] User refreshed: ${_currentUser?.name}');
        return true;
      }

      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ============ PERMISSION CHECK METHODS ============

  /// Check single permission
  bool hasPermission(String permission) {
    if (_currentUser == null) return false;
    return _currentUser!.hasPermission(permission);
  }

  /// Check if user has ANY of the given permissions
  bool hasAnyPermission(List<String> permissionList) {
    if (_currentUser == null) return false;
    return _currentUser!.hasAnyPermission(permissionList);
  }

  /// Check if user has ALL of the given permissions
  bool hasAllPermissions(List<String> permissionList) {
    if (_currentUser == null) return false;
    return _currentUser!.hasAllPermissions(permissionList);
  }

  /// Check menu access - untuk sidebar
  /// Returns true jika user bisa melihat menu tersebut
  bool canAccessMenu(String menuPermission) {
    // Guest tidak bisa akses menu yang butuh permission
    if (_currentUser == null) return false;

    // Admin bypass semua
    if (_currentUser!.isAdmin) return true;

    // Check permission
    return _currentUser!.permissions.contains(menuPermission);
  }

  /// Check area access - untuk fitur dalam halaman
  bool canAccessArea(String areaPermission) {
    if (_currentUser == null) return false;
    if (_currentUser!.isAdmin) return true;
    return _currentUser!.permissions.contains(areaPermission);
  }

  /// Check input access - untuk tombol/aksi input
  bool canInput(String inputPermission) {
    if (_currentUser == null) return false;
    if (_currentUser!.isAdmin) return true;
    return _currentUser!.permissions.contains(inputPermission);
  }
}

/// Global instance untuk akses mudah
final permissionManager = PermissionManager();
