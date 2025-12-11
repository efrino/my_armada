import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class Helpers {
  /// Format Date
  static String formatDate(String? dateStr, {String format = 'dd MMM yyyy'}) {
    if (dateStr == null || dateStr.isEmpty) return '-';
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat(format, 'id_ID').format(date);
    } catch (_) {
      return dateStr;
    }
  }

  /// Format DateTime
  static String formatDateTime(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '-';
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('dd MMM yyyy HH:mm', 'id_ID').format(date);
    } catch (_) {
      return dateStr;
    }
  }

  /// Format Number
  static String formatNumber(int number) {
    return NumberFormat('#,###', 'id_ID').format(number);
  }

  /// Get Shift Name
  static String getShiftName(int shift) {
    switch (shift) {
      case 1:
        return 'Shift 1 (06:00-14:00)';
      case 2:
        return 'Shift 2 (14:00-22:00)';
      case 3:
        return 'Shift 3 (22:00-06:00)';
      default:
        return 'Shift $shift';
    }
  }

  /// Get Status Color
  static Color getStatusColor(String status) {
    switch (status.toUpperCase()) {
      case 'FP':
      case 'OK':
        return Colors.green;
      case 'NG':
      case 'REJECT':
        return Colors.red;
      case 'WIP':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  /// Get Transaction Type Color
  static Color getTransactionColor(String type) {
    switch (type.toUpperCase()) {
      case 'IN':
        return Colors.green;
      case 'OUT':
        return Colors.red;
      case 'ADJUSTMENT':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }
}
