// Tag Data dari IFPD
class TagDataModel {
  final String idTagOk;
  final String partNumber;
  final String date;
  final int shift;
  final String lineId;
  final String status;
  final int qty;
  final String? jobNumber;
  final String? customer;
  final String? project;
  final int scannedIn;
  final String? scanInDate;
  final String? scanInUser;

  TagDataModel({
    required this.idTagOk,
    required this.partNumber,
    required this.date,
    required this.shift,
    required this.lineId,
    required this.status,
    required this.qty,
    this.jobNumber,
    this.customer,
    this.project,
    required this.scannedIn,
    this.scanInDate,
    this.scanInUser,
  });

  factory TagDataModel.fromJson(Map<String, dynamic> json) {
    return TagDataModel(
      idTagOk: json['id_tag_ok']?.toString() ?? '',
      partNumber: json['part_number']?.toString() ?? '',
      date: json['date']?.toString() ?? '',
      shift: int.tryParse(json['shift']?.toString() ?? '0') ?? 0,
      lineId: json['line_id']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      qty: int.tryParse(json['qty']?.toString() ?? '0') ?? 0,
      jobNumber: json['job_number']?.toString(),
      customer: json['customer']?.toString(),
      project: json['project']?.toString(),
      scannedIn: int.tryParse(json['scanned_in']?.toString() ?? '0') ?? 0,
      scanInDate: json['scan_in_date']?.toString(),
      scanInUser: json['scan_in_user']?.toString(),
    );
  }

  bool get isAlreadyScanned => scannedIn == 1;
}

// WSS Part Check Response
class WssPartModel {
  final bool isValid;
  final String partWss;
  final String? partDelivery;
  final String? qtyPerUnit;
  final String? model;
  final String? customer;
  final String? type;
  final int currentStock;

  WssPartModel({
    required this.isValid,
    required this.partWss,
    this.partDelivery,
    this.qtyPerUnit,
    this.model,
    this.customer,
    this.type,
    required this.currentStock,
  });

  factory WssPartModel.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>?;
    return WssPartModel(
      isValid: json['is_valid'] == true,
      partWss:
          data?['part_wss']?.toString() ?? json['part_wss']?.toString() ?? '',
      partDelivery: data?['part_delivery']?.toString(),
      qtyPerUnit: data?['qty_per_unit']?.toString(),
      model: data?['model']?.toString(),
      customer: data?['customer']?.toString(),
      type: data?['type']?.toString(),
      currentStock:
          int.tryParse(data?['current_stock']?.toString() ?? '0') ?? 0,
    );
  }
}

// WSS Stock Model
class WssStockModel {
  final int id;
  final String partWss;
  final int stockQty;
  final int minStock;
  final int? maxStock;
  final String? location;
  final String? updatedAt;
  final String? model;
  final String? customer;
  final String? type;

  WssStockModel({
    required this.id,
    required this.partWss,
    required this.stockQty,
    required this.minStock,
    this.maxStock,
    this.location,
    this.updatedAt,
    this.model,
    this.customer,
    this.type,
  });

  factory WssStockModel.fromJson(Map<String, dynamic> json) {
    return WssStockModel(
      id: int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      partWss: json['part_wss']?.toString() ?? '',
      stockQty: int.tryParse(json['stock_qty']?.toString() ?? '0') ?? 0,
      minStock: int.tryParse(json['min_stock']?.toString() ?? '0') ?? 0,
      maxStock: int.tryParse(json['max_stock']?.toString() ?? ''),
      location: json['location']?.toString(),
      updatedAt: json['updated_at']?.toString(),
      model: json['model']?.toString(),
      customer: json['customer']?.toString(),
      type: json['type']?.toString(),
    );
  }

  bool get isLowStock => stockQty <= minStock;
}

// WSS History Model
class WssHistoryModel {
  final int id;
  final String partWss;
  final String transactionType;
  final int qtyChange;
  final int qtyBefore;
  final int qtyAfter;
  final String referenceType;
  final String? referenceId;
  final String? referencePart;
  final String? notes;
  final String? createdBy;
  final String createdAt;

  WssHistoryModel({
    required this.id,
    required this.partWss,
    required this.transactionType,
    required this.qtyChange,
    required this.qtyBefore,
    required this.qtyAfter,
    required this.referenceType,
    this.referenceId,
    this.referencePart,
    this.notes,
    this.createdBy,
    required this.createdAt,
  });

  factory WssHistoryModel.fromJson(Map<String, dynamic> json) {
    return WssHistoryModel(
      id: int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      partWss: json['part_wss']?.toString() ?? '',
      transactionType: json['transaction_type']?.toString() ?? '',
      qtyChange: int.tryParse(json['qty_change']?.toString() ?? '0') ?? 0,
      qtyBefore: int.tryParse(json['qty_before']?.toString() ?? '0') ?? 0,
      qtyAfter: int.tryParse(json['qty_after']?.toString() ?? '0') ?? 0,
      referenceType: json['reference_type']?.toString() ?? '',
      referenceId: json['reference_id']?.toString(),
      referencePart: json['reference_part']?.toString(),
      notes: json['notes']?.toString(),
      createdBy: json['created_by']?.toString(),
      createdAt: json['created_at']?.toString() ?? '',
    );
  }

  bool get isIn => transactionType == 'IN';
  bool get isOut => transactionType == 'OUT';
}

// Scan In Response
class ScanInResponse {
  final int scanId;
  final String partWss;
  final int qtyAdded;
  final String batchNumber;
  final int newStock;
  final String scanTime;

  ScanInResponse({
    required this.scanId,
    required this.partWss,
    required this.qtyAdded,
    required this.batchNumber,
    required this.newStock,
    required this.scanTime,
  });

  factory ScanInResponse.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>?;
    return ScanInResponse(
      scanId: int.tryParse(data?['scan_id']?.toString() ?? '0') ?? 0,
      partWss: data?['part_wss']?.toString() ?? '',
      qtyAdded: int.tryParse(data?['qty_added']?.toString() ?? '0') ?? 0,
      batchNumber: data?['batch_number']?.toString() ?? '',
      newStock: int.tryParse(data?['new_stock']?.toString() ?? '0') ?? 0,
      scanTime: data?['scan_time']?.toString() ?? '',
    );
  }
}

/// Model for Scan Check Result
class ScanCheckResult {
  final bool isScanned;
  final ScanInfo? scanInfo;

  ScanCheckResult({required this.isScanned, this.scanInfo});

  factory ScanCheckResult.fromJson(Map<String, dynamic> json) {
    return ScanCheckResult(
      isScanned: json['is_scanned'] == true || json['is_scanned'] == 1,
      scanInfo: json['scan_info'] != null
          ? ScanInfo.fromJson(json['scan_info'])
          : null,
    );
  }
}

/// Model for previous scan info
class ScanInfo {
  final int id;
  final String partWss;
  final int qty;
  final String? batchNumber;
  final String? scanTime;
  final String? scannedBy;

  ScanInfo({
    required this.id,
    required this.partWss,
    required this.qty,
    this.batchNumber,
    this.scanTime,
    this.scannedBy,
  });

  factory ScanInfo.fromJson(Map<String, dynamic> json) {
    return ScanInfo(
      id: int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      partWss: json['part_wss'] ?? '',
      qty: int.tryParse(json['qty']?.toString() ?? '0') ?? 0,
      batchNumber: json['batch_number'],
      scanTime: json['scan_time'],
      scannedBy: json['scanned_by'],
    );
  }
}
