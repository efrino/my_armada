import 'package:flutter/material.dart';
import '../services/scan_in.dart';

class DetailTagModal extends StatefulWidget {
  final Map<String, dynamic> tagData;
  final String area;
  final String nik;
  final bool canInput; // Permission flag untuk input
  final Function(Map<String, dynamic> result) onUpload;

  const DetailTagModal({
    super.key,
    required this.tagData,
    required this.area,
    required this.nik,
    this.canInput = true, // Default true untuk backward compatibility
    required this.onUpload,
  });

  @override
  State<DetailTagModal> createState() => _DetailTagModalState();
}

class _DetailTagModalState extends State<DetailTagModal> {
  late TextEditingController _qtyController;
  bool isSubmitting = false;
  bool isScannedIn = false;
  bool hasValidData = true;

  // Stock info state
  bool isLoadingStock = false;
  Map<String, dynamic>? stockInfo;

  @override
  void initState() {
    super.initState();
    _qtyController = TextEditingController(text: _getQtyValue());
    _checkScannedStatus();
    _validateData();

    // Load stock info if has valid data and not already scanned
    if (hasValidData && !isScannedIn) {
      _loadStockInfo();
    }
  }

  void _checkScannedStatus() {
    final scannedIn = widget.tagData['scanned_in'];
    isScannedIn = scannedIn == 1 || scannedIn == '1' || scannedIn == true;
  }

  void _validateData() {
    final idTag = _getValue(['id_tag_ok', 'labelbox_id']);
    final partNumber = _getValue(['part_number', 'part_no']);

    if (idTag == '-' || partNumber == '-') {
      hasValidData = false;
    }
  }

  String _getQtyValue() {
    return widget.tagData['qty_kbn']?.toString() ?? '0';
  }

  /// Load stock info for the part number
  Future<void> _loadStockInfo() async {
    final partNumber = _getValue(['part_number', 'part_no']);
    if (partNumber == '-') return;

    setState(() {
      isLoadingStock = true;
    });

    try {
      final result = await ScanInService.getStockInfo(partNumber, widget.area);

      if (mounted) {
        setState(() {
          stockInfo = result;
          isLoadingStock = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          stockInfo = null;
          isLoadingStock = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _qtyController.dispose();
    super.dispose();
  }

  Future<void> _handleUpload() async {
    // Double check permission
    if (!widget.canInput) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Anda tidak memiliki akses untuk upload'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_qtyController.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Qty tidak boleh kosong')));
      return;
    }

    setState(() {
      isSubmitting = true;
    });

    try {
      final result = await ScanInService.scanInTag(
        nik: widget.nik,
        idTag: widget.tagData['id_tag_ok'] ?? widget.tagData['labelbox_id'],
        qty: _qtyController.text,
        area: widget.area,
      );

      // Reload stock info after successful upload
      Map<String, dynamic>? updatedStockInfo;
      if (result['success'] == true) {
        final partNumber = _getValue(['part_number', 'part_no']);
        if (partNumber != '-') {
          updatedStockInfo = await ScanInService.getStockInfo(
            partNumber,
            widget.area,
          );
        }
      }

      setState(() {
        isSubmitting = false;
      });

      Navigator.pop(context);

      // Pass result with stock info
      widget.onUpload({
        ...result,
        'stockInfo': updatedStockInfo,
        'partNumber': _getValue(['part_number', 'part_no']),
      });
    } catch (e) {
      setState(() {
        isSubmitting = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  String _getValue(List<String> fieldNames, {String defaultValue = '-'}) {
    for (var field in fieldNames) {
      if (widget.tagData.containsKey(field) &&
          widget.tagData[field] != null &&
          widget.tagData[field].toString().isNotEmpty &&
          widget.tagData[field].toString() != '0000-00-00' &&
          widget.tagData[field].toString() != '0000-00-00 00:00:00') {
        return widget.tagData[field].toString();
      }
    }
    return defaultValue;
  }

  /// Build stock info card
  Widget _buildStockInfoCard() {
    if (isLoadingStock) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.blue.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.blue.shade200),
        ),
        child: const Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 12),
            Text('Memuat info stok...'),
          ],
        ),
      );
    }

    // Don't show stock card if:
    // 1. Stock info is null (API failed)
    // 2. Stock info success is false
    // 3. User is in view-only mode (canInput = false)
    if (stockInfo == null || stockInfo!['success'] != true) {
      // Only show error/empty state if user can input
      if (widget.canInput) {
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(
                Icons.inventory_2_outlined,
                color: Colors.grey.shade500,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Info stok tidak tersedia',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ),
            ],
          ),
        );
      }
      return const SizedBox.shrink();
    }

    final data = stockInfo!['data'];
    final totalBalance = data['total_balance'] ?? 0;
    final stocks = data['stocks'] as List? ?? [];

    // Filter only available stocks (balance > 0)
    final availableStocks = stocks.where((s) {
      final balance = int.tryParse(s['balance']?.toString() ?? '0') ?? 0;
      return balance > 0;
    }).toList();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Icon(Icons.inventory, color: Colors.green.shade700, size: 20),
              const SizedBox(width: 8),
              Text(
                'Info Stok',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.green.shade800,
                  fontSize: 14,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.green.shade600,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Total: $totalBalance',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),

          // Available stock details
          if (availableStocks.isNotEmpty) ...[
            const SizedBox(height: 8),
            const Divider(height: 1),
            const SizedBox(height: 8),
            Text(
              'Stok Tersedia (${availableStocks.length} tag):',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: Colors.green.shade700,
              ),
            ),
            const SizedBox(height: 6),
            ...availableStocks.take(3).map((stock) {
              final tagId = stock['id_tag_ok'] ?? '-';
              final balance = stock['balance'] ?? '0';
              final status = stock['stock_status'] ?? '-';

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    Icon(
                      Icons.label_outline,
                      size: 14,
                      color: Colors.green.shade500,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        tagId.toString(),
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.green.shade700,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: status == 'TERSEDIA'
                            ? Colors.green.shade100
                            : Colors.orange.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        balance.toString(),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: status == 'TERSEDIA'
                              ? Colors.green.shade800
                              : Colors.orange.shade800,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
            if (availableStocks.length > 3)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '+ ${availableStocks.length - 3} tag lainnya',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.green.shade600,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
          ] else ...[
            const SizedBox(height: 8),
            Text(
              'Semua stok sudah habis',
              style: TextStyle(
                fontSize: 11,
                color: Colors.green.shade600,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }

  List<Widget> _buildEssentialFields() {
    List<Widget> fields = [];

    if (widget.area == 'IFPD') {
      fields.add(
        _buildInfoRow(
          'Tag ID',
          _getValue(['id_tag_ok', 'labelbox_id']),
          Icons.qr_code,
        ),
      );
      fields.add(const SizedBox(height: 12));

      fields.add(
        _buildInfoRow(
          'Part Number',
          _getValue(['part_number', 'part_no']),
          Icons.inventory,
        ),
      );
      fields.add(const SizedBox(height: 12));

      fields.add(
        _buildInfoRow(
          'Job Number',
          _getValue(['job_number', 'job_no']),
          Icons.work_outline,
        ),
      );
      fields.add(const SizedBox(height: 12));

      fields.add(
        _buildInfoRow('Date', _getValue(['date']), Icons.calendar_today),
      );
      fields.add(const SizedBox(height: 12));

      fields.add(
        _buildInfoRow('Customer', _getValue(['customer']), Icons.business),
      );
    } else if (widget.area == 'IFPP') {
      fields.add(
        _buildInfoRow(
          'Tag ID',
          _getValue(['id_tag_ok', 'labelbox_id']),
          Icons.qr_code,
        ),
      );
      fields.add(const SizedBox(height: 12));

      fields.add(
        _buildInfoRow(
          'Part Number',
          _getValue(['part_number', 'part_no']),
          Icons.inventory,
        ),
      );
      fields.add(const SizedBox(height: 12));

      fields.add(
        _buildInfoRow(
          'Job Number',
          _getValue(['job_no', 'job_number']),
          Icons.work_outline,
        ),
      );
      fields.add(const SizedBox(height: 12));

      fields.add(
        _buildInfoRow(
          'Arrival Date',
          _getValue(['arrival_date', 'date']),
          Icons.calendar_today,
        ),
      );
      fields.add(const SizedBox(height: 12));

      fields.add(
        _buildInfoRow('Supplier', _getValue(['supplier']), Icons.factory),
      );
    } else {
      // Default fields for other areas (IFRM, etc)
      fields.add(
        _buildInfoRow(
          'Tag ID',
          _getValue(['id_tag_ok', 'labelbox_id']),
          Icons.qr_code,
        ),
      );
      fields.add(const SizedBox(height: 12));

      fields.add(
        _buildInfoRow(
          'Part Number',
          _getValue(['part_number', 'part_no']),
          Icons.inventory,
        ),
      );
      fields.add(const SizedBox(height: 12));

      fields.add(
        _buildInfoRow(
          'Job Number',
          _getValue(['job_number', 'job_no']),
          Icons.work_outline,
        ),
      );
    }

    return fields;
  }

  Widget _buildScannedInContent() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.green.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.green.shade200),
          ),
          child: Column(
            children: [
              Icon(
                Icons.check_circle_outline,
                size: 48,
                color: Colors.green.shade600,
              ),
              const SizedBox(height: 12),
              Text(
                'Tag Sudah Di-Scan',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.green.shade800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'ID Tag ini sudah pernah di-scan sebelumnya',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.green.shade700),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        _buildInfoRow(
          'Tag ID',
          _getValue(['id_tag_ok', 'labelbox_id']),
          Icons.qr_code,
        ),
      ],
    );
  }

  Widget _buildInvalidDataContent() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Column(
        children: [
          Icon(Icons.error_outline, size: 48, color: Colors.red.shade600),
          const SizedBox(height: 12),
          Text(
            'Data Tidak Valid',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.red.shade800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tag ID atau Part Number tidak ditemukan',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Colors.red.shade700),
          ),
        ],
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
                  'Anda hanya dapat melihat data tanpa melakukan upload',
                  style: TextStyle(color: Colors.orange.shade700, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Determine if upload should be shown
    final bool showUploadButton =
        !isScannedIn && hasValidData && widget.canInput;
    final bool showViewOnlyInfo =
        !isScannedIn && hasValidData && !widget.canInput;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Detail Tag',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(),
              const SizedBox(height: 10),

              // Area Badge dengan permission indicator
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Area: ${widget.area}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue.shade700,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Permission badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: widget.canInput
                          ? Colors.green.shade50
                          : Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: widget.canInput
                            ? Colors.green.shade200
                            : Colors.orange.shade200,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          widget.canInput ? Icons.edit : Icons.visibility,
                          size: 12,
                          color: widget.canInput
                              ? Colors.green.shade700
                              : Colors.orange.shade700,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          widget.canInput ? 'Input' : 'View',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: widget.canInput
                                ? Colors.green.shade700
                                : Colors.orange.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // View only banner (if applicable)
              if (showViewOnlyInfo) ...[
                _buildViewOnlyBanner(),
                const SizedBox(height: 16),
              ],

              // Content based on status
              if (isScannedIn)
                _buildScannedInContent()
              else if (!hasValidData)
                _buildInvalidDataContent()
              else ...[
                // Show essential fields
                ..._buildEssentialFields(),
                const SizedBox(height: 12),

                // Stock Info Card (show for input mode, hide if API fails for view mode)
                _buildStockInfoCard(),
                const SizedBox(height: 12),

                // Qty Input (only if can input)
                if (widget.canInput) ...[
                  Row(
                    children: [
                      const Icon(Icons.shopping_cart, color: Colors.grey),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Quantity',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 4),
                            TextField(
                              controller: _qtyController,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                hintText: 'Masukkan qty',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  // Show qty as read-only info
                  _buildInfoRow(
                    'Quantity',
                    _getQtyValue(),
                    Icons.shopping_cart,
                  ),
                ],
              ],

              const SizedBox(height: 20),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: isSubmitting
                          ? null
                          : () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text('Tutup'),
                    ),
                  ),
                  if (showUploadButton) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: isSubmitting ? null : _handleUpload,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: isSubmitting
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.upload, size: 18),
                                  SizedBox(width: 6),
                                  Text('Upload'),
                                ],
                              ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, IconData icon) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Colors.grey),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
