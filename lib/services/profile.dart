import 'dart:convert';
import 'package:http/http.dart' as http;
import '../utils/logger.dart';

class BaseService {
  static const String baseUrl = "http://192.168.10.67/majsf_rest_api/api";
}

class ProfileService {
  // Get user data by NIK
  static Future<Map<String, dynamic>?> getNikData(String nik) async {
    try {
      final url = "${BaseService.baseUrl}/scan_barcode/nik_data?nik=$nik";
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data;
      } else {
        logger.severe('Error: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      logger.severe('Error getting NIK data: $e');
      return null;
    }
  }

  // Get user last activity (using scan_in_data_history as temporary solution)
  static Future<List<Map<String, dynamic>>> getLastActivity(String nik) async {
    try {
      final url =
          "${BaseService.baseUrl}/scan_barcode/scan_in_data_history?nik=$nik&limit=5";
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((item) => item as Map<String, dynamic>).toList();
      } else {
        logger.severe('Error: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      logger.severe('Error getting last activity: $e');
      return [];
    }
  }

  // Validate NIK (check if NIK exists in database)
  static Future<bool> validateNik(String nik) async {
    try {
      final userData = await getNikData(nik);
      return userData != null && userData['nik'] != null;
    } catch (e) {
      logger.severe('Error validating NIK: $e');
      return false;
    }
  }
}
