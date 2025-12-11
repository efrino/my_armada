import 'dart:convert';

class UserModel {
  final String nik;
  final String name;
  final String gender;
  final String department;
  final String jobTitle;
  final bool isAdmin;
  final List<String> permissions;

  UserModel({
    required this.nik,
    required this.name,
    required this.gender,
    required this.department,
    required this.jobTitle,
    required this.isAdmin,
    required this.permissions,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    // Parse permission dari string JSON ke List<String>
    List<String> parsedPermissions = [];
    if (json['permission'] != null) {
      try {
        if (json['permission'] is String) {
          parsedPermissions = List<String>.from(jsonDecode(json['permission']));
        } else if (json['permission'] is List) {
          parsedPermissions = List<String>.from(json['permission']);
        }
      } catch (e) {
        parsedPermissions = [];
      }
    }

    return UserModel(
      nik: json['nik'] ?? '',
      name: json['name'] ?? '',
      gender: json['gender'] ?? '',
      department: json['department'] ?? '',
      jobTitle: json['job_title'] ?? '',
      isAdmin:
          json['is_admin'] == '1' ||
          json['is_admin'] == 1 ||
          json['is_admin'] == true,
      permissions: parsedPermissions,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'nik': nik,
      'name': name,
      'gender': gender,
      'department': department,
      'job_title': jobTitle,
      'is_admin': isAdmin ? '1' : '0',
      'permission': jsonEncode(permissions),
    };
  }

  /// Check apakah user memiliki permission tertentu
  /// Admin bypass semua permission
  bool hasPermission(String permission) {
    if (isAdmin) return true;
    return permissions.contains(permission);
  }

  /// Check apakah user memiliki salah satu dari beberapa permission
  bool hasAnyPermission(List<String> permissionList) {
    if (isAdmin) return true;
    return permissionList.any((p) => permissions.contains(p));
  }

  /// Check apakah user memiliki semua permission yang diberikan
  bool hasAllPermissions(List<String> permissionList) {
    if (isAdmin) return true;
    return permissionList.every((p) => permissions.contains(p));
  }

  @override
  String toString() {
    return 'UserModel(nik: $nik, name: $name, isAdmin: $isAdmin, permissions: $permissions)';
  }
}
