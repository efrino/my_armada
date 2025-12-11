import 'dart:convert';
import 'package:http/http.dart' as http;
import 'base.dart';
import '../utils/logger.dart';

class ScanOutService {
  // GET - Get tag data by area
  static Future<Map<String, dynamic>?> getTagData(
    String idTagOk,
    String area,
  ) async {
    try {
      final areaLower = area.toLowerCase();
      final url =
          "${BaseService.baseUrl}/scan_barcode/tag_in_${areaLower}_data?id_tag_ok=$idTagOk";
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

  // POST - Scan out tag (berbasis part_number)
  static Future<Map<String, dynamic>> scanOutTag({
    required String nik,
    required String partNumber,
    required String area,
    required num qty,
  }) async {
    try {
      final areaLower = area.toLowerCase();
      final url =
          "${BaseService.baseUrl}/scan_barcode/scan_out_tag_$areaLower";

      // Mapping area → sloc id
      final Map<String, String> slocMap = {
        "IFRM": "1",
        "IFPP": "2",
        "IFPD": "3",
      };

      final slocId = slocMap[area.toUpperCase()] ?? area;

      logger.info('📡 POST Scan Out: $url');
      logger.info(
        '📤 Request Body: ${json.encode({'nik': nik, 'part_number': partNumber, 'sloc': slocId, 'qty': qty})}',
      );

      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'nik': nik,
          'part_number': partNumber,
          'sloc': slocId,
          'qty': qty,
        }),
      );

      logger.info('📥 Response Status: ${response.statusCode}');
      logger.info('📥 Response Body: ${response.body}');

      // Try to parse response body
      Map<String, dynamic> data;
      try {
        data = json.decode(response.body);
      } catch (e) {
        logger.warning('⚠️ Failed to parse JSON: $e');
        data = {'message': response.body};
      }

      // Determine success
      final bool isSuccess =
          response.statusCode == 200 || response.statusCode == 201;

      // Extract message
      String message;
      if (data.containsKey('message')) {
        message = data['message'].toString();
      } else if (data.containsKey('error')) {
        message = data['error'].toString();
      } else if (isSuccess) {
        message = 'Scan Out berhasil';
      } else {
        message = 'Gagal Scan Out. Status: ${response.statusCode}';
      }

      return {
        'success': isSuccess,
        'statusCode': response.statusCode,
        'message': message,
        'data': data,
      };
    } catch (e) {
      logger.warning('❌ Exception scan out tag: $e');
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
      final url = "${BaseService.baseUrl}/scan_barcode/manual_in_ifp";

      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'nik': nik,
          'part_number': partNumber,
          'qty': qty,
          'area': area,
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
