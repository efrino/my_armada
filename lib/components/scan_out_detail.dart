import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/scan_out.dart';

class ScanOutModal extends StatefulWidget {
  final Map<String, dynamic> tagData;
  final String area;
  final String nik;
  final bool canInput; // NEW: Permission flag untuk input
  final Function(Map<String, dynamic> result) onUpload;

  const ScanOutModal({
    super.key,
    required this.tagData,
    required this.area,
    required this.nik,
    this.canInput = true, // Default true untuk backward compatibility
    required this.onUpload,
  });

  @override
  State<ScanOutModal> createState() => _ScanOutModalState();
}

class _ScanOutModalState extends State<ScanOutModal> {
  late TextEditingController _qtyController;
  bool isSubmitting = false;
  bool isLoadingStock = false;
  Map<String, dynamic>? stockInfo;
  String? partNumber;

  @override
  void initState() {
    super.initState();
    _qtyController = TextEditingController();
    _extractPartNumber();
    _loadStockInfo();
  }

  void _extractPartNumber() {
    partNumber = widget.tagData['part_number'] ?? widget.tagData['part_no'];
  }

  Future<void> _loadStockInfo() async {
    if (partNumber == null || partNumber!.isEmpty) return;

    setState(() {
      isLoadingStock = true;
    });

    try {
      final info = await ScanOutService.getStockInfo(partNumber!, widget.area);

      if (mounted) {
        setState(() {
          stockInfo = info;
          isLoadingStock = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isLoadingStock = false;
        });
      }
      debugPrint('Error loading stock info: $e');
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
      _showError('Anda tidak memiliki akses untuk scan out');
      return;
    }

    // Validasi qty
    if (_qtyController.text.isEmpty) {
      _showError('Quantity harus diisi');
      return;
    }

    final qty = num.tryParse(_qtyController.text);
    if (qty == null || qty <= 0) {
      _showError('Quantity harus berupa angka positif');
      return;
    }

    // Validasi part_number
    if (partNumber == null || partNumber!.isEmpty) {
      _showError('Part number tidak ditemukan');
      return;
    }

    setState(() {
      isSubmitting = true;
    });

    try {
      final result = await ScanOutService.scanOutTag(
        nik: widget.nik,
        partNumber: partNumber!,
        area: widget.area,
        qty: qty,
      );

      // Reload stock info after successful scan out
      Map<String, dynamic>? updatedStockInfo;
      if (result['success'] == true && partNumber != null) {
        updatedStockInfo = await ScanOutService.getStockInfo(partNumber!, widget.area);
      }

      setState(() {
        isSubmitting = false;
      });

      if (mounted) {
        Navigator.pop(context);
        widget.onUpload({
          ...result,
          'stockInfo': updatedStockInfo,
          'partNumber': partNumber,
        });
      }
    } catch (e) {
      setState(() {
        isSubmitting = false;
      });
      if (mounted) {
        _showError('Error: $e');
      }
    }
  }

  void _showError(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 2),
      ),
    );
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

  List<Widget> _buildDynamicFields() {
    List<Widget> fields = [];

    // Tag ID - Always show
    fields.add(
      _buildInfoRow(
        'Tag ID (Scanned)',
        _getValue(['id_tag_ok', 'labelbox_id', 'id_kanban']),
        Icons.qr_code,
      ),
    );
    fields.add(const SizedBox(height: 12));

    // Part Number (CRITICAL - untuk scan out)
    fields.add(
      _buildInfoRow(
        'Part Number',
        partNumber ?? '-',
        Icons.inventory,
        highlight: true,
      ),
    );
    fields.add(const SizedBox(height: 12));

    // Part Name/Description
    if (widget.area == 'IFRM' || widget.area == 'IFPP') {
      String partDesc = _getValue(['part_name', 'part_desc']);
      if (partDesc != '-') {
        fields.add(
          _buildInfoRow(
            widget.area == 'IFRM' ? 'Part Name' : 'Part Description',
            partDesc,
            Icons.description,
          ),
        );
        fields.add(const SizedBox(height: 12));
      }
    }

    // Job Number
    String jobNumber = _getValue(['job_number', 'job_no']);
    if (jobNumber != '-') {
      fields.add(_buildInfoRow('Job Number', jobNumber, Icons.work_outline));
      fields.add(const SizedBox(height: 12));
    }

    return fields;
  }

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

    if (stockInfo == null || stockInfo!['success'] != true) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.orange.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.orange.shade200),
        ),
        child: Row(
          children: [
            Icon(Icons.warning_amber, color: Colors.orange.shade700, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Stok tidak tersedia atau belum ada',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.orange.shade700,
                ),
              ),
            ),
          ],
        ),
      );
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
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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

  /// NEW: Banner untuk view-only mode
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
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Mode View Only',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.orange.shade800,
                    fontSize: 12,
                  ),
                ),
                Text(
                  'Anda hanya bisa melihat data, tidak bisa scan out',
                  style: TextStyle(
                    color: Colors.orange.shade700,
                    fontSize: 11,
                  ),
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
    // Determine if scan out should be shown
    final bool showScanOutButton = widget.canInput;
    final bool showViewOnlyInfo = !widget.canInput;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Scan Out',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: isSubmitting
                        ? null
                        : () => Navigator.pop(context),
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

              // Dynamic Fields
              ..._buildDynamicFields(),

              const Divider(height: 24),

              // Stock Info Card
              _buildStockInfoCard(),

              const SizedBox(height: 16),

              // Qty Input (only if can input)
              if (showScanOutButton) ...[
                Row(
                  children: [
                    const Icon(Icons.shopping_cart, color: Colors.grey),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Quantity Scan Out',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                          const SizedBox(height: 4),
                          TextField(
                            controller: _qtyController,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
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
                              suffixIcon: _qtyController.text.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear, size: 18),
                                      onPressed: () {
                                        _qtyController.clear();
                                        setState(() {});
                                      },
                                    )
                                  : null,
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
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
                  if (showScanOutButton) ...[
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
                                  Icon(Icons.output, size: 18),
                                  SizedBox(width: 6),
                                  Text('Scan Out'),
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

  Widget _buildInfoRow(
    String label,
    String value,
    IconData icon, {
    bool highlight = false,
  }) {
    return Container(
      padding: highlight ? const EdgeInsets.all(8) : null,
      decoration: highlight
          ? BoxDecoration(
              color: Colors.amber.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.amber.shade200),
            )
          : null,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 20,
            color: highlight ? Colors.amber.shade700 : Colors.grey,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: highlight ? Colors.amber.shade700 : Colors.grey,
                    fontWeight: highlight ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: highlight ? Colors.amber.shade900 : Colors.black,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}