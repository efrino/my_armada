import 'package:flutter/material.dart';
import '../services/scan_sto.dart';

class DetailTagModal extends StatefulWidget {
  final Map<String, dynamic> tagData;
  final String area;
  final String nik;
  final Function(Map<String, dynamic> result) onUpload;
  const DetailTagModal({
    super.key,
    required this.tagData,
    required this.area,
    required this.nik,
    required this.onUpload,
  });

  @override
  State<DetailTagModal> createState() => _DetailTagModalState();
}

class _DetailTagModalState extends State<DetailTagModal> {
  bool isSubmitting = false;
  bool isScannedOut = false;

  @override
  void initState() {
    super.initState();
    _checkScannedStatus();
  }

  void _checkScannedStatus() {
    // Check if already scanned out
    final scannedOut = widget.tagData['scanned_out'];
    isScannedOut = scannedOut == 1 || scannedOut == '1' || scannedOut == true;
  }

  String _getQtyValue() {
    // Try different possible qty field names
    return widget.tagData['qty']?.toString() ??
        widget.tagData['qty_kbn']?.toString() ??
        widget.tagData['qty_per_kbn']?.toString() ??
        '0';
  }

  Future<void> _handleUpload() async {
    setState(() {
      isSubmitting = true;
    });

    try {
      final result = await ScanStoService.scanStoTag(
        nik: widget.nik,
        idTag: widget.tagData['id_tag_ok'] ?? widget.tagData['labelbox_id'],
        area: widget.area,
        qty: widget.area
      );

      setState(() {
        isSubmitting = false;
      });

      // Close modal and pass result to parent
      if (mounted) {
        Navigator.pop(context);
        widget.onUpload(result);
      }
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

  // Get field value with fallback
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
        'Tag ID',
        _getValue(['id_tag_ok', 'labelbox_id']),
        Icons.qr_code,
      ),
    );
    fields.add(const SizedBox(height: 12));

    // Part Number
    fields.add(
      _buildInfoRow(
        'Part Number',
        _getValue(['part_number', 'part_no']),
        Icons.inventory,
      ),
    );
    fields.add(const SizedBox(height: 12));

    // Part Name/Description - For IFPD and IFPP
    if (widget.area == 'IFPD' || widget.area == 'IFPP') {
      String partDesc = _getValue(['part_name', 'part_desc']);
      if (partDesc != '-') {
        fields.add(
          _buildInfoRow(
            widget.area == 'IFPD' ? 'Part Name' : 'Part Description',
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

    // Date
    fields.add(
      _buildInfoRow(
        widget.area == 'IFPP' ? 'Arrival Date' : 'Date',
        _getValue(['date', 'arrival_date']),
        Icons.calendar_today,
      ),
    );
    fields.add(const SizedBox(height: 12));

    // IFPD Specific Fields
    if (widget.area == 'IFPD') {
      // Shift
      String shift = _getValue(['shift']);
      if (shift != '-') {
        fields.add(_buildInfoRow('Shift', shift, Icons.access_time));
        fields.add(const SizedBox(height: 12));
      }

      // Line ID
      String lineId = _getValue(['line_id']);
      if (lineId != '-') {
        fields.add(_buildInfoRow('Line ID', lineId, Icons.line_style));
        fields.add(const SizedBox(height: 12));
      }

      // Status
      String status = _getValue(['status']);
      if (status != '-') {
        fields.add(_buildInfoRow('Status', status, Icons.info_outline));
        fields.add(const SizedBox(height: 12));
      }

      // Project
      String project = _getValue(['project']);
      if (project != '-') {
        fields.add(_buildInfoRow('Project', project, Icons.folder_outlined));
        fields.add(const SizedBox(height: 12));
      }

      // Customer
      String customer = _getValue(['customer']);
      if (customer != '-') {
        fields.add(_buildInfoRow('Customer', customer, Icons.business));
        fields.add(const SizedBox(height: 12));
      }
    }

    // IFPP Specific Fields
    if (widget.area == 'IFPP') {
      // PO Number
      String poNo = _getValue(['po_no']);
      if (poNo != '-' && poNo != '2147483647') {
        fields.add(_buildInfoRow('PO Number', poNo, Icons.receipt_long));
        fields.add(const SizedBox(height: 12));
      }

      // PO Item
      String poItem = _getValue(['po_item']);
      if (poItem != '-') {
        fields.add(_buildInfoRow('PO Item', poItem, Icons.list_alt));
        fields.add(const SizedBox(height: 12));
      }

      // DN Number
      String dnNo = _getValue(['dn_no']);
      if (dnNo != '-') {
        fields.add(_buildInfoRow('DN Number', dnNo, Icons.document_scanner));
        fields.add(const SizedBox(height: 12));
      }

      // Supplier
      String supplier = _getValue(['supplier']);
      if (supplier != '-') {
        fields.add(_buildInfoRow('Supplier', supplier, Icons.factory));
        fields.add(const SizedBox(height: 12));
      }

      // Model
      String model = _getValue(['model']);
      if (model != '-') {
        fields.add(_buildInfoRow('Model', model, Icons.directions_car));
        fields.add(const SizedBox(height: 12));
      }
    }

    return fields;
  }

  @override
  Widget build(BuildContext context) {
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

              // Area Badge and Status
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
                  if (isScannedOut)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.check_circle,
                            size: 14,
                            color: Colors.green.shade700,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Scanned Out',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.green.shade700,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 20),

              // Dynamic Fields based on area
              ..._buildDynamicFields(),

              // Qty (Display only - not editable)
              _buildInfoRow('Quantity', _getQtyValue(), Icons.shopping_cart),

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
                      onPressed: (!isScannedOut && !isSubmitting)
                          ? _handleUpload
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
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.upload, size: 18),
                                const SizedBox(width: 6),
                                Text(
                                  isScannedOut ? 'Sudah Terupload' : 'Upload',
                                ),
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
