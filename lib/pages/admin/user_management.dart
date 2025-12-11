import 'package:flutter/material.dart';
import '../../services/auth.dart';
import '../../utils/permissions.dart';
import '../../utils/permission_manager.dart';
import '../../models/user_model.dart';

class UserManagementPage extends StatefulWidget {
  const UserManagementPage({super.key});

  @override
  State<UserManagementPage> createState() => _UserManagementPageState();
}

class _UserManagementPageState extends State<UserManagementPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Guard: Only admin can access
    if (!permissionManager.isAdmin) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock, size: 80, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'Akses Ditolak',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text('Halaman ini hanya untuk Administrator'),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Tab Bar
        Container(
          color: Colors.white,
          child: TabBar(
            controller: _tabController,
            labelColor: Colors.orange,
            unselectedLabelColor: Colors.grey,
            indicatorColor: Colors.orange,
            tabs: const [
              Tab(icon: Icon(Icons.person_add), text: 'Tambah User'),
              Tab(icon: Icon(Icons.edit), text: 'Edit Permission'),
            ],
          ),
        ),

        // Tab Content
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: const [_AddUserTab(), _EditPermissionTab()],
          ),
        ),
      ],
    );
  }
}

// ============ TAB 1: ADD USER ============
class _AddUserTab extends StatefulWidget {
  const _AddUserTab();

  @override
  State<_AddUserTab> createState() => _AddUserTabState();
}

class _AddUserTabState extends State<_AddUserTab> {
  final Set<String> _selectedPermissions = {};
  bool _isLoading = false;
  bool _isLoadingNikList = false;
  bool _isAdmin = false;

  List<EmployeeItem> _employeeList = [];
  EmployeeItem? _selectedEmployee;

  @override
  void initState() {
    super.initState();
    _loadNikList();
  }

  Future<void> _loadNikList() async {
    setState(() => _isLoadingNikList = true);

    final result = await AuthService.getNikList();

    setState(() => _isLoadingNikList = false);

    if (result.isSuccess && result.data != null) {
      setState(() {
        _employeeList = result.data!;
      });
    } else {
      _showSnackBar(
        result.errorMessage ?? 'Gagal memuat daftar NIK',
        isError: true,
      );
    }
  }

  Future<void> _handleAddUser() async {
    if (_selectedEmployee == null) {
      _showSnackBar('Pilih karyawan terlebih dahulu', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    final result = await AuthService.createUser(
      _selectedEmployee!.nik,
      permissions: _selectedPermissions.toList(),
      isAdmin: _isAdmin,
    );

    setState(() => _isLoading = false);

    if (result.isSuccess) {
      _showSnackBar('User ${_selectedEmployee!.nik} berhasil ditambahkan');
      setState(() {
        _selectedEmployee = null;
        _selectedPermissions.clear();
        _isAdmin = false;
      });
    } else {
      _showSnackBar(
        result.errorMessage ?? 'Gagal menambahkan user',
        isError: true,
      );
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  void _showEmployeePickerDialog() {
    showDialog(
      context: context,
      builder: (context) => EmployeePickerDialog(
        employeeList: _employeeList,
        title: 'Pilih Karyawan',
        onSelected: (employee) {
          setState(() {
            _selectedEmployee = employee;
          });
          Navigator.pop(context);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // NIK Selection
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Pilih Karyawan',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const Text(' *', style: TextStyle(color: Colors.red)),
                      const Spacer(),
                      if (_isLoadingNikList)
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      else
                        IconButton(
                          icon: const Icon(Icons.refresh, size: 20),
                          onPressed: _loadNikList,
                          tooltip: 'Refresh daftar',
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Employee Picker Button
                  if (_isLoadingNikList)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        children: [
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          SizedBox(width: 12),
                          Text('Memuat daftar karyawan...'),
                        ],
                      ),
                    )
                  else
                    InkWell(
                      onTap: _employeeList.isEmpty
                          ? null
                          : _showEmployeePickerDialog,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade400),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.badge,
                              color: _selectedEmployee != null
                                  ? Colors.blue
                                  : Colors.grey,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (_selectedEmployee != null) ...[
                                    Text(
                                      _selectedEmployee!.nik,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      _selectedEmployee!.name,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ] else
                                    Text(
                                      'Ketuk untuk memilih karyawan',
                                      style: TextStyle(
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            Icon(
                              Icons.arrow_drop_down,
                              color: Colors.grey.shade600,
                            ),
                          ],
                        ),
                      ),
                    ),

                  if (_employeeList.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        '${_employeeList.length} karyawan tersedia',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Admin Toggle
          Card(
            child: SwitchListTile(
              title: const Text(
                'Jadikan Admin',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                _isAdmin
                    ? 'User ini akan memiliki akses penuh ke semua fitur'
                    : 'User biasa dengan permission terbatas',
                style: TextStyle(
                  fontSize: 12,
                  color: _isAdmin ? Colors.orange : Colors.grey.shade600,
                ),
              ),
              value: _isAdmin,
              onChanged: (value) {
                setState(() {
                  _isAdmin = value;
                  if (value) {
                    // Clear permissions jika jadi admin
                    _selectedPermissions.clear();
                  }
                });
              },
              activeColor: Colors.orange,
              secondary: Icon(
                _isAdmin ? Icons.shield : Icons.person,
                color: _isAdmin ? Colors.orange : Colors.grey,
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Permission Selection (only if not admin)
          if (!_isAdmin)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Permission (Opsional)',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        TextButton(
                          onPressed: () {
                            setState(() {
                              if (_selectedPermissions.length ==
                                  AppPermissions.getAllPermissions().length) {
                                _selectedPermissions.clear();
                              } else {
                                _selectedPermissions.clear();
                                _selectedPermissions.addAll(
                                  AppPermissions.getAllPermissions().map(
                                    (p) => p.key,
                                  ),
                                );
                              }
                            });
                          },
                          child: Text(
                            _selectedPermissions.length ==
                                    AppPermissions.getAllPermissions().length
                                ? 'Hapus Semua'
                                : 'Pilih Semua',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _buildPermissionCheckboxes(),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 24),

          // Add Button
          SizedBox(
            height: 50,
            child: ElevatedButton.icon(
              onPressed: _isLoading || _selectedEmployee == null
                  ? null
                  : _handleAddUser,
              icon: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.person_add),
              label: Text(_isLoading ? 'Menambahkan...' : 'Tambah User'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionCheckboxes() {
    final groupedPermissions = AppPermissions.getPermissionsByCategory();

    return Column(
      children: groupedPermissions.entries.map((entry) {
        return ExpansionTile(
          title: Text(
            entry.key,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          initiallyExpanded: false,
          children: entry.value.map((permission) {
            return CheckboxListTile(
              title: Text(
                permission.label,
                style: const TextStyle(fontSize: 14),
              ),
              subtitle: Text(
                permission.description,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
              value: _selectedPermissions.contains(permission.key),
              onChanged: (value) {
                setState(() {
                  if (value == true) {
                    _selectedPermissions.add(permission.key);
                  } else {
                    _selectedPermissions.remove(permission.key);
                  }
                });
              },
              dense: true,
              controlAffinity: ListTileControlAffinity.leading,
            );
          }).toList(),
        );
      }).toList(),
    );
  }
}

// ============ TAB 2: EDIT PERMISSION ============
class _EditPermissionTab extends StatefulWidget {
  const _EditPermissionTab();

  @override
  State<_EditPermissionTab> createState() => _EditPermissionTabState();
}

class _EditPermissionTabState extends State<_EditPermissionTab> {
  UserModel? _loadedUser;
  final Set<String> _selectedPermissions = {};
  bool _isLoadingNikList = false;
  bool _isLoadingUser = false;
  bool _isSaving = false;
  bool _isDeleting = false;
  bool _isAdmin = false;

  List<EmployeeItem> _employeeList = [];
  EmployeeItem? _selectedEmployee;

  @override
  void initState() {
    super.initState();
    _loadNikList();
  }

  Future<void> _loadNikList() async {
    setState(() => _isLoadingNikList = true);

    final result = await AuthService.getNikList();

    setState(() => _isLoadingNikList = false);

    if (result.isSuccess && result.data != null) {
      setState(() {
        _employeeList = result.data!;
      });
    } else {
      _showSnackBar(
        result.errorMessage ?? 'Gagal memuat daftar NIK',
        isError: true,
      );
    }
  }

  Future<void> _handleLoadUser(String nik) async {
    setState(() {
      _isLoadingUser = true;
      _loadedUser = null;
    });

    final result = await AuthService.login(nik);

    setState(() => _isLoadingUser = false);

    if (result.isSuccess && result.data != null) {
      setState(() {
        _loadedUser = result.data;
        _isAdmin = result.data!.isAdmin;
        _selectedPermissions.clear();
        _selectedPermissions.addAll(result.data!.permissions);
      });
    } else {
      _showSnackBar(
        result.errorMessage ?? 'User tidak ditemukan di sistem handheld',
        isError: true,
      );
      setState(() {
        _selectedEmployee = null;
      });
    }
  }

  Future<void> _handleSaveUser() async {
    if (_loadedUser == null) return;

    setState(() => _isSaving = true);

    final result = await AuthService.updateUser(
      _loadedUser!.nik,
      permissions: _selectedPermissions.toList(),
      isAdmin: _isAdmin,
    );

    setState(() => _isSaving = false);

    if (result.isSuccess) {
      _showSnackBar('User berhasil diupdate');
      // Reload user to reflect changes
      await _handleLoadUser(_loadedUser!.nik);
    } else {
      _showSnackBar(result.errorMessage ?? 'Gagal update user', isError: true);
    }
  }

  Future<void> _handleDeleteUser() async {
    if (_loadedUser == null) return;

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning, color: Colors.red.shade700),
            const SizedBox(width: 8),
            const Text('Hapus User'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Apakah Anda yakin ingin menghapus user ini?'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.person, color: Colors.grey),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _loadedUser!.name,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'NIK: ${_loadedUser!.nik}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Aksi ini tidak dapat dibatalkan!',
              style: TextStyle(
                color: Colors.red.shade700,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isDeleting = true);

    final result = await AuthService.deleteUser(_loadedUser!.nik);

    setState(() => _isDeleting = false);

    if (result.isSuccess) {
      _showSnackBar('User ${_loadedUser!.nik} berhasil dihapus');
      setState(() {
        _loadedUser = null;
        _selectedEmployee = null;
        _selectedPermissions.clear();
        _isAdmin = false;
      });
    } else {
      _showSnackBar(
        result.errorMessage ?? 'Gagal menghapus user',
        isError: true,
      );
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  void _showEmployeePickerDialog() {
    showDialog(
      context: context,
      builder: (context) => EmployeePickerDialog(
        employeeList: _employeeList,
        title: 'Pilih User Handheld',
        onSelected: (employee) {
          setState(() {
            _selectedEmployee = employee;
            _loadedUser = null;
            _selectedPermissions.clear();
          });
          Navigator.pop(context);
          // Auto load user data
          _handleLoadUser(employee.nik);
        },
      ),
    );
  }

  void _clearSelection() {
    setState(() {
      _selectedEmployee = null;
      _loadedUser = null;
      _selectedPermissions.clear();
      _isAdmin = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // User Selection
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Pilih User Handheld',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const Text(' *', style: TextStyle(color: Colors.red)),
                      const Spacer(),
                      if (_isLoadingNikList)
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      else
                        IconButton(
                          icon: const Icon(Icons.refresh, size: 20),
                          onPressed: _loadNikList,
                          tooltip: 'Refresh daftar',
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Employee Picker Button
                  if (_isLoadingNikList)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        children: [
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          SizedBox(width: 12),
                          Text('Memuat daftar karyawan...'),
                        ],
                      ),
                    )
                  else
                    InkWell(
                      onTap: _employeeList.isEmpty
                          ? null
                          : _showEmployeePickerDialog,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: _loadedUser != null
                                ? Colors.green.shade400
                                : Colors.grey.shade400,
                          ),
                          borderRadius: BorderRadius.circular(8),
                          color: _loadedUser != null
                              ? Colors.green.shade50
                              : null,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _loadedUser != null
                                  ? Icons.check_circle
                                  : Icons.badge,
                              color: _loadedUser != null
                                  ? Colors.green
                                  : (_selectedEmployee != null
                                        ? Colors.blue
                                        : Colors.grey),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (_selectedEmployee != null) ...[
                                    Text(
                                      _selectedEmployee!.nik,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      _selectedEmployee!.name,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                    if (_loadedUser != null)
                                      Text(
                                        '✓ Data user dimuat',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.green.shade700,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                  ] else
                                    Text(
                                      'Ketuk untuk memilih user',
                                      style: TextStyle(
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            if (_selectedEmployee != null)
                              IconButton(
                                icon: const Icon(Icons.close, size: 20),
                                onPressed: _clearSelection,
                                tooltip: 'Hapus pilihan',
                              )
                            else
                              Icon(
                                Icons.arrow_drop_down,
                                color: Colors.grey.shade600,
                              ),
                          ],
                        ),
                      ),
                    ),

                  // Loading user indicator
                  if (_isLoadingUser)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Row(
                        children: [
                          const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Memuat data user...',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),

                  if (_employeeList.isNotEmpty && !_isLoadingUser)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        '${_employeeList.length} karyawan tersedia',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // User Info & Permissions
          if (_loadedUser != null) ...[
            const SizedBox(height: 16),

            // User Info Card
            Card(
              color: _isAdmin ? Colors.orange.shade50 : Colors.blue.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: _isAdmin
                              ? Colors.orange
                              : Colors.blue,
                          child: const Icon(Icons.person, color: Colors.white),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _loadedUser!.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text('NIK: ${_loadedUser!.nik}'),
                              Text('Dept: ${_loadedUser!.department}'),
                            ],
                          ),
                        ),
                        if (_isAdmin)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.orange,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              'ADMIN',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Admin Toggle
            Card(
              child: SwitchListTile(
                title: const Text(
                  'Status Admin',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  _isAdmin
                      ? 'User ini memiliki akses penuh ke semua fitur'
                      : 'User biasa dengan permission terbatas',
                  style: TextStyle(
                    fontSize: 12,
                    color: _isAdmin ? Colors.orange : Colors.grey.shade600,
                  ),
                ),
                value: _isAdmin,
                onChanged: (value) {
                  setState(() {
                    _isAdmin = value;
                  });
                },
                activeColor: Colors.orange,
                secondary: Icon(
                  _isAdmin ? Icons.shield : Icons.person,
                  color: _isAdmin ? Colors.orange : Colors.grey,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Permission Editor
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Permission',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '${_selectedPermissions.length} dipilih',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    if (_isAdmin)
                      Container(
                        margin: const EdgeInsets.only(top: 8),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.info,
                              size: 16,
                              color: Colors.orange.shade700,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Admin memiliki akses penuh. Permission di bawah tidak berlaku.',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.orange.shade700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 8),
                    _buildPermissionCheckboxes(),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Action Buttons
            Row(
              children: [
                // Delete Button
                Expanded(
                  child: SizedBox(
                    height: 50,
                    child: OutlinedButton.icon(
                      onPressed: _isDeleting || _isSaving
                          ? null
                          : _handleDeleteUser,
                      icon: _isDeleting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.red,
                                ),
                              ),
                            )
                          : const Icon(Icons.delete),
                      label: Text(_isDeleting ? 'Menghapus...' : 'Hapus User'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Save Button
                Expanded(
                  child: SizedBox(
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: _isSaving || _isDeleting
                          ? null
                          : _handleSaveUser,
                      icon: _isSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          : const Icon(Icons.save),
                      label: Text(_isSaving ? 'Menyimpan...' : 'Simpan'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPermissionCheckboxes() {
    final groupedPermissions = AppPermissions.getPermissionsByCategory();

    return Column(
      children: groupedPermissions.entries.map((entry) {
        // Check if all permissions in category are selected
        final allSelected = entry.value.every(
          (p) => _selectedPermissions.contains(p.key),
        );
        final someSelected = entry.value.any(
          (p) => _selectedPermissions.contains(p.key),
        );

        return ExpansionTile(
          title: Row(
            children: [
              Checkbox(
                value: allSelected ? true : (someSelected ? null : false),
                tristate: true,
                onChanged: (value) {
                  setState(() {
                    if (allSelected) {
                      // Unselect all in category
                      for (var p in entry.value) {
                        _selectedPermissions.remove(p.key);
                      }
                    } else {
                      // Select all in category
                      for (var p in entry.value) {
                        _selectedPermissions.add(p.key);
                      }
                    }
                  });
                },
              ),
              Text(
                entry.key,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ],
          ),
          initiallyExpanded: someSelected,
          children: entry.value.map((permission) {
            return CheckboxListTile(
              title: Text(
                permission.label,
                style: const TextStyle(fontSize: 14),
              ),
              subtitle: Text(
                permission.description,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
              value: _selectedPermissions.contains(permission.key),
              onChanged: (value) {
                setState(() {
                  if (value == true) {
                    _selectedPermissions.add(permission.key);
                  } else {
                    _selectedPermissions.remove(permission.key);
                  }
                });
              },
              dense: true,
              controlAffinity: ListTileControlAffinity.leading,
            );
          }).toList(),
        );
      }).toList(),
    );
  }
}

// =====================================================
// Employee Picker Dialog (Searchable List) - SHARED
// =====================================================
class EmployeePickerDialog extends StatefulWidget {
  final List<EmployeeItem> employeeList;
  final String title;
  final Function(EmployeeItem) onSelected;

  const EmployeePickerDialog({
    super.key,
    required this.employeeList,
    required this.onSelected,
    this.title = 'Pilih Karyawan',
  });

  @override
  State<EmployeePickerDialog> createState() => _EmployeePickerDialogState();
}

class _EmployeePickerDialogState extends State<EmployeePickerDialog> {
  final TextEditingController _searchController = TextEditingController();
  List<EmployeeItem> _filteredList = [];

  @override
  void initState() {
    super.initState();
    _filteredList = widget.employeeList;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterList(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredList = widget.employeeList;
      } else {
        _filteredList = widget.employeeList
            .where((emp) => emp.matchesQuery(query))
            .toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
          maxWidth: MediaQuery.of(context).size.width * 0.9,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Search Box
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Cari NIK atau Nama...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            _filterList('');
                          },
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  isDense: true,
                ),
                onChanged: _filterList,
                autofocus: true,
              ),
            ),

            const SizedBox(height: 8),

            // Result count
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _searchController.text.isEmpty
                      ? '${_filteredList.length} karyawan tersedia'
                      : 'Ditemukan ${_filteredList.length} hasil',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ),

            const Divider(height: 1),

            // List
            Flexible(
              child: _filteredList.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.search_off,
                            size: 48,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _searchController.text.isEmpty
                                ? 'Tidak ada karyawan tersedia'
                                : 'Tidak ada hasil untuk "${_searchController.text}"',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 14,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: _filteredList.length,
                      itemBuilder: (context, index) {
                        final employee = _filteredList[index];

                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.blue.shade100,
                            child: Text(
                              employee.name.isNotEmpty
                                  ? employee.name[0].toUpperCase()
                                  : '?',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.blue.shade700,
                              ),
                            ),
                          ),
                          title: Text(
                            employee.nik,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          subtitle: Text(
                            employee.name,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          trailing: const Icon(
                            Icons.chevron_right,
                            color: Colors.grey,
                          ),
                          onTap: () => widget.onSelected(employee),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
