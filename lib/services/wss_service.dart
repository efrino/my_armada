import '../models/api_response.dart';
import '../models/wss_model.dart';
import 'api_service.dart';
import '../config/api_config.dart';

class WssService {
  /// Get Tag Detail from IFPD
  static Future<ApiResponse<TagDataModel>> getTagDetail(String idTagOk) async {
    if (idTagOk.isEmpty) {
      return ApiResponse.error('ID Tag OK tidak boleh kosong');
    }

    final response = await ApiService.get(
      ApiConfig.tagInIfpd,
      params: {
        'id_tag_ok': idTagOk,
        'type': 'WIP', // Tambahan parameter status
      },
    );

    if (response.success && response.data != null) {
      if (response.data!['id_tag_ok'] != null ||
          response.data!['part_number'] != null) {
        final tag = TagDataModel.fromJson(response.data!);
        return ApiResponse.success(tag, message: 'Data tag ditemukan');
      } else {
        return ApiResponse.error('Tag tidak ditemukan');
      }
    }

    return ApiResponse.error(response.message);
  }

  /// Check if ID Tag OK already scanned in scan_in_wss table
  static Future<ApiResponse<ScanCheckResult>> checkTagScanned(
    String idTagOk,
  ) async {
    if (idTagOk.isEmpty) {
      return ApiResponse.error('ID Tag OK tidak boleh kosong');
    }

    final response = await ApiService.get(
      ApiConfig.wssCheckScanned,
      params: {'id_tag_ok': idTagOk},
    );

    if (response.success && response.data != null) {
      final result = ScanCheckResult.fromJson(response.data!);
      return ApiResponse.success(result, message: response.message);
    }

    return ApiResponse.error(response.message);
  }

  /// Check if Part is WSS
  static Future<ApiResponse<WssPartModel>> checkPartWss(
    String partNumber,
  ) async {
    if (partNumber.isEmpty) {
      return ApiResponse.error('Part number tidak boleh kosong');
    }

    final response = await ApiService.get(
      ApiConfig.wssCheckPart,
      params: {'part_number': partNumber},
    );

    if (response.success && response.data != null) {
      final wssPart = WssPartModel.fromJson(response.data!);
      if (wssPart.isValid) {
        return ApiResponse.success(wssPart, message: 'Part WSS valid');
      } else {
        return ApiResponse.error(
          'Part $partNumber tidak terdata sebagai Part WSS ADM!',
        );
      }
    }

    return ApiResponse.error(response.message);
  }

  /// Scan In WSS
  static Future<ApiResponse<ScanInResponse>> scanIn({
    required String partWss,
    required int qty,
    required String nik,
    required String deviceId,
    String? idTagOk,
    String? notes,
  }) async {
    // Validation
    if (partWss.isEmpty) {
      return ApiResponse.error('Part WSS tidak boleh kosong');
    }
    if (qty <= 0) {
      return ApiResponse.error('Qty harus lebih dari 0');
    }
    if (nik.isEmpty) {
      return ApiResponse.error('NIK tidak boleh kosong');
    }
    if (deviceId.isEmpty) {
      return ApiResponse.error('Device ID tidak boleh kosong');
    }

    final body = {
      'part_wss': partWss,
      'qty': qty,
      'nik': nik,
      'device_id': deviceId,
    };

    if (idTagOk != null && idTagOk.isNotEmpty) {
      body['id_tag_ok'] = idTagOk;
    }
    if (notes != null && notes.isNotEmpty) {
      body['notes'] = notes;
    }

    final response = await ApiService.post(ApiConfig.wssScanIn, body: body);

    if (response.success && response.data != null) {
      final scanResult = ScanInResponse.fromJson(response.data!);
      return ApiResponse.success(scanResult, message: 'Scan berhasil!');
    }

    return ApiResponse.error(response.message, errors: response.errors);
  }

  /// Get All WSS Stock
  static Future<ApiResponse<List<WssStockModel>>> getAllStock() async {
    final response = await ApiService.get(ApiConfig.wssStock);

    if (response.success && response.data != null) {
      final dataList = response.data!['data'] as List<dynamic>?;
      if (dataList != null) {
        final stocks = dataList
            .map((e) => WssStockModel.fromJson(e as Map<String, dynamic>))
            .toList();
        return ApiResponse.success(
          stocks,
          message: 'Data stock berhasil diambil',
        );
      }
    }

    return ApiResponse.error(response.message);
  }

  /// Get Single WSS Stock
  static Future<ApiResponse<WssStockModel>> getStock(String partWss) async {
    if (partWss.isEmpty) {
      return ApiResponse.error('Part WSS tidak boleh kosong');
    }

    final response = await ApiService.get(
      ApiConfig.wssStock,
      params: {'part_wss': partWss},
    );

    if (response.success && response.data != null) {
      final data = response.data!['data'] as Map<String, dynamic>?;
      if (data != null) {
        final stock = WssStockModel.fromJson(data);
        return ApiResponse.success(stock);
      }
    }

    return ApiResponse.error(response.message);
  }

  /// Get WSS History
  static Future<ApiResponse<List<WssHistoryModel>>> getHistory({
    String? partWss,
    int limit = 50,
    int offset = 0,
  }) async {
    final params = {'limit': limit.toString(), 'offset': offset.toString()};

    if (partWss != null && partWss.isNotEmpty) {
      params['part_wss'] = partWss;
    }

    final response = await ApiService.get(ApiConfig.wssHistory, params: params);

    if (response.success && response.data != null) {
      final dataList = response.data!['data'] as List<dynamic>?;
      if (dataList != null) {
        final history = dataList
            .map((e) => WssHistoryModel.fromJson(e as Map<String, dynamic>))
            .toList();
        return ApiResponse.success(
          history,
          message: 'Data history berhasil diambil',
        );
      }
    }

    return ApiResponse.error(response.message);
  }

  /// Get Part List for Search/Dropdown
  static Future<ApiResponse<List<WssStockModel>>> getPartList({
    String? search,
    int limit = 20,
  }) async {
    final params = {'limit': limit.toString()};

    if (search != null && search.isNotEmpty) {
      params['search'] = search;
    }

    final response = await ApiService.get(
      ApiConfig.wssPartList,
      params: params,
    );

    if (response.success && response.data != null) {
      final dataList = response.data!['data'] as List<dynamic>?;
      if (dataList != null) {
        final parts = dataList
            .map((e) => WssStockModel.fromJson(e as Map<String, dynamic>))
            .toList();
        return ApiResponse.success(parts);
      }
    }

    return ApiResponse.error(response.message);
  }
}
