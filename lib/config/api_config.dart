class ApiConfig {
  // Base URL API
  static const String baseUrl = "http://192.168.10.67/majsf_rest_api/api";
  
  // Endpoints
  static const String nikData = "/scan_barcode/nik_data";
  static const String tagInIfpd = "/scan_barcode/tag_in_wss_data";
  static const String wssCheckPart = "/scan_barcode/wss_check_part";
  static const String wssScanIn = "/scan_barcode/wss_scan_in";
  static const String wssStock = "/scan_barcode/wss_stock";
  static const String wssHistory = "/scan_barcode/wss_history";
  static const String wssPartList = "/scan_barcode/wss_part_list";
  static const String wssCheckScanned = '/scan_barcode/check_scanned'; // NEW
  // Timeout
  static const Duration timeout = Duration(seconds: 30);
}