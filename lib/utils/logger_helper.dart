import 'logger.dart';

/// Helper class untuk logging dengan kategori yang lebih spesifik
class LoggerHelper {
  // API Call Logging
  static void logApiRequest(
    String method,
    String endpoint, {
    Map<String, dynamic>? body,
  }) {
    logger.info(
      '📡 [API REQUEST] $method $endpoint${body != null ? '\nBody: $body' : ''}',
    );
  }

  static void logApiResponse(
    String endpoint,
    int statusCode, {
    String? message,
    int? duration,
  }) {
    final emoji = statusCode >= 200 && statusCode < 300 ? '✅' : '⚠️';
    logger.info(
      '$emoji [API RESPONSE] $endpoint - Status: $statusCode'
      '${duration != null ? ', Duration: ${duration}ms' : ''}'
      '${message != null ? ', Message: $message' : ''}',
    );
  }

  static void logApiError(
    String endpoint,
    dynamic error, {
    StackTrace? stackTrace,
  }) {
    logger.severe(
      '❌ [API ERROR] $endpoint\n'
      'Error: $error'
      '${stackTrace != null ? '\nStack: ${_formatStackTrace(stackTrace)}' : ''}',
    );
  }

  // User Action Logging
  static void logUserAction(String action, {Map<String, dynamic>? details}) {
    logger.info(
      '👤 [USER ACTION] $action${details != null ? '\nDetails: $details' : ''}',
    );
  }

  // Navigation Logging
  static void logNavigation(String from, String to) {
    logger.info('🧭 [NAVIGATION] $from → $to');
  }

  // Scan Logging
  static void logScanStart(String area) {
    logger.info('📸 [SCAN] Started in area: $area');
  }

  static void logScanSuccess(String code, String area) {
    logger.info('✅ [SCAN] Success - Code: $code, Area: $area');
  }

  static void logScanError(String error, {String? area}) {
    logger.warning('⚠️ [SCAN] Error${area != null ? ' in $area' : ''}: $error');
  }

  // Camera Logging
  static void logCameraInit() {
    logger.info('📷 [CAMERA] Initializing...');
  }

  static void logCameraReady() {
    logger.info('✅ [CAMERA] Ready');
  }

  static void logCameraError(dynamic error) {
    logger.severe('❌ [CAMERA] Error: $error');
  }

  static void logCameraDispose() {
    logger.info('📷 [CAMERA] Disposed');
  }

  // Authentication Logging
  static void logLogin(String nik, bool success) {
    if (success) {
      logger.info('🔐 [AUTH] Login success - NIK: $nik');
    } else {
      logger.warning('🔐 [AUTH] Login failed - NIK: $nik');
    }
  }

  static void logLogout(String nik) {
    logger.info('🔓 [AUTH] Logout - NIK: $nik');
  }

  // Data Operation Logging
  static void logDataLoad(String dataType, {int? count}) {
    logger.info(
      '📦 [DATA] Loading $dataType${count != null ? ' (count: $count)' : ''}',
    );
  }

  static void logDataSave(String dataType, bool success) {
    if (success) {
      logger.info('💾 [DATA] Saved $dataType successfully');
    } else {
      logger.warning('💾 [DATA] Failed to save $dataType');
    }
  }

  // Performance Logging
  static void logPerformance(String operation, int durationMs) {
    final emoji = durationMs < 1000
        ? '⚡'
        : durationMs < 3000
        ? '⏱️'
        : '🐌';
    logger.info('$emoji [PERFORMANCE] $operation took ${durationMs}ms');
  }

  // App Lifecycle Logging
  static void logAppLifecycle(String state) {
    logger.info('🔄 [LIFECYCLE] App state: $state');
  }

  // Generic Success
  static void logSuccess(String message) {
    logger.info('✅ [SUCCESS] $message');
  }

  // Generic Warning
  static void logWarning(String message) {
    logger.warning('⚠️ [WARNING] $message');
  }

  // Generic Error
  static void logError(
    String message, {
    dynamic error,
    StackTrace? stackTrace,
  }) {
    logger.severe(
      '❌ [ERROR] $message'
      '${error != null ? '\nError: $error' : ''}'
      '${stackTrace != null ? '\nStack: ${_formatStackTrace(stackTrace)}' : ''}',
    );
  }

  // Debug Logging (only in development)
  static void logDebug(String message) {
    logger.fine('🐛 [DEBUG] $message');
  }

  // Format stack trace to show only first 5 lines
  static String _formatStackTrace(StackTrace stackTrace) {
    return stackTrace.toString().split('\n').take(5).join('\n');
  }
}

/// Extension untuk timing operations
extension TimedOperation<T> on Future<T> Function() {
  Future<T> timed(String operationName) async {
    final startTime = DateTime.now();
    try {
      final result = await this();
      final duration = DateTime.now().difference(startTime).inMilliseconds;
      LoggerHelper.logPerformance(operationName, duration);
      return result;
    } catch (e, stackTrace) {
      final duration = DateTime.now().difference(startTime).inMilliseconds;
      LoggerHelper.logError(
        'Operation "$operationName" failed after ${duration}ms',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }
}
