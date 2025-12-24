import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../components/barcode_scanner.dart';
import '../components/loading_dialog.dart';
import '../components/error_dialog.dart';
import '../components/success_dialog.dart';
import '../components/confirm_dialog.dart';
import '../services/wss_service.dart';
import '../utils/shared_prefs.dart';
import '../utils/helpers.dart';
import '../utils/permission_manager.dart';
import '../utils/permissions.dart';
import '../models/wss_model.dart';

class ScanIfpWssPage extends StatefulWidget {
  final String nik;

  const ScanIfpWssPage({super.key, required this.nik});

  @override
  State<ScanIfpWssPage> createState() => _ScanIfpWssPageState();
}

class _ScanIfpWssPageState extends State<ScanIfpWssPage> {
  final _tagController = TextEditingController();
  final _scrollController = ScrollController();

  TagDataModel? _tagData;
  WssPartModel? _wssPartData;
  bool _isLoading = false;
  bool _isWssValid = false;
  bool _useManualInput = false;
  bool _scannerActive = true;

  // Qty dari tag (locked, tidak bisa diubah)
  int _qtyFromTag = 0;

  // Check is_scanned state
  bool _isAlreadyScanned = false;
  ScanInfo? _previousScanInfo;

  // Counter untuk force rebuild scanner
  int _scannerRebuildKey = 0;

  /// Check apakah user punya permission untuk input
  bool get canInput {
    if (permissionManager.isAdmin) return true;
    return permissionManager.hasPermission(AppPermissions.inputScanIfpWss);
  }

  @override
  void initState() {
    super.initState();
  }

  void _onBarcodeScanned(String barcode) {
    HapticFeedback.mediumImpact();
    setState(() {
      _tagController.text = barcode;
      _scannerActive = false;
    });
    _fetchTagDetail(barcode);
  }

  void _toggleInputMode() {
    setState(() {
      _useManualInput = !_useManualInput;
      if (!_useManualInput) {
        _scannerActive = true;
        _scannerRebuildKey++;
      }
    });
  }

  Future<void> _fetchTagDetail(String? idTagOk) async {
    final tagId = idTagOk ?? _tagController.text.trim();
    if (tagId.isEmpty) {
      ErrorDialog.show(context, message: 'ID Tag OK tidak boleh kosong');
      return;
    }

    setState(() {
      _isLoading = true;
      _tagData = null;
      _wssPartData = null;
      _isWssValid = false;
      _qtyFromTag = 0;
      _isAlreadyScanned = false;
      _previousScanInfo = null;
    });

    LoadingDialog.show(context, message: 'Memeriksa tag...');

    // ========== STEP 1: CEK APAKAH TAG SUDAH PERNAH DI-SCAN ==========
    final scanCheck = await WssService.checkTagScanned(tagId);
    if (!mounted) return;

    if (scanCheck.success &&
        scanCheck.data != null &&
        scanCheck.data!.isScanned) {
      // Tag sudah pernah di-scan - set state, TIDAK pakai modal
      setState(() {
        _isAlreadyScanned = true;
        _previousScanInfo = scanCheck.data!.scanInfo;
      });
      // Tetap lanjut ambil data tag untuk ditampilkan
    }
    // ================================================================

    // STEP 2: Ambil data tag dari IFPD
    final tagResponse = await WssService.getTagDetail(tagId);
    if (!mounted) return;

    if (tagResponse.success && tagResponse.data != null) {
      setState(() => _tagData = tagResponse.data);

      // STEP 3: Check part WSS (hanya jika belum di-scan)
      if (!_isAlreadyScanned) {
        await _checkPartWss(_tagData!.partNumber);
      } else {
        // Jika sudah di-scan, tetap cek WSS untuk info tapi tidak untuk submit
        final wssResponse = await WssService.checkPartWss(_tagData!.partNumber);
        if (wssResponse.success && wssResponse.data != null) {
          setState(() {
            _wssPartData = wssResponse.data;
            _isWssValid = true;
            _qtyFromTag = _tagData!.qty;
          });
        }
        LoadingDialog.hide(context);
        setState(() => _isLoading = false);

        // Scroll ke bawah untuk lihat warning
        Future.delayed(const Duration(milliseconds: 300), () {
          if (_scrollController.hasClients) {
            _scrollController.animateTo(
              _scrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          }
        });
      }
    } else {
      LoadingDialog.hide(context);
      setState(() => _isLoading = false);
      ErrorDialog.show(
        context,
        message: tagResponse.message,
        onConfirm: _resetForm,
      );
    }
  }

  Future<void> _checkPartWss(String partNumber) async {
    final wssResponse = await WssService.checkPartWss(partNumber);
    if (!mounted) return;

    LoadingDialog.hide(context);
    setState(() => _isLoading = false);

    if (wssResponse.success && wssResponse.data != null) {
      setState(() {
        _wssPartData = wssResponse.data;
        _isWssValid = true;
        _qtyFromTag = _tagData!.qty;
      });

      Future.delayed(const Duration(milliseconds: 300), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    } else {
      setState(() => _isWssValid = false);
      final retry = await ConfirmDialog.show(
        context,
        title: 'Bukan Part WSS',
        message: '${wssResponse.message}\n\nScan tag lain?',
        confirmText: 'Scan Lagi',
        confirmColor: Colors.blue,
      );
      if (retry == true) _resetForm();
    }
  }

  Future<void> _submitScanIn() async {
    // Block jika tidak punya permission input
    if (!canInput) {
      ErrorDialog.show(
        context,
        message: 'Anda tidak memiliki permission untuk melakukan scan in',
      );
      return;
    }

    // Block jika sudah pernah di-scan
    if (_isAlreadyScanned) {
      return;
    }

    if (_tagData == null || _wssPartData == null || !_isWssValid) {
      ErrorDialog.show(context, message: 'Data tidak lengkap');
      return;
    }

    if (_qtyFromTag <= 0) {
      ErrorDialog.show(context, message: 'Qty harus lebih dari 0');
      return;
    }

    if (widget.nik.isEmpty) {
      ErrorDialog.show(context, message: 'NIK tidak tersedia');
      return;
    }

    final confirm = await ConfirmDialog.show(
      context,
      title: 'Konfirmasi Scan',
      message:
          'Part: ${_tagData!.partNumber}\nQty: ${Helpers.formatNumber(_qtyFromTag)}\n\nLanjutkan?',
      confirmText: 'Ya, Simpan',
      confirmColor: Colors.green,
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);
    LoadingDialog.show(context, message: 'Menyimpan...');

    final response = await WssService.scanIn(
      partWss: _tagData!.partNumber,
      qty: _qtyFromTag,
      nik: widget.nik,
      deviceId: SharedPrefs.getDeviceId(),
      idTagOk: _tagData!.idTagOk,
    );

    if (!mounted) return;
    LoadingDialog.hide(context);
    setState(() => _isLoading = false);

    if (response.success && response.data != null) {
      HapticFeedback.heavyImpact();
      final result = response.data!;

      await SuccessDialog.show(
        context,
        title: 'Berhasil! ✓',
        message:
            'Part: ${result.partWss}\n'
            'Qty: +${Helpers.formatNumber(result.qtyAdded)}\n'
            'Stok: ${Helpers.formatNumber(result.newStock)}',
        onConfirm: _resetForm,
      );
    } else {
      ErrorDialog.show(context, message: response.message);
    }
  }

  void _resetForm() {
    setState(() {
      _tagController.clear();
      _tagData = null;
      _wssPartData = null;
      _isWssValid = false;
      _qtyFromTag = 0;
      _isAlreadyScanned = false;
      _previousScanInfo = null;
      _useManualInput = false;
      _scannerActive = true;
      _scannerRebuildKey++;
    });

    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Check permission - jika tidak punya view permission, tampilkan no access
    if (!permissionManager.hasPermission(AppPermissions.viewScanIfpWss) &&
        !permissionManager.isAdmin) {
      return _buildNoAccess();
    }

    return SingleChildScrollView(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // View-only banner jika tidak punya permission input
          if (!canInput) ...[
            _buildViewOnlyBanner(),
            const SizedBox(height: 12),
          ],

          // Step 1: Scanner / Manual Input
          if (_tagData == null) ...[
            _buildInputSection(),
            const SizedBox(height: 16),
          ],

          // Step 2: Tag Info
          if (_tagData != null) ...[
            _buildTagInfoCard(),
            const SizedBox(height: 12),
          ],

          // WARNING: Tag sudah di-scan (inline card, bukan modal)
          if (_isAlreadyScanned && _previousScanInfo != null) ...[
            _buildAlreadyScannedCard(),
            const SizedBox(height: 12),
          ],

          // Step 3: WSS Info & Submit
          if (_wssPartData != null && _isWssValid) ...[
            _buildWssInfoCard(),
            const SizedBox(height: 12),
            _buildQtyDisplayCard(),
            const SizedBox(height: 20),
            if (canInput) _buildSubmitButton(),
            if (canInput) const SizedBox(height: 12),
            _buildResetButton(),
          ],
        ],
      ),
    );
  }

  /// No access widget
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
              'Anda tidak memiliki permission untuk mengakses halaman ini.\nHubungi admin untuk mendapatkan akses.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }

  /// View only banner
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Mode Lihat Saja',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.orange.shade800,
                    fontSize: 13,
                  ),
                ),
                Text(
                  'Anda tidak memiliki permission untuk menyimpan data',
                  style: TextStyle(color: Colors.orange.shade700, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Warning Card untuk tag yang sudah pernah di-scan
  Widget _buildAlreadyScannedCard() {
    return Card(
      elevation: 2,
      color: Colors.orange.shade50,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.orange.shade300, width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Warning
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.orange.shade700,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Tag Sudah Di-scan!',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.orange.shade800,
                          fontSize: 15,
                        ),
                      ),
                      Text(
                        'Tag ini tidak dapat di-scan ulang',
                        style: TextStyle(
                          color: Colors.orange.shade700,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),
            Divider(color: Colors.orange.shade200, height: 1),
            const SizedBox(height: 12),

            // Info scan sebelumnya
            Text(
              'Info Scan Sebelumnya:',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 8),
            _buildScanInfoRow('Part WSS', _previousScanInfo!.partWss),
            _buildScanInfoRow(
              'Qty',
              Helpers.formatNumber(_previousScanInfo!.qty),
            ),
            _buildScanInfoRow('Batch', _previousScanInfo!.batchNumber ?? '-'),
            _buildScanInfoRow(
              'Waktu',
              Helpers.formatDateTime(_previousScanInfo!.scanTime),
            ),
            _buildScanInfoRow('Oleh', _previousScanInfo!.scannedBy ?? '-'),
          ],
        ),
      ),
    );
  }

  Widget _buildScanInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 70,
            child: Text(
              label,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ),
          const Text(': ', style: TextStyle(fontSize: 12)),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Row(
            children: [
              Icon(
                _useManualInput ? Icons.keyboard : Icons.qr_code_scanner,
                color: Colors.blue.shade700,
                size: 22,
              ),
              const SizedBox(width: 8),
              Text(
                _useManualInput ? 'Input Manual' : 'Scan Barcode',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: _toggleInputMode,
                icon: Icon(
                  _useManualInput ? Icons.qr_code_scanner : Icons.keyboard,
                  size: 18,
                ),
                label: Text(
                  _useManualInput ? 'Gunakan Kamera' : 'Input Manual',
                  style: const TextStyle(fontSize: 13),
                ),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(color: Colors.blue.shade200),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        if (_useManualInput)
          _buildManualInputCard()
        else
          Column(
            children: [
              BarcodeScanner(
                key: ValueKey('scanner_$_scannerRebuildKey'),
                isActive: _scannerActive,
                onScanned: _onBarcodeScanned,
              ),
              const SizedBox(height: 8),
              Text(
                'Arahkan kamera ke barcode Tag OK',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                textAlign: TextAlign.center,
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildManualInputCard() {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Masukkan ID Tag OK secara manual jika barcode tidak terbaca.',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _tagController,
              autofocus: true,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Contoh: MAJWLD2911250100772',
                prefixIcon: const Icon(Icons.tag),
                suffixIcon: _tagController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 20),
                        onPressed: () {
                          _tagController.clear();
                          setState(() {});
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => _fetchTagDetail(null),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : () => _fetchTagDetail(null),
                icon: const Icon(Icons.search, size: 20),
                label: const Text('Cari Tag'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTagInfoCard() {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.qr_code_2, color: Colors.blue.shade700, size: 24),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Tag OK',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      Text(
                        _tagData!.idTagOk,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: Colors.blue.shade700,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Helpers.getStatusColor(_tagData!.status),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _tagData!.status,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                _buildInfoRow(
                  'Part Number',
                  _tagData!.partNumber,
                  isBold: true,
                ),
                const Divider(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildInfoItem(
                        'Tanggal',
                        Helpers.formatDate(_tagData!.date),
                      ),
                    ),
                    Expanded(
                      child: _buildInfoItem(
                        'Shift',
                        'Shift ${_tagData!.shift}',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: _buildInfoItem('Line', _tagData!.lineId)),
                    Expanded(
                      child: _buildInfoItem(
                        'Qty Tag',
                        Helpers.formatNumber(_tagData!.qty),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWssInfoCard() {
    return Card(
      elevation: 1,
      color: Colors.green.shade50,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.check_circle,
                color: Colors.green.shade700,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Part WSS Valid',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade700,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    '${_wssPartData!.model ?? '-'} • ${_wssPartData!.customer ?? '-'}',
                    style: TextStyle(
                      color: Colors.green.shade600,
                      fontSize: 12,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'Stok',
                  style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                ),
                Text(
                  Helpers.formatNumber(_wssPartData!.currentStock),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: Colors.blue.shade700,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQtyDisplayCard() {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.add_box, color: Colors.orange.shade700, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Qty Scan In',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.lock, size: 12, color: Colors.grey.shade600),
                      const SizedBox(width: 4),
                      Text(
                        'Dari Tag',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 20),
              decoration: BoxDecoration(
                color: _isAlreadyScanned || !canInput
                    ? Colors.grey.shade200
                    : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: _isAlreadyScanned || !canInput
                      ? Colors.grey.shade400
                      : Colors.grey.shade300,
                ),
              ),
              child: Column(
                children: [
                  Text(
                    Helpers.formatNumber(_qtyFromTag),
                    style: TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      color: _isAlreadyScanned || !canInput
                          ? Colors.grey.shade500
                          : Colors.blue.shade700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'pcs',
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.info_outline, size: 14, color: Colors.grey.shade500),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _isAlreadyScanned
                        ? 'Tag sudah di-scan, tidak dapat disimpan ulang'
                        : !canInput
                        ? 'Anda tidak memiliki permission untuk menyimpan'
                        : 'Pastikan Qty Aktual sesuai',
                    style: TextStyle(
                      fontSize: 11,
                      color: _isAlreadyScanned || !canInput
                          ? Colors.orange.shade700
                          : Colors.grey.shade600,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubmitButton() {
    // Disabled jika sudah di-scan, tidak punya permission, atau sedang loading
    final isDisabled = _isAlreadyScanned || !canInput || _isLoading;

    return SizedBox(
      height: 52,
      child: ElevatedButton.icon(
        onPressed: isDisabled ? null : _submitScanIn,
        icon: Icon(_isAlreadyScanned ? Icons.block : Icons.save),
        label: Text(
          _isAlreadyScanned ? 'TIDAK DAPAT DISIMPAN' : 'SIMPAN',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: _isAlreadyScanned ? Colors.grey : Colors.green,
          foregroundColor: Colors.white,
          disabledBackgroundColor: Colors.grey.shade400,
          disabledForegroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Widget _buildResetButton() {
    return OutlinedButton.icon(
      onPressed: _resetForm,
      icon: const Icon(Icons.qr_code_scanner, size: 20),
      label: const Text('Scan Tag Baru'),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {bool isBold = false}) {
    return Row(
      children: [
        Text(
          '$label: ',
          style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
              fontSize: isBold ? 15 : 13,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
        ),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  @override
  void dispose() {
    _tagController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}
