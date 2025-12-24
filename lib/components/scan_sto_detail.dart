import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/scan_sto.dart';
import '../utils/helpers.dart';

class StoDetailModal extends StatefulWidget {
  final Map<String, dynamic> tagData;
  final String group;
  final String nik;
  final bool canInput;
  final Function(Map<String, dynamic> result) onSubmit;

  const StoDetailModal({
    super.key,
    required this.tagData,
    required this.group,
    required this.nik,
    required this.canInput,
    required this.onSubmit,
  });

  @override
  State<StoDetailModal> createState() => _StoDetailModalState();
}

class _StoDetailModalState extends State<StoDetailModal> {
  final _qtyController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool isSubmitting = false;

  late Map<String, dynamic> validation;
  bool get isActive => widget.tagData['active']?.toString() == '1';
  bool get canInputQty => validation['canInput'] == true && widget.canInput;

  @override
  void initState() {
    super.initState();
    // Validate tag data for selected group
    validation = ScanStoService.validateTagForGroup(
      widget.tagData,
      widget.group,
    );
  }

  Color get groupColor {
    return widget.group.toUpperCase() == 'A' ? Colors.blue : Colors.orange;
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    final qty = _qtyController.text.trim();

    // Konfirmasi sebelum submit
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.help_outline, color: groupColor),
            const SizedBox(width: 8),
            const Text('Konfirmasi'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Apakah data berikut sudah benar?'),
            const SizedBox(height: 12),
            _buildConfirmRow('Tag', widget.tagData['id_tag'] ?? '-'),
            _buildConfirmRow('Group', widget.group),
            _buildConfirmRow('NIK', widget.nik),
            _buildConfirmRow('Qty', qty),
          ],
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: groupColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('Ya, Simpan'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() {
      isSubmitting = true;
    });

    try {
      final result = await ScanStoService.updateStore(
        nik: widget.nik,
        idTag: widget.tagData['id_tag'] ?? '',
        qty: qty,
        group: widget.group,
      );

      setState(() {
        isSubmitting = false;
      });

      if (mounted) {
        Navigator.pop(context);
        widget.onSubmit(result);
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

  Widget _buildConfirmRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 60,
            child: Text(
              '$label:',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
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
                    const Text(
                      'Detail Tag STO',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const Divider(),
                const SizedBox(height: 10),

                // Group Badge & Status
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: groupColor,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'Group ${widget.group}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: isActive
                            ? Colors.green.shade50
                            : Colors.red.shade50,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isActive ? Icons.check_circle : Icons.cancel,
                            size: 14,
                            color: isActive
                                ? Colors.green.shade700
                                : Colors.red.shade700,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isActive ? 'Aktif' : 'Tidak Aktif',
                            style: TextStyle(
                              fontSize: 12,
                              color: isActive
                                  ? Colors.green.shade700
                                  : Colors.red.shade700,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Validation Message Card
                _buildValidationCard(),
                const SizedBox(height: 16),

                // Tag Info
                _buildInfoSection(),
                const SizedBox(height: 16),

                // Group Data Section
                _buildGroupDataSection(),
                const SizedBox(height: 16),

                // Input Qty (if allowed)
                if (canInputQty) ...[
                  _buildQtyInput(),
                  const SizedBox(height: 20),
                ],

                // Action Buttons
                _buildActionButtons(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildValidationCard() {
    final isError = validation['valid'] != true;
    final canInput = validation['canInput'] == true;

    Color bgColor;
    Color borderColor;
    Color textColor;
    IconData icon;

    if (isError) {
      bgColor = Colors.red.shade50;
      borderColor = Colors.red.shade200;
      textColor = Colors.red.shade700;
      icon = Icons.error_outline;
    } else if (canInput) {
      bgColor = Colors.green.shade50;
      borderColor = Colors.green.shade200;
      textColor = Colors.green.shade700;
      icon = Icons.check_circle_outline;
    } else {
      bgColor = Colors.orange.shade50;
      borderColor = Colors.orange.shade200;
      textColor = Colors.orange.shade700;
      icon = Icons.info_outline;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Icon(icon, color: textColor, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  validation['message'] ?? '',
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (validation['existingDate'] != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Update: ${Helpers.formatDateTime(validation['existingDate'])}',
                    style: TextStyle(
                      color: textColor.withOpacity(0.8),
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Informasi Tag',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade700,
          ),
        ),
        const SizedBox(height: 8),
        _buildInfoRow('Tag ID', widget.tagData['id_tag'] ?? '-', Icons.qr_code),
        const SizedBox(height: 8),
        _buildInfoRow(
          'Part Number',
          widget.tagData['part_number'] ?? '-',
          Icons.inventory,
        ),
        const SizedBox(height: 8),
        _buildInfoRow(
          'Deskripsi',
          widget.tagData['material_description'] ?? '-',
          Icons.description,
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildInfoRow(
                'Area',
                widget.tagData['area'] ?? '-',
                Icons.location_on,
              ),
            ),
            Expanded(
              child: _buildInfoRow(
                'Type',
                widget.tagData['type'] ?? '-',
                Icons.category,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildInfoRow(
                'Customer',
                widget.tagData['customer'] ?? '-',
                Icons.business,
              ),
            ),
            Expanded(
              child: _buildInfoRow(
                'Model',
                widget.tagData['model'] ?? '-',
                Icons.directions_car,
              ),
            ),
          ],
        ),
        if (widget.tagData['job_number'] != null) ...[
          const SizedBox(height: 8),
          _buildInfoRow(
            'Job Number',
            widget.tagData['job_number'] ?? '-',
            Icons.work_outline,
          ),
        ],
      ],
    );
  }

  Widget _buildGroupDataSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Data Group',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade700,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _buildGroupCard('A')),
            const SizedBox(width: 12),
            Expanded(child: _buildGroupCard('B')),
          ],
        ),
      ],
    );
  }

  Widget _buildGroupCard(String group) {
    final isSelected = widget.group.toUpperCase() == group;
    final nik = group == 'A'
        ? widget.tagData['nik_a']
        : widget.tagData['nik_b'];
    final qty = group == 'A'
        ? widget.tagData['qty_a']
        : widget.tagData['qty_b'];
    final updated = group == 'A'
        ? widget.tagData['updated_a']
        : widget.tagData['updated_b'];

    final hasData =
        nik != null &&
        nik.toString().isNotEmpty &&
        qty != null &&
        qty.toString().isNotEmpty;

    final color = group == 'A' ? Colors.blue : Colors.orange;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isSelected ? color.withOpacity(0.1) : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected ? color : Colors.grey.shade300,
          width: isSelected ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  group,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
              const Spacer(),
              if (hasData)
                Icon(Icons.check_circle, color: Colors.green.shade600, size: 18)
              else
                Icon(
                  Icons.radio_button_unchecked,
                  color: Colors.grey.shade400,
                  size: 18,
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'NIK: ${nik ?? '-'}',
            style: TextStyle(
              fontSize: 12,
              color: hasData ? Colors.black87 : Colors.grey.shade500,
            ),
          ),
          Text(
            'Qty: ${qty ?? '-'}',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: hasData ? color : Colors.grey.shade500,
            ),
          ),
          if (updated != null && hasData)
            Text(
              Helpers.formatDateTime(updated),
              style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
            ),
        ],
      ),
    );
  }

  Widget _buildQtyInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Input Qty untuk Group ${widget.group}',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: groupColor,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Icon(Icons.person, color: Colors.grey.shade600, size: 20),
            const SizedBox(width: 8),
            Text(
              'NIK: ${widget.nik}',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(width: 4),
            Text(
              '(otomatis)',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _qtyController,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          autofocus: true,
          decoration: InputDecoration(
            labelText: 'Quantity',
            hintText: 'Masukkan jumlah',
            prefixIcon: Icon(Icons.numbers, color: groupColor),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: groupColor, width: 2),
            ),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Qty tidak boleh kosong';
            }
            final qty = int.tryParse(value.trim());
            if (qty == null || qty <= 0) {
              return 'Qty harus lebih dari 0';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: isSubmitting ? null : () => Navigator.pop(context),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Tutup'),
          ),
        ),
        if (canInputQty) ...[
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              onPressed: isSubmitting ? null : _handleSubmit,
              style: ElevatedButton.styleFrom(
                backgroundColor: groupColor,
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
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.save, size: 18),
                        SizedBox(width: 6),
                        Text('Simpan'),
                      ],
                    ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildInfoRow(String label, String value, IconData icon) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: Colors.grey.shade500),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _qtyController.dispose();
    super.dispose();
  }
}
