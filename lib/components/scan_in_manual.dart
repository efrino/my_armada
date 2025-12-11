import 'package:flutter/material.dart';
import '../services/scan_in.dart';
import '../utils/permission_manager.dart';
import '../utils/permissions.dart';

class ScanInManualModal extends StatefulWidget {
  final String area;
  final String nik;
  final Function(Map<String, dynamic> result) onSubmit;

  const ScanInManualModal({
    super.key,
    required this.area,
    required this.nik,
    required this.onSubmit,
  });

  @override
  State<ScanInManualModal> createState() => _ScanInManualModalState();
}

class _ScanInManualModalState extends State<ScanInManualModal> {
  final TextEditingController _qtyController = TextEditingController();
  List<Map<String, dynamic>> partList = [];
  Map<String, dynamic>? selectedPart;
  bool isLoading = false;
  bool isSubmitting = false;
  
  // Stock info state
  bool isLoadingStock = false;
  Map<String, dynamic>? stockInfo;

  /// Check if user has input permission for the current area
  bool get hasInputPermission {
    if (permissionManager.isAdmin) return true;

    switch (widget.area) {
      case 'IFPD':
        return permissionManager.hasPermission(AppPermissions.inputScanInIfpd);
      case 'IFPP':
        return permissionManager.hasPermission(AppPermissions.inputScanInIfpp);
      case 'IFRM':
        return permissionManager.hasPermission(AppPermissions.inputScanInIfrm);
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
            content: Text(
              'Anda tidak memiliki akses input di area ${widget.area}',
            ),
            backgroundColor: Colors.red,
          ),
        );
      });
      return;
    }

    _loadPartData();
  }

  Future<void> _loadPartData() async {
    setState(() {
      isLoading = true;
    });

    try {
      final parts = await ScanInService.getPartData(widget.area);
      setState(() {
        partList = parts;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading part data: $e')));
      }
    }
  }

  Future<void> _showPartSelectionModal() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _PartSelectionModal(partList: partList),
    );

    if (result != null) {
      setState(() {
        selectedPart = result;
        stockInfo = null; // Reset stock info
      });
      // Load stock info for selected part
      _loadStockInfo();
    }
  }

  /// Load stock info for selected part number
  Future<void> _loadStockInfo() async {
    if (selectedPart == null) return;
    
    final partNumber = selectedPart!['part_number']?.toString() ?? 
                       selectedPart!['job_number']?.toString() ?? '';
    
    if (partNumber.isEmpty) return;

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

  /// Build stock info card
  Widget _buildStockInfoCard() {
    if (selectedPart == null) {
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

    // Don't show if stock info failed
    if (stockInfo == null || stockInfo!['success'] != true) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(Icons.inventory_2_outlined, color: Colors.grey.shade500, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Info stok tidak tersedia',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
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

  Future<void> _handleSubmit() async {
    // Final permission check before submit
    if (!hasInputPermission) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Anda tidak memiliki akses input di area ${widget.area}',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (selectedPart == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih part number terlebih dahulu')),
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
      final partNumber =
          selectedPart!['part_number']?.toString() ??
          selectedPart!['job_number']?.toString() ??
          '';

      final result = await ScanInService.manualInput(
        nik: widget.nik,
        partNumber: partNumber,
        qty: _qtyController.text,
        area: widget.area,
      );

      // Fetch stock info after successful upload
      Map<String, dynamic>? stockInfo;
      if (result['success'] == true && partNumber.isNotEmpty) {
        stockInfo = await ScanInService.getStockInfo(partNumber, widget.area);
      }

      setState(() {
        isSubmitting = false;
      });

      if (mounted) {
        Navigator.pop(context);
        widget.onSubmit({
          ...result,
          'stockInfo': stockInfo,
          'partNumber': partNumber,
        });
      }
    } catch (e) {
      setState(() {
        isSubmitting = false;
      });

      if (mounted) {
        Navigator.pop(context);
        widget.onSubmit({
          'success': false,
          'statusCode': 0,
          'message': 'Error: ${e.toString()}',
          'data': null,
          'stockInfo': null,
          'partNumber': null,
        });
      }
    }
  }

  @override
  void dispose() {
    _qtyController.dispose();
    super.dispose();
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
                    'Input Manual',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 8),

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
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.location_on,
                          size: 14,
                          color: Colors.blue.shade700,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Area: ${widget.area}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.blue.shade700,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
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
              const Text(
                'Part Number / Job Number',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),

              if (isLoading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32.0),
                    child: CircularProgressIndicator(),
                  ),
                )
              else
                InkWell(
                  onTap: _showPartSelectionModal,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.search, color: Colors.grey.shade600),
                        const SizedBox(width: 12),
                        Expanded(
                          child: selectedPart == null
                              ? Text(
                                  'Pilih part number...',
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 14,
                                  ),
                                )
                              : Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      selectedPart!['part_number']
                                              ?.toString() ??
                                          selectedPart!['job_number']
                                              ?.toString() ??
                                          '-',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                    if (selectedPart!['part_name'] != null)
                                      Text(
                                        selectedPart!['part_name'].toString(),
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                  ],
                                ),
                        ),
                        Icon(
                          Icons.arrow_forward_ios,
                          size: 16,
                          color: Colors.grey.shade600,
                        ),
                      ],
                    ),
                  ),
                ),

              const SizedBox(height: 20),

              // Stock Info Card (show after part selected)
              if (selectedPart != null) ...[
                _buildStockInfoCard(),
                const SizedBox(height: 20),
              ],

              // Qty Input
              const Text(
                'Quantity',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _qtyController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  hintText: 'Masukkan quantity',
                  prefixIcon: const Icon(Icons.inventory_2_outlined),
                ),
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
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Batal'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: isSubmitting ? null : _handleSubmit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
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
                          : const Text('Submit'),
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

// Modal untuk memilih part number dengan flexible search
class _PartSelectionModal extends StatefulWidget {
  final List<Map<String, dynamic>> partList;

  const _PartSelectionModal({required this.partList});

  @override
  State<_PartSelectionModal> createState() => _PartSelectionModalState();
}

class _PartSelectionModalState extends State<_PartSelectionModal> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> filteredPartList = [];

  @override
  void initState() {
    super.initState();
    filteredPartList = widget.partList;
    _searchController.addListener(_filterParts);
  }

  /// Flexible search - karakter tidak harus berurutan
  /// Contoh: query "abc" akan match dengan "aXbXc", "a1b2c3", "cab", dll
  bool _flexibleMatch(String target, String query) {
    if (query.isEmpty) return true;
    if (target.isEmpty) return false;

    final targetLower = target.toLowerCase();
    final queryLower = query.toLowerCase().replaceAll(' ', ''); // Abaikan spasi

    // Setiap karakter di query harus ada di target (tidak harus urut)
    // Menggunakan pendekatan: setiap karakter query "dikonsumsi" dari target
    var remaining = targetLower;

    for (var char in queryLower.split('')) {
      final index = remaining.indexOf(char);
      if (index == -1) {
        return false; // Karakter tidak ditemukan
      }
      // Hapus karakter yang sudah match agar tidak di-match lagi
      remaining = remaining.substring(0, index) + remaining.substring(index + 1);
    }

    return true;
  }

  void _filterParts() {
    final query = _searchController.text;
    setState(() {
      if (query.isEmpty) {
        filteredPartList = widget.partList;
      } else {
        filteredPartList = widget.partList.where((part) {
          final partNumber = (part['part_number'] ?? '').toString();
          final jobNumber = (part['job_number'] ?? '').toString();
          final partName = (part['part_name'] ?? '').toString();

          return _flexibleMatch(partNumber, query) ||
              _flexibleMatch(jobNumber, query) ||
              _flexibleMatch(partName, query);
        }).toList();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.75,
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Pilih Part Number',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Search Box
            TextField(
              controller: _searchController,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Cari part number (tidak harus urut)...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () => _searchController.clear(),
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
            ),
            const SizedBox(height: 8),

            // Search hint
            Align(
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
            const SizedBox(height: 4),

            // Items count
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '${filteredPartList.length} items ditemukan',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ),
            const SizedBox(height: 8),

            const Divider(height: 1),

            // List
            Expanded(
              child: filteredPartList.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.search_off,
                            size: 64,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Tidak ada data ditemukan',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Coba kata kunci lain',
                            style: TextStyle(
                              color: Colors.grey.shade500,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.only(top: 8),
                      itemCount: filteredPartList.length,
                      separatorBuilder: (context, index) =>
                          const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final part = filteredPartList[index];
                        return InkWell(
                          onTap: () => Navigator.pop(context, part),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 12,
                            ),
                            child: Row(
                              children: [
                                // Icon
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.shade50,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    Icons.qr_code_2,
                                    size: 24,
                                    color: Colors.blue.shade700,
                                  ),
                                ),
                                const SizedBox(width: 12),

                                // Content
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        part['part_number']?.toString() ??
                                            part['job_number']?.toString() ??
                                            '-',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                      if (part['part_name'] != null) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          part['part_name'].toString(),
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey.shade600,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ],
                                  ),
                                ),

                                // Qty Badge
                                if (part['qty_kbn'] != null) ...[
                                  const SizedBox(width: 12),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.orange.shade100,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Column(
                                      children: [
                                        Text(
                                          'Qty',
                                          style: TextStyle(
                                            fontSize: 9,
                                            color: Colors.orange.shade900,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        Text(
                                          part['qty_kbn'].toString(),
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.orange.shade900,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
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