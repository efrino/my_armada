import 'dart:convert';
import 'package:http/http.dart' as http;
import '../utils/logger.dart';

class StoBaseService {
  static const String baseUrl = "https://mspin.newarmada.biz/sto/documentation";
}

class ScanStoService {
  /// GET - Get tag data by barcode
  static Future<Map<String, dynamic>?> getTagData(String barcode) async {
    try {
      final url = "${StoBaseService.baseUrl}/get-store?barcode=$barcode";
      logger.info('STO API GET: $url');

      final response = await http
          .get(Uri.parse(url))
          .timeout(
            const Duration(seconds: 15),
            onTimeout: () => http.Response('{"error": "Timeout"}', 408),
          );

      logger.info('STO API Response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data;
      } else if (response.statusCode == 404) {
        return null;
      } else {
        logger.severe('Error: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      logger.severe('Error getting tag data: $e');
      return null;
    }
  }

  /// POST - Update store data (submit qty)
  static Future<Map<String, dynamic>> updateStore({
    required String nik,
    required String idTag,
    required String qty,
    required String group,
  }) async {
    try {
      final url = "${StoBaseService.baseUrl}/update-store";
      logger.info('STO API POST: $url');

      final body = {
        'nik': nik,
        'tag_sto': idTag,
        'qty': qty,
        'group': group.toUpperCase(),
      };

      logger.info('STO API Body: $body');

      final response = await http
          .post(
            Uri.parse(url),
            headers: {'Content-Type': 'application/json'},
            body: json.encode(body),
          )
          .timeout(
            const Duration(seconds: 15),
            onTimeout: () => http.Response('{"error": "Timeout"}', 408),
          );

      logger.info('STO API Response: ${response.statusCode}');

      final data = json.decode(response.body);

      return {
        'success': response.statusCode == 200 || response.statusCode == 201,
        'statusCode': response.statusCode,
        'message':
            data['message'] ??
            (response.statusCode == 200
                ? 'Update berhasil'
                : 'Gagal update data'),
        'data': data,
      };
    } catch (e) {
      logger.severe('Error update store: $e');
      return {
        'success': false,
        'statusCode': 0,
        'message': 'Error koneksi: ${e.toString()}',
        'data': null,
      };
    }
  }

  /// Validate tag data berdasarkan group yang dipilih
  /// Returns: Map dengan key 'valid', 'message', 'canInput'
  static Map<String, dynamic> validateTagForGroup(
    Map<String, dynamic> tagData,
    String group,
  ) {
    // 1. Cek apakah tag aktif
    final active = tagData['active']?.toString();
    if (active != '1') {
      return {
        'valid': false,
        'canInput': false,
        'message': 'Tag tidak aktif (status: inactive)',
      };
    }

    // 2. Cek berdasarkan group
    final groupUpper = group.toUpperCase();

    if (groupUpper == 'A') {
      final nikA = tagData['nik_a']?.toString().trim() ?? '';
      final qtyA = tagData['qty_a']?.toString().trim() ?? '';

      // Jika sudah ada data di group A
      if (nikA.isNotEmpty && qtyA.isNotEmpty) {
        return {
          'valid': true,
          'canInput': false,
          'message': 'Data Group A sudah terisi oleh $nikA (Qty: $qtyA)',
          'existingNik': nikA,
          'existingQty': qtyA,
          'existingDate': tagData['updated_a'],
        };
      }

      // Belum ada data, bisa input
      return {
        'valid': true,
        'canInput': true,
        'message': 'Silakan input qty untuk Group A',
      };
    } else if (groupUpper == 'B') {
      final nikB = tagData['nik_b']?.toString().trim() ?? '';
      final qtyB = tagData['qty_b']?.toString().trim() ?? '';

      // Jika sudah ada data di group B
      if (nikB.isNotEmpty && qtyB.isNotEmpty) {
        return {
          'valid': true,
          'canInput': false,
          'message': 'Data Group B sudah terisi oleh $nikB (Qty: $qtyB)',
          'existingNik': nikB,
          'existingQty': qtyB,
          'existingDate': tagData['updated_b'],
        };
      }

      // Belum ada data, bisa input
      return {
        'valid': true,
        'canInput': true,
        'message': 'Silakan input qty untuk Group B',
      };
    }

    return {'valid': false, 'canInput': false, 'message': 'Group tidak valid'};
  }
}
