import 'package:flutter/material.dart';
import '../services/scan_sto.dart';

class ScanStoManualModal extends StatefulWidget {
  final String area;
  final String nik;
  final Function(Map<String, dynamic> result) onSubmit;

  const ScanStoManualModal({
    super.key,
    required this.area,
    required this.nik,
    required this.onSubmit,
  });

  @override
  State<ScanStoManualModal> createState() => _ScanStoManualModalState();
}

class _ScanStoManualModalState extends State<ScanStoManualModal> {
  final TextEditingController _qtyController = TextEditingController();
  List<Map<String, dynamic>> partList = [];
  String? selectedPartNumber;
  bool isLoading = false;
  bool isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadPartData();
  }

  Future<void> _loadPartData() async {
    setState(() {
      isLoading = true;
    });

    try {
      final parts = await ScanStoService.getPartData(widget.area);
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

  Future<void> _handleSubmit() async {
    if (selectedPartNumber == null) {
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
      final result = await ScanStoService.manualInput(
        nik: widget.nik,
        partNumber: selectedPartNumber!,
        qty: _qtyController.text,
        area: widget.area,
      );

      setState(() {
        isSubmitting = false;
      });

      // Close modal and pass result to parent
      Navigator.pop(context);
      widget.onSubmit(result);
    } catch (e) {
      setState(() {
        isSubmitting = false;
      });

      // Close modal and pass error to parent
      Navigator.pop(context);
      widget.onSubmit({
        'success': false,
        'statusCode': 0,
        'message': 'Error: ${e.toString()}',
        'data': null,
      });
    }
  }

  @override
  void dispose() {
    _qtyController.dispose();
    super.dispose();
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
                    'Input Manual',
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

              // Area Badge
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
              const SizedBox(height: 20),

              // Part Number Dropdown
              const Text(
                'Part Number / Job Number',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              isLoading
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16.0),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  : DropdownButtonFormField<String>(
                      initialValue: selectedPartNumber,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        hintText: 'Pilih Part Number',
                      ),
                      items: partList.map((part) {
                        return DropdownMenuItem<String>(
                          value:
                              part['part_number']?.toString() ??
                              part['job_number']?.toString(),
                          child: Text(
                            part['part_number']?.toString() ??
                                part['job_number']?.toString() ??
                                'Unknown',
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          selectedPartNumber = value;
                        });
                      },
                    ),
              const SizedBox(height: 16),

              // Qty Input
              const Text(
                'Quantity',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _qtyController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  hintText: 'Masukkan quantity',
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
                        padding: const EdgeInsets.symmetric(vertical: 12),
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
