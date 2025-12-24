class AppPermissions {
  // ============ SCAN IN PERMISSIONS ============
  // View permissions
  static const String viewScanIn = 'view.scanIn';
  static const String viewScanInIfpd = 'view.scanInIfpd';
  static const String viewScanInIfpp = 'view.scanInIfpp';
  static const String viewScanInIfrm = 'view.scanInIfrm';

  // Input permissions
  static const String inputScanIn = 'input.scanIn';
  static const String inputScanInIfpd = 'input.scanInIfpd';
  static const String inputScanInIfpp = 'input.scanInIfpp';
  static const String inputScanInIfrm = 'input.scanInIfrm';

  // ============ SCAN OUT PERMISSIONS ============
  // View permissions
  static const String viewScanOut = 'view.scanOut';
  static const String viewScanOutIfpd = 'view.scanOutIfpd';
  static const String viewScanOutIfpp = 'view.scanOutIfpp';
  static const String viewScanOutIfrm = 'view.scanOutIfrm';

  // Input permissions
  static const String inputScanOut = 'input.scanOut';
  static const String inputScanOutIfpd = 'input.scanOutIfpd';
  static const String inputScanOutIfpp = 'input.scanOutIfpp';
  static const String inputScanOutIfrm = 'input.scanOutIfrm';

  // ============ SCAN IFP WSS PERMISSIONS ============
  // View permissions
  static const String viewScanIfpWss = 'view.scanIfpWss';
  static const String viewHistoryIfpWss = 'view.historyIfpWss';

  // Input permissions
  static const String inputScanIfpWss = 'input.scanIfpWss';

  // ============ SCAN STO PERMISSIONS ============
  // View permissions
  static const String viewScanSto = 'view.scanSto';

  // Input permissions
  static const String inputScanSto = 'input.scanSto';

  // ============ HISTORY PERMISSIONS ============
  static const String viewHistoryScan = 'view.historyScan';
  static const String viewHistorySto = 'view.historySto';
  static const String exportHistoryScan = 'export.historyScan';
  static const String exportHistorySto = 'export.historySto';

  // // ============ ADMIN PERMISSIONS ============
  static const String manageUsers = 'admin.manageUsers';
  static const String managePermissions = 'admin.managePermissions';

  /// Daftar semua permission yang tersedia (untuk UI checkbox admin)
  static List<PermissionItem> getAllPermissions() {
    return [
      // Scan In
      PermissionItem(
        key: viewScanIn,
        label: 'Lihat Menu Scan In',
        category: 'Scan In',
        description: 'Akses ke menu Scan In',
      ),
      PermissionItem(
        key: viewScanInIfpd,
        label: 'Lihat Scan In IFPD',
        category: 'Scan In',
        description: 'Akses scan in area IFPD',
      ),
      PermissionItem(
        key: viewScanInIfpp,
        label: 'Lihat Scan In IFPP',
        category: 'Scan In',
        description: 'Akses scan in area IFPP',
      ),
      PermissionItem(
        key: viewScanInIfrm,
        label: 'Lihat Scan In IFRM',
        category: 'Scan In',
        description: 'Akses scan in area IFRM',
      ),
      PermissionItem(
        key: inputScanInIfpd,
        label: 'Input Scan In IFPD',
        category: 'Scan In',
        description: 'Bisa melakukan scan in di area IFPD',
      ),
      PermissionItem(
        key: inputScanInIfpp,
        label: 'Input Scan In IFPP',
        category: 'Scan In',
        description: 'Bisa melakukan scan in di area IFPP',
      ),
      PermissionItem(
        key: inputScanInIfrm,
        label: 'Input Scan In IFRM',
        category: 'Scan In',
        description: 'Bisa melakukan scan in di area IFRM',
      ),

      // Scan Out
      PermissionItem(
        key: viewScanOut,
        label: 'Lihat Menu Scan Out',
        category: 'Scan Out',
        description: 'Akses ke menu Scan Out',
      ),
      PermissionItem(
        key: viewScanOutIfpd,
        label: 'Lihat Scan Out IFPD',
        category: 'Scan Out',
        description: 'Akses scan out area IFPD',
      ),
      PermissionItem(
        key: viewScanOutIfpp,
        label: 'Lihat Scan Out IFPP',
        category: 'Scan Out',
        description: 'Akses scan out area IFPP',
      ),
      PermissionItem(
        key: viewScanOutIfrm,
        label: 'Lihat Scan Out IFRM',
        category: 'Scan Out',
        description: 'Akses scan out area IFRM',
      ),
      PermissionItem(
        key: inputScanOutIfpd,
        label: 'Input Scan Out IFPD',
        category: 'Scan Out',
        description: 'Bisa melakukan scan out di area IFPD',
      ),
      PermissionItem(
        key: inputScanOutIfpp,
        label: 'Input Scan Out IFPP',
        category: 'Scan Out',
        description: 'Bisa melakukan scan out di area IFPP',
      ),
      PermissionItem(
        key: inputScanOutIfrm,
        label: 'Input Scan Out IFRM',
        category: 'Scan Out',
        description: 'Bisa melakukan scan out di area IFRM',
      ),

      PermissionItem(
        key: viewScanIfpWss,
        label: 'Lihat Scan IFP WSS',
        category: 'Scan IFP WSS',
        description: 'Akses Menu Scan IFP WSS',
      ),
      PermissionItem(
        key: inputScanIfpWss,
        label: 'Input Scan IFP WSS',
        category: 'Scan IFP WSS',
        description: 'Bisa kirim data Scan IFP WSS',
      ),

      // Scan STO (update)
      PermissionItem(
        key: viewScanSto,
        label: 'Lihat Scan STO',
        category: 'Scan STO',
        description: 'Akses menu Scan STO',
      ),
      PermissionItem(
        key: inputScanSto,
        label: 'Input Scan STO',
        category: 'Scan STO',
        description: 'Dapat input qty pada Scan STO',
      ),

      // History
      PermissionItem(
        key: viewHistoryScan,
        label: 'Lihat History Scan',
        category: 'History',
        description: 'Akses ke menu History Scan',
      ),
      PermissionItem(
        key: viewHistorySto,
        label: 'Lihat History STO',
        category: 'History',
        description: 'Akses ke menu History STO',
      ),
      PermissionItem(
        key: exportHistoryScan,
        label: 'Export History Scan',
        category: 'History',
        description: 'Bisa export data history scan',
      ),
      PermissionItem(
        key: exportHistorySto,
        label: 'Export History STO',
        category: 'History',
        description: 'Bisa export data history STO',
      ),
      // History IFP WSS (TAMBAHAN BARU)
      PermissionItem(
        key: viewHistoryIfpWss,
        label: 'Lihat History IFP WSS',
        category: 'History IFP WSS',
        description: 'Akses ke menu History IFP WSS',
      ),
    ];
  }

  /// Grouping permissions by category
  static Map<String, List<PermissionItem>> getPermissionsByCategory() {
    final allPermissions = getAllPermissions();
    final Map<String, List<PermissionItem>> grouped = {};

    for (var permission in allPermissions) {
      if (!grouped.containsKey(permission.category)) {
        grouped[permission.category] = [];
      }
      grouped[permission.category]!.add(permission);
    }

    return grouped;
  }
}

/// Model untuk item permission (digunakan di UI)
class PermissionItem {
  final String key;
  final String label;
  final String category;
  final String description;

  const PermissionItem({
    required this.key,
    required this.label,
    required this.category,
    required this.description,
  });
}
