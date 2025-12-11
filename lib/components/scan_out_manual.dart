import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/scan_out.dart';
import '../utils/permission_manager.dart';
import '../utils/permissions.dart';

class ScanOutManualModal extends StatefulWidget {
  final String area;
  final String nik;
  final Function(Map<String, dynamic> result) onSubmit;

  const ScanOutManualModal({
    super.key,
    required this.area,
    required this.nik,
    required this.onSubmit,
  });

  @override
  State<ScanOutManualModal> createState() => _ScanOutManualModalState();
}

class _ScanOutManualModalState extends State<ScanOutManualModal> {
  final TextEditingController _qtyController = TextEditingController();
  bool isSubmitting = false;
  bool isLoadingStock = false;
  bool isLoadingParts = false;
  Map<String, dynamic>? stockInfo;
  List<Map<String, dynamic>> partList = [];
  String? selectedPartNumber;

  /// Check if user has input permission for the current area
  bool get hasInputPermission {
    if (permissionManager.isAdmin) return true;
    
    switch (widget.area) {
      case 'IFPD':
        return permissionManager.hasPermission(AppPermissions.inputScanOutIfpd);
      case 'IFPP':
        return permissionManager.hasPermission(AppPermissions.inputScanOutIfpp);
      case 'IFRM':
        return permissionManager.hasPermission(AppPermissions.inputScanOutIfrm);
      default:
        return false;
    }
  }

  @override
  void initState() {
    super.initState();
    
    // Double check permission on init
    if (!hasInputPermission) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Anda tidak memiliki akses input di area ${widget.area}'),
            backgroundColor: Colors.red,
          ),
        );
      });
      return;
    }
    
    _loadPartList();
  }

  @override
  void dispose() {
    _qtyController.dispose();
    super.dispose();
  }

  Future<void> _loadPartList() async {
    setState(() {
      isLoadingParts = true;
    });

    try {
      final parts = await ScanOutService.getPartData(widget.area);

      if (mounted) {
        setState(() {
          partList = parts;
          isLoadingParts = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isLoadingParts = false;
        });
      }
      debugPrint('Error loading part list: $e');
    }
  }

  void _onPartSelected(String? partNumber) {
    if (partNumber == null) return;

    setState(() {
      selectedPartNumber = partNumber;
      stockInfo = null;
    });

    _loadStockInfo(partNumber);
  }

  Future<void> _loadStockInfo(String partNumber) async {
    if (partNumber.isEmpty) {
      setState(() {
        stockInfo = null;
      });
      return;
    }

    setState(() {
      isLoadingStock = true;
      stockInfo = null;
    });

    try {
      final info = await ScanOutService.getStockInfo(partNumber, widget.area);

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

  Future<void> _handleSubmit() async {
    // Final permission check before submit
    if (!hasInputPermission) {
      _showError('Anda tidak memiliki akses input di area ${widget.area}');
      return;
    }

    final partNumber = selectedPartNumber;
    final qtyText = _qtyController.text.trim();

    if (partNumber == null || partNumber.isEmpty) {
      _showError('Part Number harus diisi');
      return;
    }

    if (qtyText.isEmpty) {
      _showError('Quantity harus diisi');
      return;
    }

    final qty = num.tryParse(qtyText);
    if (qty == null || qty <= 0) {
      _showError('Quantity harus berupa angka positif');
      return;
    }

    setState(() {
      isSubmitting = true;
    });

    try {
      final result = await ScanOutService.scanOutTag(
        nik: widget.nik,
        partNumber: partNumber,
        area: widget.area,
        qty: qty,
      );

      // Reload stock info after successful scan out
      Map<String, dynamic>? updatedStockInfo;
      if (result['success'] == true && partNumber.isNotEmpty) {
        updatedStockInfo = await ScanOutService.getStockInfo(partNumber, widget.area);
      }

      setState(() {
        isSubmitting = false;
      });

      if (mounted) {
        Navigator.pop(context);
        widget.onSubmit({
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

  Widget _buildStockInfoCard() {
    if (selectedPartNumber == null) {
      return const SizedBox.shrink();
    }

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

    if (stockInfo == null) {
      return const SizedBox.shrink();
    }

    if (stockInfo!['success'] != true) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.red.shade200),
        ),
        child: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red.shade700, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Stok tidak ditemukan atau sudah habis',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.red.shade700,
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

  void _showPartPickerDialog() {
    showDialog(
      context: context,
      builder: (context) => _PartPickerDialog(
        partList: partList,
        onSelected: (part) {
          _onPartSelected(part['part_number']);
          Navigator.pop(context);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // If no permission, show nothing (will be closed in initState)
    if (!hasInputPermission) {
      return const SizedBox.shrink();
    }

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
                    'Scan Out Manual',
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

              // Info Card
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue.shade700),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Scan out berbasis Part Number (bukan ID Tag)',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.blue.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Area Badge dengan permission indicator
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.blue.shade400, Colors.blue.shade600],
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Area: ${widget.area}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Input permission badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.edit,
                          size: 12,
                          color: Colors.green.shade700,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Input Mode',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Part Number Selection
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.inventory, color: Colors.grey, size: 20),
                      const SizedBox(width: 8),
                      const Text(
                        'Part Number',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Text(' *', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Loading state
                  if (isLoadingParts)
                    Container(
                      padding: const EdgeInsets.all(12),
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
                          Text('Memuat daftar part...'),
                        ],
                      ),
                    )
                  // Dropdown Button
                  else
                    InkWell(
                      onTap: partList.isEmpty ? null : _showPartPickerDialog,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade400),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                selectedPartNumber ?? 'Pilih Part Number',
                                style: TextStyle(
                                  color: selectedPartNumber != null
                                      ? Colors.black
                                      : Colors.grey.shade600,
                                  fontSize: 14,
                                ),
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
                ],
              ),
              const SizedBox(height: 16),

              // Stock Info Card
              _buildStockInfoCard(),

              if (stockInfo != null && stockInfo!['success'] == true)
                const SizedBox(height: 16),

              // Qty Input
              if (stockInfo != null && stockInfo!['success'] == true)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.shopping_cart,
                          color: Colors.grey,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Quantity',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Text(' *', style: TextStyle(color: Colors.red)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _qtyController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: InputDecoration(
                        hintText: 'Masukkan qty',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
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
                      child: const Text('Batal'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed:
                          (stockInfo != null &&
                              stockInfo!['success'] == true &&
                              !isSubmitting)
                          ? _handleSubmit
                          : null,
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
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =====================================================
// Part Picker Dialog (Searchable List) - REAL-TIME FILTER
// =====================================================
class _PartPickerDialog extends StatefulWidget {
  final List<Map<String, dynamic>> partList;
  final Function(Map<String, dynamic>) onSelected;

  const _PartPickerDialog({required this.partList, required this.onSelected});

  @override
  State<_PartPickerDialog> createState() => _PartPickerDialogState();
}

class _PartPickerDialogState extends State<_PartPickerDialog> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _filteredPartList = [];

  @override
  void initState() {
    super.initState();
    _filteredPartList = widget.partList;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Flexible search - karakter tidak harus berurutan
  /// Contoh: query "abc" akan match dengan "aXbXc", "a1b2c3", "cab", dll
  bool _flexibleMatch(String target, String query) {
    if (query.isEmpty) return true;
    if (target.isEmpty) return false;

    final targetLower = target.toLowerCase();
    final queryLower = query.toLowerCase().replaceAll(' ', ''); // Abaikan spasi

    // Setiap karakter di query harus ada di target (tidak harus urut)
    var remaining = targetLower;

    for (var char in queryLower.split('')) {
      final index = remaining.indexOf(char);
      if (index == -1) {
        return false;
      }
      remaining = remaining.substring(0, index) + remaining.substring(index + 1);
    }

    return true;
  }

  void _filterPartList(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredPartList = widget.partList;
      } else {
        _filteredPartList = widget.partList.where((part) {
          final partNumber = (part['part_number'] ?? '').toString();
          final jobNumber = (part['job_number'] ?? '').toString();
          return _flexibleMatch(partNumber, query) ||
              _flexibleMatch(jobNumber, query);
        }).toList();
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
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Pilih Part Number',
                      style: TextStyle(
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
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Cari part number (tidak harus urut)...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            _filterPartList('');
                          },
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  isDense: true,
                ),
                onChanged: _filterPartList,
              ),
            ),

            const SizedBox(height: 8),

            // Search hint
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Ketik karakter apapun, tidak perlu berurutan',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade500,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ),

            // Result count
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 4,
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _searchController.text.isEmpty
                      ? '${_filteredPartList.length} items tersedia'
                      : 'Ditemukan ${_filteredPartList.length} hasil',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ),
            ),

            const Divider(height: 1),

            // List
            Flexible(
              child: _filteredPartList.isEmpty
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
                                ? 'Tidak ada part yang tersedia'
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
                      itemCount: _filteredPartList.length,
                      itemBuilder: (context, index) {
                        final part = _filteredPartList[index];
                        final partNumber = part['part_number'] ?? '-';
                        final jobNumber = part['job_number'] ?? '';

                        return ListTile(
                          dense: true,
                          title: Text(
                            partNumber,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          subtitle: jobNumber.isNotEmpty
                              ? Text(
                                  'Job: $jobNumber',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                )
                              : null,
                          trailing: const Icon(
                            Icons.chevron_right,
                            color: Colors.grey,
                          ),
                          onTap: () => widget.onSelected(part),
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