import 'package:flutter/material.dart';
import '../services/scan_sto.dart';

class StoManualInputModal extends StatefulWidget {
  final String group;
  final String nik;
  final bool canInput;
  final Function(Map<String, dynamic> tagData) onTagFound;

  const StoManualInputModal({
    super.key,
    required this.group,
    required this.nik,
    required this.canInput,
    required this.onTagFound,
  });

  @override
  State<StoManualInputModal> createState() => _StoManualInputModalState();
}

class _StoManualInputModalState extends State<StoManualInputModal> {
  final _codeController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool isLoading = false;
  String? errorMessage;

  Color get groupColor {
    return widget.group.toUpperCase() == 'A' ? Colors.blue : Colors.orange;
  }

  Future<void> _handleSearch() async {
    if (!_formKey.currentState!.validate()) return;

    final code = _codeController.text.trim().toUpperCase();

    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final tagData = await ScanStoService.getTagData(code);

      if (!mounted) return;

      setState(() {
        isLoading = false;
      });

      if (tagData != null) {
        widget.onTagFound(tagData);
      } else {
        setState(() {
          errorMessage = 'Tag "$code" tidak ditemukan';
        });
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
        errorMessage = 'Error: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.keyboard, color: groupColor),
                        const SizedBox(width: 8),
                        const Text(
                          'Input Manual',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const Divider(),
                const SizedBox(height: 16),

                // Group Badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: groupColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: groupColor),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.group_work, color: groupColor, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        'Group ${widget.group}',
                        style: TextStyle(
                          color: groupColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Instructions
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.grey.shade600),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Masukkan kode Tag STO jika QR Code tidak terbaca.\nContoh: A12345',
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Input Field
                TextFormField(
                  controller: _codeController,
                  textCapitalization: TextCapitalization.characters,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: 'Kode Tag STO',
                    hintText: 'Contoh: A12345',
                    prefixIcon: Icon(Icons.qr_code, color: groupColor),
                    suffixIcon: _codeController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _codeController.clear();
                              setState(() {
                                errorMessage = null;
                              });
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: groupColor, width: 2),
                    ),
                    errorText: errorMessage,
                  ),
                  onChanged: (_) {
                    setState(() {
                      errorMessage = null;
                    });
                  },
                  onFieldSubmitted: (_) => _handleSearch(),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Kode tidak boleh kosong';
                    }
                    if (value.trim().length < 2) {
                      return 'Kode minimal 2 karakter';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),

                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: isLoading
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
                        onPressed: isLoading ? null : _handleSearch,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: groupColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: isLoading
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
                                  Icon(Icons.search, size: 18),
                                  SizedBox(width: 6),
                                  Text('Cari Tag'),
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
      ),
    );
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }
}
