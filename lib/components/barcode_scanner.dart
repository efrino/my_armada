import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class BarcodeScanner extends StatefulWidget {
  final Function(String) onScanned;
  final bool isActive;

  const BarcodeScanner({
    super.key,
    required this.onScanned,
    this.isActive = true,
  });

  @override
  State<BarcodeScanner> createState() => _BarcodeScannerState();
}

class _BarcodeScannerState extends State<BarcodeScanner>
    with WidgetsBindingObserver {
  late MobileScannerController _controller;
  bool _isFlashOn = false;
  bool _hasScanned = false;
  bool _isControllerInitialized = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initController();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_isControllerInitialized) return;

    switch (state) {
      case AppLifecycleState.resumed:
        if (widget.isActive && !_hasScanned) {
          _safeStart();
        }
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
        _safeStop();
        break;
      default:
        break;
    }
  }

  void _initController() {
    _controller = MobileScannerController(
      facing: CameraFacing.back,
      torchEnabled: false,
      detectionSpeed: DetectionSpeed.normal,
      detectionTimeoutMs: 500,
    );
    _isControllerInitialized = true;
  }

  @override
  void didUpdateWidget(BarcodeScanner oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.isActive && !oldWidget.isActive) {
      _resetScanner();
    } else if (!widget.isActive && oldWidget.isActive) {
      _safeStop();
    }
  }

  Future<void> _resetScanner() async {
    if (!mounted || !_isControllerInitialized) return;

    setState(() => _hasScanned = false);
    await Future.delayed(const Duration(milliseconds: 100));
    if (mounted) _safeStart();
  }

  Future<void> _safeStart() async {
    if (!_isControllerInitialized) return;
    try {
      await _controller.start();
    } catch (e) {
      debugPrint('Error starting scanner: $e');
    }
  }

  Future<void> _safeStop() async {
    if (!_isControllerInitialized) return;
    try {
      await _controller.stop();
    } catch (e) {
      debugPrint('Error stopping scanner: $e');
    }
  }

  void _toggleFlash() async {
    if (!_isControllerInitialized) return;
    try {
      await _controller.toggleTorch();
      if (mounted) {
        setState(() => _isFlashOn = !_isFlashOn);
      }
    } catch (e) {
      debugPrint('Error toggling flash: $e');
    }
  }

  Future<void> _manualRestart() async {
    if (!mounted || !_isControllerInitialized) return;

    setState(() => _hasScanned = false);
    await _safeStop();
    await Future.delayed(const Duration(milliseconds: 200));
    if (mounted) await _safeStart();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_hasScanned || !widget.isActive || !mounted) return;

    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isNotEmpty) {
      final String? code = barcodes.first.rawValue;
      if (code != null && code.isNotEmpty) {
        setState(() => _hasScanned = true);
        _safeStop();
        widget.onScanned(code);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade300, width: 1),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            // Scanner View
            SizedBox(
              height: 280,
              width: double.infinity,
              child: _isControllerInitialized
                  ? MobileScanner(
                      controller: _controller,
                      onDetect: _onDetect,
                      errorBuilder: (_, error) => _buildErrorWidget(error),
                    )
                  : _buildLoadingWidget(),
            ),

            // Scan Frame Overlay
            Positioned.fill(child: CustomPaint(painter: ScanFramePainter())),

            // Top Controls - Flash & Refresh
            Positioned(
              top: 8,
              left: 8,
              right: 8,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildControlButton(
                    icon: _isFlashOn ? Icons.flash_on : Icons.flash_off,
                    onTap: _toggleFlash,
                    isActive: _isFlashOn,
                    tooltip: 'Flash',
                  ),
                  _buildControlButton(
                    icon: Icons.refresh,
                    onTap: _manualRestart,
                    tooltip: 'Refresh',
                  ),
                ],
              ),
            ),

            // Success Overlay
            if (_hasScanned)
              Positioned.fill(
                child: Container(
                  color: Colors.green.withOpacity(0.4),
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(50),
                      ),
                      child: const Icon(
                        Icons.check,
                        color: Colors.green,
                        size: 40,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingWidget() {
    return Container(
      color: Colors.black87,
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.white),
            SizedBox(height: 16),
            Text(
              'Memuat kamera...',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required VoidCallback onTap,
    bool isActive = false,
    String? tooltip,
  }) {
    return Tooltip(
      message: tooltip ?? '',
      child: Material(
        color: isActive ? Colors.amber : Colors.black54,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorWidget(MobileScannerException error) {
    return Container(
      color: Colors.grey.shade900,
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.videocam_off, color: Colors.red.shade300, size: 48),
            const SizedBox(height: 16),
            Text(
              _getErrorMessage(error),
              style: const TextStyle(color: Colors.white70, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: _manualRestart,
              icon: const Icon(Icons.refresh, color: Colors.white70),
              label: const Text(
                'Coba Lagi',
                style: TextStyle(color: Colors.white70),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.white38),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getErrorMessage(MobileScannerException error) {
    switch (error.errorCode) {
      case MobileScannerErrorCode.permissionDenied:
        return 'Izin kamera ditolak.\nBuka pengaturan untuk mengizinkan.';
      case MobileScannerErrorCode.unsupported:
        return 'Perangkat tidak mendukung kamera.';
      default:
        return 'Gagal membuka kamera.';
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _isControllerInitialized = false;
    _controller.dispose();
    super.dispose();
  }
}

/// Custom painter untuk frame scan area
class ScanFramePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Scan area di tengah
    const scanSize = 200.0;
    final left = (size.width - scanSize) / 2;
    final top = (size.height - scanSize) / 2;
    final scanRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(left, top, scanSize, scanSize),
      const Radius.circular(12),
    );

    // Semi-transparent overlay di luar scan area
    final overlayPaint = Paint()..color = Colors.black.withOpacity(0.5);
    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRRect(scanRect)
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(path, overlayPaint);

    // Border scan area
    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawRRect(scanRect, borderPaint);

    // Corner accents
    final cornerPaint = Paint()
      ..color = Colors.blue
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    const len = 25.0;
    final corners = [
      // Top-left
      [Offset(left, top + len), Offset(left, top), Offset(left + len, top)],
      // Top-right
      [
        Offset(left + scanSize - len, top),
        Offset(left + scanSize, top),
        Offset(left + scanSize, top + len),
      ],
      // Bottom-left
      [
        Offset(left, top + scanSize - len),
        Offset(left, top + scanSize),
        Offset(left + len, top + scanSize),
      ],
      // Bottom-right
      [
        Offset(left + scanSize - len, top + scanSize),
        Offset(left + scanSize, top + scanSize),
        Offset(left + scanSize, top + scanSize - len),
      ],
    ];

    for (var corner in corners) {
      canvas.drawLine(corner[0], corner[1], cornerPaint);
      canvas.drawLine(corner[1], corner[2], cornerPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
