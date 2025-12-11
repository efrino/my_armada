import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utils/permission_manager.dart';
import '../utils/permissions.dart';

import '../pages/home.dart';
import '../pages/profile.dart';
// import '../pages/history_scan.dart';
// import '../pages/history_sto.dart';
import '../pages/scan_in.dart';
import '../pages/scan_out.dart';
import '../pages/scan_sto.dart';
import '../pages/admin/user_management.dart';
//import '../pages/wss_adm.dart;'

class MainLayout extends StatefulWidget {
  final int initialIndex;

  const MainLayout({super.key, this.initialIndex = 0});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  late int _selectedIndex;

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  /// Definisi menu dengan permission requirement
  /// permission: null = selalu tampil (public menu)
  /// permission: string = butuh permission tersebut
  /// permissions: List<String> = butuh salah satu dari permission tersebut
  List<MenuItemConfig> get _allMenuItems => [
    MenuItemConfig(
      id: 'home',
      title: 'Beranda',
      icon: Icons.home,
      permission: null, // Public - selalu tampil
      enabled: true,
    ),
    MenuItemConfig(
      id: 'profile',
      title: 'Profil Operator',
      icon: Icons.person,
      permission: null, // Public - selalu tampil
      enabled: true,
    ),
    MenuItemConfig(
      id: 'scan_in',
      title: 'Scan In',
      icon: Icons.qr_code_2,
      permission: AppPermissions.viewScanIn,
      enabled: true,
      requireLogin: true,
    ),
    MenuItemConfig(
      id: 'scan_out',
      title: 'Scan Out',
      icon: Icons.qr_code_scanner_rounded,
      permission: AppPermissions.viewScanOut,
      enabled: true,
      requireLogin: true,
    ),
    MenuItemConfig(
      id: 'scan_sto',
      title: 'Scan STO',
      icon: Icons.receipt_long_rounded,
      permission: AppPermissions.viewScanSto,
      enabled: true,
      requireLogin: true,
    ),
    MenuItemConfig(
      id: 'history_scan',
      title: 'History Scan',
      icon: Icons.history,
      permission: AppPermissions.viewHistoryScan,
      enabled: false, // Fitur belum tersedia
      requireLogin: true,
    ),
    MenuItemConfig(
      id: 'history_sto',
      title: 'History STO',
      icon: Icons.warehouse,
      permission: AppPermissions.viewHistorySto,
      enabled: false, // Fitur belum tersedia
      requireLogin: true,
    ),
    // Admin menu - hanya tampil untuk admin
    MenuItemConfig(
      id: 'user_management',
      title: 'Kelola User',
      icon: Icons.admin_panel_settings,
      permission: AppPermissions.manageUsers,
      enabled: true,
      requireLogin: true,
      adminOnly: true,
    ),
    //Menu WSS ADM
    MenuItemConfig(
      id: 'wss_adm',
      title: 'Scan In IFP WSS',
      icon: Icons.safety_check,
      permission: AppPermissions.viewScanIfpWss,
      enabled:true,
      requireLogin: true,
    ),
  ];

  /// Filter menu berdasarkan permission user
  List<MenuItemConfig> get _visibleMenuItems {
    return _allMenuItems.where((item) {
      // Public menu (no permission required)
      if (item.permission == null && item.permissions == null) {
        return true;
      }

      // User belum login - hide menu yang butuh login
      if (!permissionManager.isLoggedIn) {
        return !item.requireLogin;
      }

      // Admin bisa akses semua
      if (permissionManager.isAdmin) {
        return true;
      }

      // Admin-only menu - hide untuk non-admin
      if (item.adminOnly) {
        return false;
      }

      // Check single permission
      if (item.permission != null) {
        return permissionManager.hasPermission(item.permission!);
      }

      // Check multiple permissions (any)
      if (item.permissions != null) {
        return permissionManager.hasAnyPermission(item.permissions!);
      }

      return false;
    }).toList();
  }

  @override
  void initState() {
    super.initState();

    // Always start at Home (index 0)
    // Login page is shown separately when not logged in
    _selectedIndex = widget.initialIndex;

    // Listen to permission changes
    permissionManager.addListener(_onPermissionChanged);
  }

  @override
  void dispose() {
    permissionManager.removeListener(_onPermissionChanged);
    super.dispose();
  }

  void _onPermissionChanged() {
    // Refresh UI ketika user login/logout atau permission berubah
    if (mounted) {
      setState(() {
        // Jika current selected menu tidak lagi visible, reset ke home
        if (_selectedIndex >= _visibleMenuItems.length) {
          _selectedIndex = 0;
        }
      });
    }
  }

  Widget _getPage(String menuId) {
    switch (menuId) {
      case 'home':
        return HomePage(
          onTapMenu: _onMenuTapFromHome,
          visibleMenuItems: _visibleMenuItems,
        );
      case 'profile':
        return ProfilePage(
          onLoginSuccess: _handleLoginSuccess,
          onLogout: _handleLogout,
        );
      case 'scan_in':
        return ScanInPage(nik: permissionManager.userNik);
      case 'scan_out':
        return ScanOutPage(nik: permissionManager.userNik);
      case 'scan_sto':
        return ScanStoPage(nik: permissionManager.userNik);
      case 'history_scan':
        return const Center(child: Text('History Scan - Coming Soon'));
      case 'history_sto':
        return const Center(child: Text('History STO - Coming Soon'));
      case 'user_management':
        return const UserManagementPage();
      default:
        return const Center(child: Text('Page not found'));
    }
  }

  /// Handle tap menu dari HomePage
  void _onMenuTapFromHome(int index) {
    if (index < _visibleMenuItems.length) {
      _onItemTapped(index);
    }
  }

  void _handleLoginSuccess(String nik) {
    // Login sudah dihandle oleh PermissionManager
    // Navigate to Home after successful login
    setState(() {
      _selectedIndex = 0; // Go to Home
    });
  }

  void _handleLogout() {
    // Reset to home, login page will be shown automatically
    setState(() {
      _selectedIndex = 0;
    });
  }

  void _onItemTapped(int index) {
    final visibleItems = _visibleMenuItems;

    if (index >= visibleItems.length) return;

    final item = visibleItems[index];

    // Check if menu is enabled
    if (!item.enabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Fitur ini belum tersedia'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    // Check if login required but user not logged in
    if (item.requireLogin && !permissionManager.isLoggedIn) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Silakan login terlebih dahulu'),
          duration: const Duration(seconds: 2),
          action: SnackBarAction(
            label: 'Login',
            onPressed: () {
              // Navigate to profile/login page
              final profileIndex = visibleItems.indexWhere(
                (m) => m.id == 'profile',
              );
              if (profileIndex != -1) {
                setState(() {
                  _selectedIndex = profileIndex;
                });
              }
            },
          ),
        ),
      );
      return;
    }

    setState(() {
      _selectedIndex = index;
    });

    // Close drawer if open
    if (_scaffoldKey.currentState?.isDrawerOpen ?? false) {
      Navigator.pop(context);
    }
  }

  /// Handle back button press
  /// First press: Open drawer
  /// Second press (drawer open): Show exit confirmation
  Future<bool> _handleBackButton() async {
    final scaffoldState = _scaffoldKey.currentState;

    // If drawer is open, show exit confirmation
    if (scaffoldState?.isDrawerOpen ?? false) {
      final shouldExit = await _showExitDialog();
      if (shouldExit == true) {
        SystemNavigator.pop();
        return true;
      }
      return false;
    }

    // If drawer is closed, open it
    scaffoldState?.openDrawer();
    return false;
  }

  /// Show exit confirmation dialog
  Future<bool?> _showExitDialog() {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.exit_to_app, color: Colors.red),
            SizedBox(width: 8),
            Text(
              'Keluar Aplikasi',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.w500),
            ),
          ],
        ),
        content: const Text('Apakah Anda yakin ingin keluar dari aplikasi?'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Keluar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // If not logged in, show only login page (no drawer, no navigation)
    if (!permissionManager.isLoggedIn) {
      return _buildLoginOnlyScaffold();
    }

    final visibleItems = _visibleMenuItems;
    final currentItem =
        visibleItems.isNotEmpty && _selectedIndex < visibleItems.length
        ? visibleItems[_selectedIndex]
        : visibleItems.first;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (!didPop) {
          await _handleBackButton();
        }
      },
      child: Scaffold(
        key: _scaffoldKey,
        appBar: AppBar(
          title: Text(currentItem.title),
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
          elevation: 2,
          actions: [
            // Show admin badge if user is admin
            if (permissionManager.isAdmin)
              Container(
                margin: const EdgeInsets.only(right: 12),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.orange,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.shield, size: 14),
                    SizedBox(width: 4),
                    Text('Admin', style: TextStyle(fontSize: 12)),
                  ],
                ),
              ),
          ],
        ),
        drawer: _buildDrawer(visibleItems),
        body: _getPage(currentItem.id),
      ),
    );
  }

  /// Build scaffold for login-only mode (no drawer, no navigation)
  Widget _buildLoginOnlyScaffold() {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (!didPop) {
          // Show exit dialog directly when not logged in
          final shouldExit = await _showExitDialog();
          if (shouldExit == true) {
            SystemNavigator.pop();
          }
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Login'),
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
          elevation: 2,
          automaticallyImplyLeading: false, // No hamburger menu
        ),
        body: ProfilePage(
          onLoginSuccess: _handleLoginSuccess,
          onLogout: _handleLogout,
        ),
      ),
    );
  }

  Widget _buildDrawer(List<MenuItemConfig> visibleItems) {
    final user = permissionManager.currentUser;

    return Drawer(
      child: Column(
        children: [
          // Drawer Header
          UserAccountsDrawerHeader(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: permissionManager.isAdmin
                    ? [Colors.orange.shade700, Colors.orange.shade500]
                    : [Colors.blue.shade700, Colors.blue.shade500],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            currentAccountPicture: CircleAvatar(
              backgroundColor: Colors.white,
              child: Icon(
                user == null ? Icons.person_outline : Icons.person,
                size: 40,
                color: permissionManager.isAdmin ? Colors.orange : Colors.blue,
              ),
            ),
            accountName: Row(
              children: [
                Flexible(
                  child: Text(
                    user?.name ?? 'Guest',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (permissionManager.isAdmin) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'ADMIN',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            accountEmail: Text(
              user == null ? 'Belum login' : 'NIK: ${user.nik}',
            ),
            otherAccountsPictures: user?.department.isNotEmpty == true
                ? [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(
                          user!.department,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ]
                : null,
          ),

          // Menu Items
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.zero,
              itemCount: visibleItems.length,
              itemBuilder: (context, index) {
                final item = visibleItems[index];
                final isSelected = _selectedIndex == index;

                return ListTile(
                  leading: Icon(
                    item.icon,
                    color: item.enabled
                        ? (isSelected
                              ? (permissionManager.isAdmin
                                    ? Colors.orange
                                    : Colors.blue)
                              : Colors.grey[700])
                        : Colors.grey[400],
                  ),
                  title: Text(
                    item.title,
                    style: TextStyle(
                      color: item.enabled
                          ? (isSelected
                                ? (permissionManager.isAdmin
                                      ? Colors.orange
                                      : Colors.blue)
                                : Colors.grey[700])
                          : Colors.grey[400],
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                  selected: isSelected,
                  selectedTileColor: permissionManager.isAdmin
                      ? Colors.orange.withOpacity(0.1)
                      : Colors.blue.withOpacity(0.1),
                  enabled: item.enabled,
                  onTap: () => _onItemTapped(index),
                  trailing: _buildMenuTrailing(item),
                );
              },
            ),
          ),

          // Permission info for non-admin
          if (permissionManager.isLoggedIn && !permissionManager.isAdmin)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 16,
                    color: Colors.grey.shade600,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Menu terbatas sesuai permission',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Back button hint
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.red.shade100),
            ),
            child: Row(
              children: [
                Icon(Icons.exit_to_app, size: 14, color: Colors.red.shade400),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Tekan tombol back lagi untuk keluar',
                    style: TextStyle(fontSize: 10, color: Colors.red.shade600),
                  ),
                ),
              ],
            ),
          ),

          // Footer
          const Divider(),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Text(
                  'MAJSF Scanner App',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
                const SizedBox(height: 4),
                Text(
                  'Version 1.2.0',
                  style: TextStyle(color: Colors.grey[400], fontSize: 10),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget? _buildMenuTrailing(MenuItemConfig item) {
    if (!item.enabled) {
      return const Icon(Icons.lock_outline, size: 16, color: Colors.grey);
    }

    if (item.adminOnly) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.orange.withOpacity(0.2),
          borderRadius: BorderRadius.circular(4),
        ),
        child: const Text(
          'Admin',
          style: TextStyle(fontSize: 10, color: Colors.orange),
        ),
      );
    }

    if (item.requireLogin && !permissionManager.isLoggedIn) {
      return const Icon(Icons.login, size: 16, color: Colors.grey);
    }

    return null;
  }
}

/// Configuration class untuk menu item
class MenuItemConfig {
  final String id;
  final String title;
  final IconData icon;
  final String? permission; // Single permission requirement
  final List<String>? permissions; // Multiple permissions (any)
  final bool enabled;
  final bool requireLogin;
  final bool adminOnly;

  const MenuItemConfig({
    required this.id,
    required this.title,
    required this.icon,
    this.permission,
    this.permissions,
    this.enabled = true,
    this.requireLogin = false,
    this.adminOnly = false,
  });
}
