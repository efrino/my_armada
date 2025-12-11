import 'dart:convert';
import 'package:http/http.dart' as http;
import '../utils/logger.dart';

class BaseService {
  static const String baseUrl = "http://192.168.10.67/majsf_rest_api/api";
}

class ScanStoService {
  // GET - Get tag data by area
  static Future<Map<String, dynamic>?> getTagData(
    String idTagOk,
    String area,
  ) async {
    try {
      final url =
          "${BaseService.baseUrl}/scan_barcode/sto_tag_data?id_tag_ok=$idTagOk";
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

  // POST - Scan in tag (from barcode scanner)
  static Future<Map<String, dynamic>> scanStoTag({
    required String nik,
    required String idTag,
    required String qty,
    required String area,
  }) async {
    try {
      final areaLower = area.toLowerCase();
      final url = "${BaseService.baseUrl}/scan_barcode/scan_in_tag_$areaLower";

      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'nik': nik,
          'id_tag_ok': idTag,
          'qty': qty,
          'sloc': area,
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
      final url =
          "${BaseService.baseUrl}/scan_barcode/sto_part_data?sloc=$area";
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
