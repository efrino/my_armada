import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/user_model.dart';
import '../utils/logger.dart';

class AuthService {
  static const String _baseUrl = 'http://192.168.10.67/majsf_rest_api/api';
  static const Duration _timeout = Duration(seconds: 30);

  /// Login / Get user data by NIK
  /// GET /auth/user_mobile?nik={nik}
  static Future<AuthResult<UserModel>> login(String nik) async {
    try {
      final uri = Uri.parse('$_baseUrl/auth/user_mobile?nik=$nik');
      
      logger.info('🔐 [AUTH] Attempting login for NIK: $nik');
      
      final response = await http.get(
        uri,
        headers: {'Content-Type': 'application/json'},
      ).timeout(_timeout);

      logger.info('🔐 [AUTH] Response status: ${response.statusCode}');
      logger.fine('🔐 [AUTH] Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        // Check jika response adalah error
        if (data is Map && data.containsKey('status') && data['status'] == false) {
          return AuthResult.error(data['message'] ?? 'User tidak ditemukan');
        }
        
        // Parse user data
        final user = UserModel.fromJson(data);
        logger.info('🔐 [AUTH] Login success: ${user.name} (Admin: ${user.isAdmin})');
        
        return AuthResult.success(user);
      } else if (response.statusCode == 404 || response.statusCode == 409) {
        final data = jsonDecode(response.body);
        return AuthResult.error(data['message'] ?? 'User dengan NIK $nik tidak ditemukan');
      } else {
        return AuthResult.error('Server error: ${response.statusCode}');
      }
    } on http.ClientException catch (e) {
      logger.severe('🔐 [AUTH] Network error: $e');
      return AuthResult.error('Tidak dapat terhubung ke server. Periksa koneksi jaringan.');
    } catch (e) {
      logger.severe('🔐 [AUTH] Login error: $e');
      return AuthResult.error('Terjadi kesalahan: $e');
    }
  }

  /// Get list of all employees (NIK + Name) for dropdown
  /// GET /auth/nik_list
  static Future<AuthResult<List<EmployeeItem>>> getNikList() async {
    try {
      final uri = Uri.parse('$_baseUrl/auth/nik_list');
      
      logger.info('🔐 [AUTH] Fetching NIK list');
      
      final response = await http.get(
        uri,
        headers: {'Content-Type': 'application/json'},
      ).timeout(_timeout);

      logger.info('🔐 [AUTH] NIK list response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        // Check jika response adalah error
        if (data is Map && data.containsKey('status') && data['status'] == false) {
          return AuthResult.error(data['message'] ?? 'Data tidak ditemukan');
        }
        
        // Parse list
        if (data is List) {
          final employees = data.map((e) => EmployeeItem.fromJson(e)).toList();
          logger.info('🔐 [AUTH] Loaded ${employees.length} employees');
          return AuthResult.success(employees);
        } else {
          return AuthResult.error('Format response tidak valid');
        }
      } else {
        return AuthResult.error('Server error: ${response.statusCode}');
      }
    } catch (e) {
      logger.severe('🔐 [AUTH] Get NIK list error: $e');
      return AuthResult.error('Terjadi kesalahan: $e');
    }
  }

  /// Create new user/operator
  /// POST /auth/user_mobile
  static Future<AuthResult<bool>> createUser(
    String nik, {
    List<String> permissions = const [],
    bool isAdmin = false,
  }) async {
    try {
      final uri = Uri.parse('$_baseUrl/auth/user_mobile');
      
      logger.info('🔐 [AUTH] Creating user: $nik (isAdmin: $isAdmin)');
      
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'nik': nik,
          'permission': jsonEncode(permissions),
          'is_admin': isAdmin ? true : false,
        }),
      ).timeout(_timeout);

      logger.info('🔐 [AUTH] Create user response: ${response.statusCode}');
      logger.fine('🔐 [AUTH] Response body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        if (data['status'] == true) {
          return AuthResult.success(true);
        } else {
          return AuthResult.error(data['message'] ?? 'Gagal menambahkan user');
        }
      } else if (response.statusCode == 409) {
        final data = jsonDecode(response.body);
        return AuthResult.error(data['message'] ?? 'User sudah terdaftar');
      } else {
        return AuthResult.error('Server error: ${response.statusCode}');
      }
    } catch (e) {
      logger.severe('🔐 [AUTH] Create user error: $e');
      return AuthResult.error('Terjadi kesalahan: $e');
    }
  }

  /// Update user permissions and admin status
  /// PUT /auth/user_mobile
  static Future<AuthResult<bool>> updateUser(
    String nik, {
    required List<String> permissions,
    required bool isAdmin,
  }) async {
    try {
      final uri = Uri.parse('$_baseUrl/auth/user_mobile');
      
      logger.info('🔐 [AUTH] Updating user: $nik (isAdmin: $isAdmin)');
      logger.fine('🔐 [AUTH] New permissions: $permissions');
      
      final response = await http.put(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'nik': nik,
          'permission': jsonEncode(permissions),
          'is_admin': isAdmin ? '1' : '0',
        }),
      ).timeout(_timeout);

      logger.info('🔐 [AUTH] Update user response: ${response.statusCode}');
      logger.fine('🔐 [AUTH] Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == true) {
          return AuthResult.success(true);
        } else {
          return AuthResult.error(data['message'] ?? 'Gagal update user');
        }
      } else if (response.statusCode == 409) {
        final data = jsonDecode(response.body);
        return AuthResult.error(data['message'] ?? 'User tidak ditemukan');
      } else {
        return AuthResult.error('Server error: ${response.statusCode}');
      }
    } catch (e) {
      logger.severe('🔐 [AUTH] Update user error: $e');
      return AuthResult.error('Terjadi kesalahan: $e');
    }
  }

  /// Delete user
  /// DELETE /auth/user_mobile
  static Future<AuthResult<bool>> deleteUser(String nik) async {
    try {
      final uri = Uri.parse('$_baseUrl/auth/user_mobile');
      
      logger.info('🔐 [AUTH] Deleting user: $nik');
      
      final request = http.Request('DELETE', uri);
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode({'nik': nik});
      
      final streamedResponse = await request.send().timeout(_timeout);
      final response = await http.Response.fromStream(streamedResponse);

      logger.info('🔐 [AUTH] Delete user response: ${response.statusCode}');
      logger.fine('🔐 [AUTH] Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == true) {
          return AuthResult.success(true);
        } else {
          return AuthResult.error(data['message'] ?? 'Gagal menghapus user');
        }
      } else if (response.statusCode == 409) {
        final data = jsonDecode(response.body);
        return AuthResult.error(data['message'] ?? 'User tidak ditemukan');
      } else {
        return AuthResult.error('Server error: ${response.statusCode}');
      }
    } catch (e) {
      logger.severe('🔐 [AUTH] Delete user error: $e');
      return AuthResult.error('Terjadi kesalahan: $e');
    }
  }

  /// Update user permissions only (backward compatibility)
  /// PUT /auth/user_mobile
  static Future<AuthResult<bool>> updatePermissions(
    String nik,
    List<String> permissions, {
    bool? isAdmin,
  }) async {
    // If isAdmin not specified, we need to get current status first
    if (isAdmin == null) {
      final userResult = await login(nik);
      if (userResult.isSuccess && userResult.data != null) {
        isAdmin = userResult.data!.isAdmin;
      } else {
        isAdmin = false;
      }
    }
    
    return updateUser(nik, permissions: permissions, isAdmin: isAdmin);
  }
}


/// Result wrapper untuk auth operations
class AuthResult<T> {
  final T? data;
  final String? errorMessage;
  final bool isSuccess;

  AuthResult._({this.data, this.errorMessage, required this.isSuccess});

  factory AuthResult.success(T data) {
    return AuthResult._(data: data, isSuccess: true);
  }

  factory AuthResult.error(String message) {
    return AuthResult._(errorMessage: message, isSuccess: false);
  }
}

/// Model untuk employee item (dropdown)
class EmployeeItem {
  final String nik;
  final String name;

  EmployeeItem({required this.nik, required this.name});

  factory EmployeeItem.fromJson(Map<String, dynamic> json) {
    return EmployeeItem(
      nik: json['nik']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
    );
  }

  /// Display text untuk dropdown
  String get displayText => '$nik - $name';

  /// Search matcher (case insensitive)
  bool matchesQuery(String query) {
    final lowerQuery = query.toLowerCase();
    return nik.toLowerCase().contains(lowerQuery) ||
        name.toLowerCase().contains(lowerQuery);
  }
}