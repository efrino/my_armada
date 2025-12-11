import 'package:flutter/material.dart';
import '../utils/logger.dart';

class ResponseModal extends StatelessWidget {
  final bool success;
  final String message;
  final String? title;
  final Map<String, dynamic>? stockInfo;
  final String? partNumber;
  final VoidCallback? onClose;

  const ResponseModal({
    super.key,
    required this.success,
    required this.message,
    this.title,
    this.stockInfo,
    this.partNumber,
    this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: success ? Colors.green.shade50 : Colors.red.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  success ? Icons.check_circle : Icons.error,
                  size: 64,
                  color: success ? Colors.green.shade600 : Colors.red.shade600,
                ),
              ),
              const SizedBox(height: 20),

              // Title
              Text(
                title ?? (success ? 'Berhasil!' : 'Gagal!'),
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: success ? Colors.green.shade700 : Colors.red.shade700,
                ),
              ),
              const SizedBox(height: 12),

              // Message
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, color: Colors.grey),
              ),

              // Stock Info (only show if success and stockInfo available)
              if (success &&
                  stockInfo != null &&
                  stockInfo!['success'] == true) ...[
                const SizedBox(height: 20),
                _buildStockInfoCard(),
              ],

              const SizedBox(height: 24),

              // Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    // Log modal dismiss
                    logger.info(
                      'ResponseModal dismissed - Success: $success, Message: $message',
                    );

                    Navigator.pop(context);
                    if (onClose != null) {
                      onClose!();
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: success
                        ? Colors.green.shade600
                        : Colors.red.shade600,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'OK',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Build stock info card for success response
  Widget _buildStockInfoCard() {
    final data = stockInfo!['data'];
    final totalBalance = data['total_balance'] ?? 0;
    final stocks = data['stocks'] as List? ?? [];

    // Filter only available stocks (balance > 0)
    final availableStocks = stocks.where((s) {
      final balance = int.tryParse(s['balance']?.toString() ?? '0') ?? 0;
      return balance > 0;
    }).toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Icon(Icons.inventory_2, color: Colors.blue.shade700, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Update Stok',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade800,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),

          // Part number
          if (partNumber != null && partNumber!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Part: $partNumber',
              style: TextStyle(fontSize: 12, color: Colors.blue.shade700),
            ),
          ],

          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),

          // Total Balance - Highlighted
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blue.shade600, Colors.blue.shade400],
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Total Stok Sekarang',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                    fontSize: 13,
                  ),
                ),
                Text(
                  totalBalance.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
              ],
            ),
          ),

          // Available stock per tag
          if (availableStocks.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'Stok Tersedia (${availableStocks.length} tag):',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.blue.shade700,
              ),
            ),
            const SizedBox(height: 8),
            ...availableStocks.take(5).map((stock) {
              final tagId = stock['id_tag_ok'] ?? '-';
              final balance = stock['balance'] ?? '0';
              final status = stock['stock_status'] ?? '-';

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Icon(
                      Icons.label_outline,
                      size: 14,
                      color: Colors.blue.shade400,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        tagId.toString(),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.blue.shade700,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: status == 'TERSEDIA'
                            ? Colors.green.shade100
                            : Colors.blue.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        balance.toString(),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: status == 'TERSEDIA'
                              ? Colors.green.shade800
                              : Colors.blue.shade800,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
            if (availableStocks.length > 5)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  '+ ${availableStocks.length - 5} tag lainnya',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.blue.shade600,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
          ] else if (totalBalance == 0) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 16,
                    color: Colors.orange.shade700,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Semua stok sudah habis',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.orange.shade700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // Static method untuk show modal
  static Future<void> show(
    BuildContext context, {
    required bool success,
    required String message,
    String? title,
    Map<String, dynamic>? stockInfo,
    String? partNumber,
    VoidCallback? onClose,
  }) {
    // Log when modal is shown
    if (success) {
      logger.info('ResponseModal shown - SUCCESS: $message');
    } else {
      logger.warning('ResponseModal shown - FAILURE: $message');
    }

    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => ResponseModal(
        success: success,
        message: message,
        title: title,
        stockInfo: stockInfo,
        partNumber: partNumber,
        onClose: onClose,
      ),
    );
  }
}
