import 'package:logging/logging.dart';
import 'package:http/http.dart' as http;

final Logger logger = Logger('AppLogger');

/// Konfigurasi remote logging
class LoggerConfig {
  /// Enable/disable remote logging ke server
  /// Set ke true jika backend sudah siap
  static bool enableRemoteLogging = false;

  /// URL endpoint untuk remote logging
  static String remoteLogUrl = 'http://192.168.70.61/error_logs.php';

  /// Timeout untuk HTTP request (dalam detik)
  static int timeoutSeconds = 5;

  /// Hanya kirim log dengan level ini atau lebih tinggi ke server
  /// Level hierarchy: ALL < FINEST < FINER < FINE < CONFIG < INFO < WARNING < SEVERE < SHOUT
  static Level minRemoteLevel = Level.WARNING;
}

void setupLogging() {
  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen((record) {
    final logMessage =
        '${record.level.name}: ${record.time}: ${record.message}';

    // Output ke console
    // ignore: avoid_print
    print(logMessage);

    // Output ke server lokal (jika diaktifkan)
    if (LoggerConfig.enableRemoteLogging &&
        record.level >= LoggerConfig.minRemoteLevel) {
      _sendLogToServer(record);
    }
  });
}

/// Kirim log ke server secara async tanpa blocking
Future<void> _sendLogToServer(LogRecord record) async {
  try {
    await http
        .post(
          Uri.parse(LoggerConfig.remoteLogUrl),
          headers: {'Content-Type': 'application/json'},
          body:
              '''
{
  "level": "${record.level.name}",
  "time": "${record.time.toIso8601String()}",
  "message": "${_escapeJson(record.message)}",
  "logger": "${record.loggerName}"
}
''',
        )
        .timeout(
          Duration(seconds: LoggerConfig.timeoutSeconds),
          onTimeout: () => http.Response('Timeout', 408),
        );
  } catch (e) {
    // Silent fail - jangan print error lagi untuk menghindari loop
    // Uncomment baris di bawah hanya untuk debugging
    // print('Remote log failed: $e');
  }
}

/// Escape special characters untuk JSON
String _escapeJson(String text) {
  return text
      .replaceAll('\\', '\\\\')
      .replaceAll('"', '\\"')
      .replaceAll('\n', '\\n')
      .replaceAll('\r', '\\r')
      .replaceAll('\t', '\\t');
}
