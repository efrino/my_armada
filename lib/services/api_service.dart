import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/api_response.dart';

class ApiService {
  static final _client = http.Client();

  /// GET Request
  static Future<ApiResponse<Map<String, dynamic>>> get(String endpoint, {Map<String, String>? params}) async {
    try {
      String url = '${ApiConfig.baseUrl}$endpoint';
      
      if (params != null && params.isNotEmpty) {
        final queryString = params.entries
            .map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
            .join('&');
        url = '$url?$queryString';
      }

      final response = await _client
          .get(Uri.parse(url))
          .timeout(ApiConfig.timeout);

      return _handleResponse(response);
    } on SocketException {
      return ApiResponse.networkError();
    } on TimeoutException {
      return ApiResponse.timeout();
    } catch (e) {
      return ApiResponse.error('Terjadi kesalahan: ${e.toString()}');
    }
  }

  /// POST Request
  static Future<ApiResponse<Map<String, dynamic>>> post(
    String endpoint, {
    Map<String, dynamic>? body,
  }) async {
    try {
      final url = '${ApiConfig.baseUrl}$endpoint';

      final response = await _client
          .post(
            Uri.parse(url),
            headers: {'Content-Type': 'application/x-www-form-urlencoded'},
            body: body?.map((key, value) => MapEntry(key, value.toString())),
          )
          .timeout(ApiConfig.timeout);

      return _handleResponse(response);
    } on SocketException {
      return ApiResponse.networkError();
    } on TimeoutException {
      return ApiResponse.timeout();
    } catch (e) {
      return ApiResponse.error('Terjadi kesalahan: ${e.toString()}');
    }
  }

  /// Handle Response
  static ApiResponse<Map<String, dynamic>> _handleResponse(http.Response response) {
    try {
      final jsonData = json.decode(response.body) as Map<String, dynamic>;

      if (response.statusCode >= 200 && response.statusCode < 300) {
        // Check if API returns success field
        if (jsonData.containsKey('success')) {
          if (jsonData['success'] == true) {
            return ApiResponse.success(
              jsonData,
              message: jsonData['message']?.toString() ?? 'Berhasil',
            );
          } else {
            return ApiResponse.error(
              jsonData['message']?.toString() ?? 'Gagal : $response',
              statusCode: response.statusCode,
              errors: jsonData['errors'] != null
                  ? List<String>.from(jsonData['errors'])
                  : null,
            );
          }
        }
        
        // If no success field, assume success for 2xx status
        return ApiResponse.success(jsonData);
      } else if (response.statusCode == 401) {
        return ApiResponse.error(
          'Unauthorized. Silakan login ulang.',
          statusCode: 401,
        );
      } else if (response.statusCode == 404) {
        return ApiResponse.error(
          jsonData['message']?.toString() ?? 'Data tidak ditemukan',
          statusCode: 404,
        );
      } else if (response.statusCode >= 500) {
        return ApiResponse.serverError();
      } else {
        return ApiResponse.error(
          jsonData['message']?.toString() ?? 'Terjadi kesalahan',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      return ApiResponse.error('Gagal memproses response: ${e.toString()}');
    }
  }
}