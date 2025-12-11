import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../services/scan_sto.dart';
import '../components/scan_sto_detail.dart';
import '../components/scan_sto_manual.dart';
import '../components/response_modal.dart';

class ScanStoPage extends StatefulWidget {
  final String nik;

  const ScanStoPage({super.key, required this.nik});

  @override
  State<ScanStoPage> createState() => _ScanStoPageState();
}

class _ScanStoPageState extends State<ScanStoPage> with WidgetsBindingObserver {
  String? selectedArea;
  Map<String, dynamic>? lastScannedTag;
  MobileScannerController? cameraController;
  bool isProcessing = false;
  bool isModalOpen = false;
  String? lastScannedCode;
  DateTime? lastScanTime;
  bool isCameraInitialized = false;

  final List<Map<String, String>> areaOptions = [
    {'value': '', 'label': '--- Pilih Area ---'},
    {'value': 'IFRM', 'label': 'IFRM (Belum tersedia)'},
    {'value': 'IFPP', 'label': 'IFPP'},
    {'value': 'IFPD', 'label': 'IFPD'},
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    selectedArea = ''; // Default to no selection
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
    if (cameraController != null) return; // Already initialized

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

    // Prevent selecting disabled area
    if (value == 'IFRM') {
      _showError('Area IFRM belum tersedia');
      return;
    }

    // Only update selectedArea, don't touch camera
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
    // Prevent scan if conditions not met
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
      final tagData = await ScanStoService.getTagData(code, selectedArea!);

      if (!mounted) return;

      setState(() {
        isProcessing = false;
      });

      if (tagData != null) {
        setState(() {
          lastScannedTag = tagData;
        });

        await _showDetailTagModal(tagData);
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

  Future<void> _showDetailTagModal(Map<String, dynamic> tagData) async {
    if (!mounted) return;

    ScaffoldMessenger.of(context).clearSnackBars();

    setState(() {
      isModalOpen = true;
    });

    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => DetailTagModal(
        tagData: tagData,
        area: selectedArea!,
        nik: widget.nik,
        onUpload: (result) async {
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
    if (lastScannedTag == null ||
        selectedArea == null ||
        selectedArea!.isEmpty) {
      return;
    }

    try {
      final updatedTag = await ScanStoService.getTagData(
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
      final updatedTag = await ScanStoService.getTagData(
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
        await _showDetailTagModal(updatedTag);
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

    setState(() {
      isModalOpen = true;
    });

    showDialog(
      context: context,
      builder: (context) => ScanStoManualModal(
        area: selectedArea!,
        nik: widget.nik,
        onSubmit: (result) async {
          await ResponseModal.show(
            context,
            success: result['success'] as bool,
            message: result['message'] as String,
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
    _disposeCamera();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool hasValidArea =
        selectedArea != null &&
        selectedArea!.isNotEmpty &&
        selectedArea != 'IFRM';

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

          // Manual input button at bottom center
          if (hasValidArea)
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
                selectedArea == null || selectedArea!.isEmpty
                    ? 'Silakan pilih area untuk memulai scanning'
                    : selectedArea == 'IFRM'
                    ? 'Area IFRM belum tersedia'
                    : 'Kamera tidak aktif',
                style: TextStyle(
                  color: selectedArea == 'IFRM'
                      ? Colors.red.shade300
                      : Colors.grey.shade400,
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAreaSelector() {
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
            color: Colors.blue.withValues(alpha: 0.5),
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
                  Text(
                    'Area Scan',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: selectedArea,
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
                      items: areaOptions.map((area) {
                        final bool isDisabled = area['value'] == 'IFRM';
                        return DropdownMenuItem<String>(
                          value: area['value'],
                          enabled: !isDisabled,
                          child: Text(
                            area['label']!,
                            style: TextStyle(
                              color: isDisabled
                                  ? Colors.grey.shade400
                                  : Colors.blue.shade700,
                            ),
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
