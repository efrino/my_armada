import 'dart:convert';
import 'package:http/http.dart' as http;
import 'base.dart';
import '../utils/logger.dart';

class ScanInService {
  // GET - Get tag data by area
  static Future<Map<String, dynamic>?> getTagData(
    String idTagOk,
    String area,
  ) async {
    try {
      final areaLower = area.toLowerCase();
      final url =
          "${BaseService.baseUrl}/scan_barcode/tag_in_${areaLower}_data?id_tag_ok=$idTagOk&area=$areaLower";
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data;
      } else {
        logger.severe('Error: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      logger.severe('Error getting tag data: $e');
      return null;
    }
  }

  // GET - Get stock info for a part_number
  static Future<Map<String, dynamic>?> getStockInfo(
    String partNumber,
    String area,
  ) async {
    try {
      // Mapping area → sloc
      final Map<String, String> slocMap = {
        "IFRM": "1",
        "IFPP": "2",
        "IFPD": "3",
      };
      final sloc = slocMap[area.toUpperCase()] ?? area;

      final url =
          "${BaseService.baseUrl}/scan_barcode/stock_info_ifpp?part_number=$partNumber&sloc=$sloc";

      logger.info('📡 GET Stock Info: $url');

      final response = await http.get(Uri.parse(url));

      logger.info('📥 Response Status: ${response.statusCode}');
      logger.info('📥 Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return data;
        }
      }
      return null;
    } catch (e) {
      logger.severe('Error getting stock info: $e');
      return null;
    }
  }

  // POST - Scan in tag (from barcode scanner)
  static Future<Map<String, dynamic>> scanInTag({
    required String nik,
    required String idTag,
    required String qty,
    required String area,
  }) async {
    try {
      final areaLower = area.toLowerCase();
      final url = "${BaseService.baseUrl}/scan_barcode/scan_in_tag_$areaLower";

      // Mapping area → sloc id
      final Map<String, String> slocMap = {
        "IFRM": "1",
        "IFPP": "2",
        "IFPD": "3",
      };

      // Default fallback jika area tidak diketahui
      final slocId = slocMap[area.toUpperCase()] ?? area;

      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'nik': nik,
          'id_tag_ok': idTag,
          'qty': qty,
          'sloc': slocId,
        }),
      );

      final data = json.decode(response.body);

      // Return response with status
      return {
        'success': response.statusCode == 200 || response.statusCode == 201,
        'statusCode': response.statusCode,
        'message':
            data['message'] ??
            (response.statusCode == 200 ? 'Scan in berhasil' : '$response'),
        'data': data,
      };
    } catch (e) {
      logger.severe('Error scan in tag: $e');
      return {
        'success': false,
        'statusCode': 0,
        'message': 'Error koneksi: ${e.toString()}',
        'data': null,
      };
    }
  }

  // GET - Get part data for manual input
  static Future<List<Map<String, dynamic>>> getPartData(String area) async {
    try {
      // Mapping area → sloc id
      final Map<String, String> slocMap = {
        "IFRM": "1",
        "IFPP": "2",
        "IFPD": "3",
      };

      // Default fallback jika area tidak diketahui
      final slocId = slocMap[area.toUpperCase()] ?? area;
      final url =
          "${BaseService.baseUrl}/scan_barcode/scan_part_data?sloc=$slocId";
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((item) => item as Map<String, dynamic>).toList();
      } else {
        logger.severe('Error: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      logger.severe('Error getting part data: $e');
      return [];
    }
  }

  // POST - Manual input
  static Future<Map<String, dynamic>> manualInput({
    required String nik,
    required String partNumber,
    required String qty,
    required String area,
  }) async {
    try {
      final areaLower = area.toLowerCase();
      final url = "${BaseService.baseUrl}/scan_barcode/manual_in_$areaLower";
      // Mapping area → sloc id
      final Map<String, String> slocMap = {
        "IFRM": "1",
        "IFPP": "2",
        "IFPD": "3",
      };

      // Default fallback jika area tidak diketahui
      final slocId = slocMap[area.toUpperCase()] ?? area;

      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'nik': nik,
          'part_number': partNumber,
          'qty': qty,
          'sloc': slocId,
          'in_out': "in",
        }),
      );

      final data = json.decode(response.body);

      // Return response with status
      return {
        'success': response.statusCode == 200 || response.statusCode == 201,
        'statusCode': response.statusCode,
        'message':
            data['message'] ??
            (response.statusCode == 200
                ? 'Input manual berhasil'
                : 'Gagal input manual'),
        'data': data,
      };
    } catch (e) {
      logger.severe('Error manual input: $e');
      return {
        'success': false,
        'statusCode': 0,
        'message': 'Error koneksi: ${e.toString()}',
        'data': null,
      };
    }
  }
}
