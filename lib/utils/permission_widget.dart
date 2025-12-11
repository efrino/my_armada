import 'package:flutter/material.dart';
import 'permission_manager.dart';

/// Widget yang hanya menampilkan child jika user memiliki permission
class PermissionGate extends StatelessWidget {
  final String? permission;
  final List<String>? anyPermissions;
  final List<String>? allPermissions;
  final Widget child;
  final Widget? fallback;
  final bool showLock;

  const PermissionGate({
    super.key,
    this.permission,
    this.anyPermissions,
    this.allPermissions,
    required this.child,
    this.fallback,
    this.showLock = false,
  }) : assert(
         permission != null || anyPermissions != null || allPermissions != null,
         'At least one permission check must be provided',
       );

  bool get _hasAccess {
    if (permission != null) {
      return permissionManager.hasPermission(permission!);
    }
    if (anyPermissions != null) {
      return permissionManager.hasAnyPermission(anyPermissions!);
    }
    if (allPermissions != null) {
      return permissionManager.hasAllPermissions(allPermissions!);
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    if (_hasAccess) {
      return child;
    }

    if (fallback != null) {
      return fallback!;
    }

    if (showLock) {
      return _buildLockedWidget();
    }

    return const SizedBox.shrink();
  }

  Widget _buildLockedWidget() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.lock_outline, color: Colors.grey.shade500),
          const SizedBox(width: 8),
          Text('Akses terbatas', style: TextStyle(color: Colors.grey.shade600)),
        ],
      ),
    );
  }
}

/// Widget untuk button dengan permission check
class PermissionButton extends StatelessWidget {
  final String? permission;
  final List<String>? anyPermissions;
  final VoidCallback? onPressed;
  final Widget child;
  final ButtonStyle? style;
  final bool showDisabled;

  const PermissionButton({
    super.key,
    this.permission,
    this.anyPermissions,
    required this.onPressed,
    required this.child,
    this.style,
    this.showDisabled = true,
  });

  bool get _hasAccess {
    if (permission != null) {
      return permissionManager.hasPermission(permission!);
    }
    if (anyPermissions != null) {
      return permissionManager.hasAnyPermission(anyPermissions!);
    }
    return permissionManager.isLoggedIn; // Default: harus login
  }

  @override
  Widget build(BuildContext context) {
    if (!showDisabled && !_hasAccess) {
      return const SizedBox.shrink();
    }

    return ElevatedButton(
      onPressed: _hasAccess ? onPressed : null,
      style: style,
      child: child,
    );
  }
}

/// Widget untuk area/section dengan permission check
/// Menampilkan locked state jika tidak punya akses
class PermissionArea extends StatelessWidget {
  final String permission;
  final String title;
  final Widget child;
  final String? lockedMessage;

  const PermissionArea({
    super.key,
    required this.permission,
    required this.title,
    required this.child,
    this.lockedMessage,
  });

  @override
  Widget build(BuildContext context) {
    final hasAccess = permissionManager.hasPermission(permission);

    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: hasAccess ? Colors.blue.shade50 : Colors.grey.shade100,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  hasAccess ? Icons.check_circle : Icons.lock,
                  size: 20,
                  color: hasAccess ? Colors.blue : Colors.grey,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: hasAccess ? Colors.blue.shade700 : Colors.grey,
                    ),
                  ),
                ),
                if (!hasAccess)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'Terkunci',
                      style: TextStyle(fontSize: 10),
                    ),
                  ),
              ],
            ),
          ),

          // Content
          if (hasAccess)
            Padding(padding: const EdgeInsets.all(12), child: child)
          else
            Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.lock_outline,
                      size: 48,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      lockedMessage ?? 'Anda tidak memiliki akses ke fitur ini',
                      style: TextStyle(color: Colors.grey.shade600),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Extension untuk BuildContext agar mudah check permission
extension PermissionContext on BuildContext {
  bool hasPermission(String permission) {
    return permissionManager.hasPermission(permission);
  }

  bool hasAnyPermission(List<String> permissions) {
    return permissionManager.hasAnyPermission(permissions);
  }

  bool get isAdmin => permissionManager.isAdmin;

  bool get isLoggedIn => permissionManager.isLoggedIn;
}
