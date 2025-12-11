import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'utils/exit.dart';
import 'utils/logger.dart';
import 'utils/permission_manager.dart';
import 'dart:ui';

void main() {
  // Setup logging first
  setupLogging();

  // Catch all Flutter framework errors
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);

    logger.severe(
      '🔥 [FLUTTER ERROR] ${details.exception}\n'
      'Stack: ${details.stack}',
    );
  };

  // Catch all async errors
  PlatformDispatcher.instance.onError = (error, stack) {
    logger.severe(
      '🔥 [ASYNC ERROR] $error\n'
      'Stack: $stack',
    );
    return true;
  };

  // Run app in error zone
  runZonedGuarded(
    () async {
      // Ensure Flutter binding is initialized
      WidgetsFlutterBinding.ensureInitialized();

      // Lock orientation to portrait
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);

      // Initialize PermissionManager (load saved session)
      await permissionManager.init();

      logger.info('🚀 [APP] Application started');
      logger.info('🔑 [APP] User logged in: ${permissionManager.isLoggedIn}');
      if (permissionManager.isLoggedIn) {
        logger.info(
          '🔑 [APP] Current user: ${permissionManager.userName} (Admin: ${permissionManager.isAdmin})',
        );
      }

      runApp(const MyApp());
    },
    (error, stack) {
      logger.severe(
        '🔥 [ZONE ERROR] $error\n'
        'Stack: $stack',
      );
    },
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'MAJSF Scanner',
      theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
      home: const ExitWrapper(),
      // Global error widget builder
      builder: (context, widget) {
        // Setup global error widget
        ErrorWidget.builder = (FlutterErrorDetails details) {
          logger.severe(
            '🔥 [ERROR WIDGET] ${details.exception}\n'
            'Stack: ${details.stack}',
          );

          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 80,
                      color: Colors.red.shade400,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Oops! Terjadi Kesalahan',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.red.shade700,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Aplikasi mengalami error. Silakan restart aplikasi.',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey.shade600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: () {
                        // Try to navigate back or restart
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(
                            builder: (context) => const ExitWrapper(),
                          ),
                          (route) => false,
                        );
                      },
                      icon: const Icon(Icons.refresh),
                      label: const Text('Restart Aplikasi'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade600,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        };

        return widget ?? const SizedBox.shrink();
      },
    );
  }
}
