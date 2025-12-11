import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../services/scan_out.dart';
import '../components/scan_out_detail.dart';
import '../components/scan_out_manual.dart';
import '../components/response_modal.dart';
import '../utils/permission_manager.dart';
import '../utils/permissions.dart';

class ScanOutPage extends StatefulWidget {
  final String nik;

  const ScanOutPage({super.key, required this.nik});

  @override
  State<ScanOutPage> createState() => _ScanOutPageState();
}

class _ScanOutPageState extends State<ScanOutPage> with WidgetsBindingObserver {
  String? selectedArea;
  Map<String, dynamic>? lastScannedTag;
  MobileScannerController? cameraController;
  bool isProcessing = false;
  bool isModalOpen = false;
  String? lastScannedCode;
  DateTime? lastScanTime;
  bool isCameraInitialized = false;

  /// Area options dengan permission requirements
  final List<AreaOption> allAreaOptions = [
    AreaOption(
      value: '',
      label: '--- Pilih Area ---',
      viewPermission: null,
      inputPermission: null,
      enabled: true,
    ),
    AreaOption(
      value: 'IFRM',
      label: 'IFRM',
      viewPermission: AppPermissions.viewScanOutIfrm,
      inputPermission: AppPermissions.inputScanOutIfrm,
      enabled: true,
    ),
    AreaOption(
      value: 'IFPP',
      label: 'IFPP',
      viewPermission: AppPermissions.viewScanOutIfpp,
      inputPermission: AppPermissions.inputScanOutIfpp,
      enabled: true,
    ),
    AreaOption(
      value: 'IFPD',
      label: 'IFPD',
      viewPermission: AppPermissions.viewScanOutIfpd,
      inputPermission: AppPermissions.inputScanOutIfpd,
      enabled: false, // Belum tersedia
      disabledReason: 'Belum tersedia',
    ),
  ];

  /// Filter area berdasarkan permission user
  List<AreaOption> get availableAreaOptions {
    return allAreaOptions.where((area) {
      // Placeholder "Pilih Area" selalu tampil
      if (area.value.isEmpty) return true;

      // Admin bisa lihat semua
      if (permissionManager.isAdmin) return true;

      // Check view permission
      if (area.viewPermission != null) {
        return permissionManager.hasPermission(area.viewPermission!);
      }

      return true;
    }).toList();
  }

  /// Check apakah user bisa input di area tertentu
  bool canInputInArea(String area) {
    if (area.isEmpty) return false;

    // Admin bisa input di semua area
    if (permissionManager.isAdmin) return true;

    // Find area config
    final areaConfig = allAreaOptions.firstWhere(
      (a) => a.value == area,
      orElse: () => allAreaOptions.first,
    );

    if (areaConfig.inputPermission == null) return false;

    return permissionManager.hasPermission(areaConfig.inputPermission!);
  }

  /// Get current area's input permission status
  bool get canInputCurrentArea => canInputInArea(selectedArea ?? '');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    selectedArea = '';

    // Listen to permission changes
    permissionManager.addListener(_onPermissionChanged);
  }

  void _onPermissionChanged() {
    if (mounted) {
      setState(() {
        // Reset selected area jika tidak lagi punya akses
        if (selectedArea != null && selectedArea!.isNotEmpty) {
          final stillHasAccess = availableAreaOptions.any(
            (a) => a.value == selectedArea,
          );
          if (!stillHasAccess) {
            selectedArea = '';
            _disposeCamera();
          }
        }
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    if (!mounted || cameraController == null) return;

    switch (state) {
      case AppLifecycleState.resumed:
        if (isCameraInitialized) {
          _startCamera();
        }
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        _stopCamera();
        break;
    }
  }

  void _startCamera() {
    if (cameraController == null || !mounted) return;

    try {
      cameraController!.start();
    } catch (e) {
      debugPrint('Error starting camera: $e');
    }
  }

  void _stopCamera() {
    if (cameraController == null || !mounted) return;

    try {
      cameraController!.stop();
    } catch (e) {
      debugPrint('Error stopping camera: $e');
    }
  }

  Future<void> _initializeCamera() async {
    if (cameraController != null) return;

    try {
      cameraController = MobileScannerController(
        detectionSpeed: DetectionSpeed.normal,
        facing: CameraFacing.back,
        torchEnabled: false,
      );

      _startCamera();

      if (mounted) {
        setState(() {
          isCameraInitialized = true;
        });
      }
    } catch (e) {
      debugPrint('Error initializing camera: $e');
      if (mounted) {
        _showError('Gagal menginisialisasi kamera');
      }
    }
  }

  void _disposeCamera() {
    if (cameraController != null) {
      try {
        _stopCamera();
        cameraController!.dispose();
        cameraController = null;
        isCameraInitialized = false;
      } catch (e) {
        debugPrint('Error disposing camera: $e');
      }
    }
  }

  void _onAreaChanged(String? value) {
    if (value == null) return;

    // Find area config
    final areaConfig = allAreaOptions.firstWhere(
      (a) => a.value == value,
      orElse: () => allAreaOptions.first,
    );

    // Prevent selecting disabled area
    if (!areaConfig.enabled) {
      _showError(
        'Area ${areaConfig.label} ${areaConfig.disabledReason ?? "tidak tersedia"}',
      );
      return;
    }

    // Check permission (extra safety)
    if (value.isNotEmpty && areaConfig.viewPermission != null) {
      if (!permissionManager.hasPermission(areaConfig.viewPermission!)) {
        _showError('Anda tidak memiliki akses ke area $value');
        return;
      }
    }

    setState(() {
      selectedArea = value;
      lastScannedTag = null;
      lastScannedCode = null;
      lastScanTime = null;
    });

    // Initialize camera only if not already initialized and area is valid
    if (value.isNotEmpty && !isCameraInitialized) {
      _initializeCamera();
    }
  }

  Future<void> _handleBarcodeScan(BarcodeCapture capture) async {
    if (isModalOpen || isProcessing || !isCameraInitialized) return;

    if (selectedArea == null || selectedArea!.isEmpty) return;

    if (widget.nik.isEmpty) {
      _showError('Anda belum login. Silakan login terlebih dahulu.');
      return;
    }

    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final String code = barcodes.first.rawValue ?? '';
    if (code.isEmpty) return;

    // Debounce: Ignore scan if same code scanned within 2 seconds
    final now = DateTime.now();
    if (lastScannedCode == code &&
        lastScanTime != null &&
        now.difference(lastScanTime!).inSeconds < 2) {
      return;
    }

    lastScannedCode = code;
    lastScanTime = now;

    if (!mounted) return;

    setState(() {
      isProcessing = true;
    });

    try {
      final tagData = await ScanOutService.getTagData(code, selectedArea!);

      if (!mounted) return;

      setState(() {
        isProcessing = false;
      });

      if (tagData != null) {
        setState(() {
          lastScannedTag = tagData;
        });

        await _showScanOutModal(tagData);
      } else {
        _showError('Tag tidak ditemukan');
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isProcessing = false;
      });
      _showError('Error: $e');
    }
  }

  Future<void> _showScanOutModal(Map<String, dynamic> tagData) async {
    if (!mounted) return;

    ScaffoldMessenger.of(context).clearSnackBars();

    setState(() {
      isModalOpen = true;
    });

    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => ScanOutModal(
        tagData: tagData,
        area: selectedArea!,
        nik: widget.nik,
        canInput: canInputCurrentArea, // Pass permission status
        onUpload: (result) async {
          await ResponseModal.show(
            context,
            success: result['success'] as bool,
            message: result['message'] as String,
            stockInfo: result['stockInfo'] as Map<String, dynamic>?,
            partNumber: result['partNumber'] as String?,
            onClose: () async {
              if (result['success'] == true) {
                await _refreshLastTagData();
              }
            },
          );
        },
      ),
    );

    if (!mounted) return;

    setState(() {
      isModalOpen = false;
    });
  }

  Future<void> _refreshLastTagData() async {
    if (lastScannedTag == null ||
        selectedArea == null ||
        selectedArea!.isEmpty) {
      return;
    }

    try {
      final updatedTag = await ScanOutService.getTagData(
        lastScannedTag!['id_tag_ok'] ?? lastScannedTag!['labelbox_id'],
        selectedArea!,
      );

      if (!mounted) return;

      if (updatedTag != null) {
        setState(() {
          lastScannedTag = updatedTag;
        });
      }
    } catch (e) {
      debugPrint('Error refreshing last tag: $e');
    }
  }

  Future<void> _refreshLastTag() async {
    if (lastScannedTag == null ||
        selectedArea == null ||
        selectedArea!.isEmpty) {
      return;
    }

    setState(() {
      isProcessing = true;
    });

    try {
      final updatedTag = await ScanOutService.getTagData(
        lastScannedTag!['id_tag_ok'] ?? lastScannedTag!['labelbox_id'],
        selectedArea!,
      );

      if (!mounted) return;

      setState(() {
        isProcessing = false;
      });

      if (updatedTag != null) {
        setState(() {
          lastScannedTag = updatedTag;
        });
        await _showScanOutModal(updatedTag);
      } else {
        _showError('Tag tidak ditemukan');
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isProcessing = false;
      });
      _showError('Error: $e');
    }
  }

  void _deleteLastTag() {
    setState(() {
      isModalOpen = true;
    });

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.delete_outline, color: Colors.red),
            SizedBox(width: 8),
            Text('Hapus Tag'),
          ],
        ),
        content: const Text('Apakah Anda yakin ingin menghapus last tag?'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                lastScannedTag = null;
                lastScannedCode = null;
                lastScanTime = null;
              });
              Navigator.pop(context);

              ScaffoldMessenger.of(context).clearSnackBars();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Last tag dihapus'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Hapus'),
          ),
        ],
      ),
    ).then((_) {
      if (!mounted) return;
      setState(() {
        isModalOpen = false;
      });
    });
  }

  void _showManualInputModal() {
    if (widget.nik.isEmpty) {
      _showError('Anda belum login. Silakan login terlebih dahulu.');
      return;
    }

    if (selectedArea == null || selectedArea!.isEmpty) {
      _showError('Silakan pilih area terlebih dahulu');
      return;
    }

    // Check input permission
    if (!canInputCurrentArea) {
      _showError('Anda tidak memiliki akses input di area $selectedArea');
      return;
    }

    setState(() {
      isModalOpen = true;
    });

    showDialog(
      context: context,
      builder: (context) => ScanOutManualModal(
        area: selectedArea!,
        nik: widget.nik,
        onSubmit: (result) async {
          await ResponseModal.show(
            context,
            success: result['success'] as bool,
            message: result['message'] as String,
            stockInfo: result['stockInfo'] as Map<String, dynamic>?,
            partNumber: result['partNumber'] as String?,
          );
        },
      ),
    ).then((_) {
      if (!mounted) return;
      setState(() {
        isModalOpen = false;
      });
    });
  }

  void _showError(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    permissionManager.removeListener(_onPermissionChanged);
    _disposeCamera();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Check if user is logged in
    if (!permissionManager.isLoggedIn) {
      return _buildNotLoggedIn();
    }

    // Check if user has any scan out permission
    final hasAnyScanOutPermission = permissionManager.hasAnyPermission([
      AppPermissions.viewScanOut,
      AppPermissions.viewScanOutIfpd,
      AppPermissions.viewScanOutIfpp,
      AppPermissions.viewScanOutIfrm,
    ]);

    if (!hasAnyScanOutPermission) {
      return _buildNoAccess();
    }

    final bool hasValidArea =
        selectedArea != null &&
        selectedArea!.isNotEmpty &&
        allAreaOptions
            .firstWhere(
              (a) => a.value == selectedArea,
              orElse: () => allAreaOptions.first,
            )
            .enabled;

    final bool showCamera = hasValidArea && isCameraInitialized;

    return Scaffold(
      body: Stack(
        children: [
          // Camera view or placeholder
          if (showCamera && cameraController != null)
            MobileScanner(
              controller: cameraController!,
              onDetect: _handleBarcodeScan,
            )
          else
            _buildCameraPlaceholder(),

          // Semi-transparent overlay when modal is open
          if (isModalOpen) Container(color: Colors.black54),

          // Top area selector
          Positioned(top: 16, left: 16, right: 16, child: _buildAreaSelector()),

          // Permission info banner
          if (hasValidArea && !canInputCurrentArea)
            Positioned(
              top: 100,
              left: 16,
              right: 16,
              child: _buildViewOnlyBanner(),
            ),

          // Scanning indicator
          if (isProcessing && !isModalOpen)
            Container(
              color: Colors.black54,
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 16),
                    Text(
                      'Memproses...',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),

          // Camera initializing indicator
          if (hasValidArea && !isCameraInitialized && !isModalOpen)
            Container(
              color: Colors.black87,
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 16),
                    Text(
                      'Menginisialisasi kamera...',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),

          // Floating action buttons (only show when camera is ready)
          if (showCamera)
            Positioned(right: 16, bottom: 100, child: _buildActionButtons()),

          // Manual input button at bottom center (only if has input permission)
          if (hasValidArea && canInputCurrentArea)
            Positioned(
              left: 0,
              right: 0,
              bottom: 24,
              child: Center(
                child: ElevatedButton.icon(
                  onPressed: !isModalOpen ? _showManualInputModal : null,
                  icon: const Icon(Icons.keyboard),
                  label: const Text('Input Manual'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.blue,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildNotLoggedIn() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.login, size: 80, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            const Text(
              'Login Diperlukan',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Silakan login terlebih dahulu untuk mengakses fitur Scan Out',
              style: TextStyle(color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoAccess() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock, size: 80, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            const Text(
              'Akses Terbatas',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Anda tidak memiliki akses ke fitur Scan Out.\nHubungi admin untuk mendapatkan akses.',
              style: TextStyle(color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildViewOnlyBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.orange.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade300),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(Icons.visibility, color: Colors.orange.shade800, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Mode View Only',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.orange.shade800,
                    fontSize: 13,
                  ),
                ),
                Text(
                  'Anda hanya bisa melihat data. Hubungi admin untuk akses input.',
                  style: TextStyle(color: Colors.orange.shade700, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCameraPlaceholder() {
    final areaConfig = selectedArea != null && selectedArea!.isNotEmpty
        ? allAreaOptions.firstWhere(
            (a) => a.value == selectedArea,
            orElse: () => allAreaOptions.first,
          )
        : null;

    return Container(
      color: Colors.grey.shade900,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.qr_code_scanner, size: 100, color: Colors.grey.shade600),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                selectedArea == null || selectedArea!.isEmpty
                    ? 'Silakan pilih area untuk memulai scanning'
                    : areaConfig != null && !areaConfig.enabled
                    ? 'Area ${areaConfig.label} ${areaConfig.disabledReason ?? "tidak tersedia"}'
                    : 'Kamera tidak aktif',
                style: TextStyle(
                  color: areaConfig != null && !areaConfig.enabled
                      ? Colors.red.shade300
                      : Colors.grey.shade400,
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            // Show accessible areas
            if (selectedArea == null || selectedArea!.isEmpty) ...[
              const SizedBox(height: 24),
              Text(
                'Area yang tersedia:',
                style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: availableAreaOptions
                    .where((a) => a.value.isNotEmpty && a.enabled)
                    .map((area) {
                      final hasInputAccess = canInputInArea(area.value);
                      return Chip(
                        avatar: Icon(
                          hasInputAccess ? Icons.edit : Icons.visibility,
                          size: 16,
                          color: hasInputAccess ? Colors.green : Colors.orange,
                        ),
                        label: Text(
                          area.label,
                          style: const TextStyle(fontSize: 12),
                        ),
                        backgroundColor: Colors.grey.shade800,
                        labelStyle: TextStyle(color: Colors.grey.shade300),
                      );
                    })
                    .toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAreaSelector() {
    final areas = availableAreaOptions;

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade400, Colors.blue.shade600],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.5),
            blurRadius: 12,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.location_on,
                color: Colors.blue.shade700,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Area Scan',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12,
                        ),
                      ),
                      if (selectedArea != null &&
                          selectedArea!.isNotEmpty &&
                          canInputCurrentArea) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.edit,
                                size: 10,
                                color: Colors.green.shade700,
                              ),
                              const SizedBox(width: 2),
                              Text(
                                'Input',
                                style: TextStyle(
                                  fontSize: 9,
                                  color: Colors.green.shade700,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ] else if (selectedArea != null &&
                          selectedArea!.isNotEmpty &&
                          !canInputCurrentArea) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.visibility,
                                size: 10,
                                color: Colors.orange.shade700,
                              ),
                              const SizedBox(width: 2),
                              Text(
                                'View',
                                style: TextStyle(
                                  fontSize: 9,
                                  color: Colors.orange.shade700,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: areas.any((a) => a.value == selectedArea)
                          ? selectedArea
                          : '',
                      isExpanded: true,
                      isDense: true,
                      icon: Icon(
                        Icons.arrow_drop_down,
                        color: Colors.blue.shade700,
                      ),
                      style: TextStyle(
                        color: Colors.blue.shade700,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                      items: areas.map((area) {
                        final bool isDisabled = !area.enabled;
                        final bool hasInputAccess = canInputInArea(area.value);

                        return DropdownMenuItem<String>(
                          value: area.value,
                          enabled: area.enabled,
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  area.label,
                                  style: TextStyle(
                                    color: isDisabled
                                        ? Colors.grey.shade400
                                        : Colors.blue.shade700,
                                  ),
                                ),
                              ),
                              if (area.value.isNotEmpty && area.enabled) ...[
                                Icon(
                                  hasInputAccess
                                      ? Icons.edit
                                      : Icons.visibility,
                                  size: 14,
                                  color: hasInputAccess
                                      ? Colors.green.shade600
                                      : Colors.orange.shade600,
                                ),
                              ],
                              if (isDisabled && area.value.isNotEmpty) ...[
                                Icon(
                                  Icons.lock,
                                  size: 14,
                                  color: Colors.grey.shade400,
                                ),
                              ],
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: _onAreaChanged,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        FloatingActionButton(
          heroTag: 'detail',
          onPressed: lastScannedTag != null && !isModalOpen
              ? _refreshLastTag
              : null,
          backgroundColor: lastScannedTag != null
              ? Colors.blue
              : Colors.grey.shade600,
          child: const Icon(Icons.info_outline),
        ),
        const SizedBox(height: 12),
        FloatingActionButton(
          heroTag: 'delete',
          onPressed: lastScannedTag != null && !isModalOpen
              ? _deleteLastTag
              : null,
          backgroundColor: lastScannedTag != null
              ? Colors.red
              : Colors.grey.shade600,
          child: const Icon(Icons.delete_outline),
        ),
      ],
    );
  }
}

/// Model untuk area option dengan permission
class AreaOption {
  final String value;
  final String label;
  final String? viewPermission;
  final String? inputPermission;
  final bool enabled;
  final String? disabledReason;

  const AreaOption({
    required this.value,
    required this.label,
    this.viewPermission,
    this.inputPermission,
    this.enabled = true,
    this.disabledReason,
  });
}
