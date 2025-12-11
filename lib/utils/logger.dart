import 'package:logging/logging.dart';
import 'package:http/http.dart' as http;

final Logger logger = Logger('AppLogger');

void setupLogging() {
  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen((record) async {
    final logMessage =
        '${record.level.name}: ${record.time}: ${record.message}';

    // Output ke console
    // ignore: avoid_print
    print(logMessage);

    // Output juga ke server lokal
    try {
      await http.post(
        Uri.parse('http://192.168.70.61/error_logs.php'),
        headers: {'Content-Type': 'application/json'},
        body:
            '''
        {
          "level": "${record.level.name}",
          "time": "${record.time.toIso8601String()}",
          "message": "${record.message}"
        }
        ''',
      );
    } catch (e) {
      // ignore: avoid_print
      print('ERROR SEND LOG: $e');
    }
  });
}
