import 'package:flutter/material.dart';
import '../layout/main.dart';

/// ExitWrapper - Now simplified as back button handling moved to MainLayout
/// This wrapper is kept for backward compatibility
class ExitWrapper extends StatelessWidget {
  const ExitWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    // Back button handling is now in MainLayout
    // ExitWrapper simply returns MainLayout
    return const MainLayout();
  }
}
