import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../services/scan_sto.dart';
import '../components/scan_sto_detail.dart';
import '../components/scan_sto_manual.dart';
import '../components/response_modal.dart';
import '../utils/permission_manager.dart';
import '../utils/permissions.dart';

class ScanStoPage extends StatefulWidget {
  final String nik;

  const ScanStoPage({super.key, required this.nik});

  @override
  State<ScanStoPage> createState() => _ScanStoPageState();
}

class _ScanStoPageState extends State<ScanStoPage> with WidgetsBindingObserver {
  String? selectedGroup;
  Map<String, dynamic>? lastScannedTag;
  MobileScannerController? cameraController;
  bool isProcessing = false;
  bool isModalOpen = false;
  String? lastScannedCode;
  DateTime? lastScanTime;
  bool isCameraInitialized = false;

  final List<Map<String, dynamic>> groupOptions = [
    {'value': '', 'label': '--- Pilih Group ---', 'color': Colors.grey},
    {'value': 'A', 'label': 'Group A', 'color': Colors.blue},
    {'value': 'B', 'label': 'Group B', 'color': Colors.orange},
  ];

  /// Check apakah user punya permission untuk input
  bool get canInput {
    if (permissionManager.isAdmin) return true;
    return permissionManager.hasPermission(AppPermissions.inputScanSto);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    selectedGroup = '';
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

  void _onGroupChanged(String? value) {
    if (value == null) return;

    setState(() {
      selectedGroup = value;
      lastScannedTag = null;
      lastScannedCode = null;
      lastScanTime = null;
    });

    // Initialize camera if group is valid
    if (value.isNotEmpty && !isCameraInitialized) {
      _initializeCamera();
    }
  }

  Color _getGroupColor() {
    if (selectedGroup == 'A') return Colors.blue;
    if (selectedGroup == 'B') return Colors.orange;
    return Colors.grey;
  }

  Future<void> _handleBarcodeScan(BarcodeCapture capture) async {
    if (isModalOpen || isProcessing || !isCameraInitialized) return;
    if (selectedGroup == null || selectedGroup!.isEmpty) return;

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

    await _processBarcode(code);
  }

  Future<void> _processBarcode(String code) async {
    if (!mounted) return;

    setState(() {
      isProcessing = true;
    });

    try {
      final tagData = await ScanStoService.getTagData(code);

      if (!mounted) return;

      setState(() {
        isProcessing = false;
      });

      if (tagData != null) {
        setState(() {
          lastScannedTag = tagData;
        });

        await _showDetailModal(tagData);
      } else {
        _showError('Tag "$code" tidak ditemukan');
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isProcessing = false;
      });
      _showError('Error: $e');
    }
  }

  Future<void> _showDetailModal(Map<String, dynamic> tagData) async {
    if (!mounted) return;

    ScaffoldMessenger.of(context).clearSnackBars();

    setState(() {
      isModalOpen = true;
    });

    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => StoDetailModal(
        tagData: tagData,
        group: selectedGroup!,
        nik: widget.nik,
        canInput: canInput,
        onSubmit: (result) async {
          await ResponseModal.show(
            context,
            success: result['success'] as bool,
            message: result['message'] as String,
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
    if (lastScannedTag == null) return;

    try {
      final tagId = lastScannedTag!['id_tag'] ?? '';
      if (tagId.isEmpty) return;

      final updatedTag = await ScanStoService.getTagData(tagId);

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
    if (lastScannedTag == null) return;

    setState(() {
      isProcessing = true;
    });

    try {
      final tagId = lastScannedTag!['id_tag'] ?? '';
      if (tagId.isEmpty) {
        setState(() => isProcessing = false);
        return;
      }

      final updatedTag = await ScanStoService.getTagData(tagId);

      if (!mounted) return;

      setState(() {
        isProcessing = false;
      });

      if (updatedTag != null) {
        setState(() {
          lastScannedTag = updatedTag;
        });
        await _showDetailModal(updatedTag);
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
            onPressed: () => Navigator.pop(context),
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

    if (selectedGroup == null || selectedGroup!.isEmpty) {
      _showError('Silakan pilih group terlebih dahulu');
      return;
    }

    setState(() {
      isModalOpen = true;
    });

    showDialog(
      context: context,
      builder: (context) => StoManualInputModal(
        group: selectedGroup!,
        nik: widget.nik,
        canInput: canInput,
        onTagFound: (tagData) async {
          setState(() {
            lastScannedTag = tagData;
          });
          // Close manual modal first
          Navigator.pop(context);
          // Then show detail modal
          await _showDetailModal(tagData);
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
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _disposeCamera();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Check permission
    if (!permissionManager.hasPermission(AppPermissions.viewScanSto) &&
        !permissionManager.isAdmin) {
      return _buildNoAccess();
    }

    final bool hasValidGroup =
        selectedGroup != null && selectedGroup!.isNotEmpty;
    final bool showCamera = hasValidGroup && isCameraInitialized;

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

          // Top group selector
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: _buildGroupSelector(),
          ),

          // View-only banner
          if (hasValidGroup && !canInput)
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
          if (hasValidGroup && !isCameraInitialized && !isModalOpen)
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

          // Floating action buttons
          if (showCamera)
            Positioned(right: 16, bottom: 100, child: _buildActionButtons()),

          // Manual input button
          if (hasValidGroup)
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
                    foregroundColor: _getGroupColor(),
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

  Widget _buildNoAccess() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock_outline, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'Akses Ditolak',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Anda tidak memiliki permission untuk mengakses halaman ini.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildViewOnlyBanner() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.visibility, color: Colors.orange.shade700, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Mode Lihat Saja - Tidak dapat input data',
              style: TextStyle(
                color: Colors.orange.shade800,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCameraPlaceholder() {
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
                selectedGroup == null || selectedGroup!.isEmpty
                    ? 'Silakan pilih Group untuk memulai scanning'
                    : 'Kamera tidak aktif',
                style: TextStyle(color: Colors.grey.shade400, fontSize: 16),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupSelector() {
    final groupColor = _getGroupColor();

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [groupColor.withOpacity(0.8), groupColor],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: groupColor.withOpacity(0.5),
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
                color: groupColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.group_work, color: groupColor, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Pilih Group STO',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: selectedGroup,
                      isExpanded: true,
                      isDense: true,
                      icon: Icon(Icons.arrow_drop_down, color: groupColor),
                      style: TextStyle(
                        color: groupColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                      items: groupOptions.map((group) {
                        final color = group['color'] as Color;
                        return DropdownMenuItem<String>(
                          value: group['value'] as String,
                          child: Text(
                            group['label'] as String,
                            style: TextStyle(
                              color: color,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        );
                      }).toList(),
                      onChanged: _onGroupChanged,
                    ),
                  ),
                ],
              ),
            ),
            // Group indicator badge
            if (selectedGroup != null && selectedGroup!.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: groupColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  selectedGroup!,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
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
              ? _getGroupColor()
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
