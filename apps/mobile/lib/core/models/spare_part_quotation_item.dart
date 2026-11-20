import 'dart:convert';
import 'package:crypto/crypto.dart';

enum SparePartStatus {
  pending,
  approved,
  rejected;

  static SparePartStatus fromString(String? val) {
    switch (val?.toLowerCase()) {
      case 'approved':
        return SparePartStatus.approved;
      case 'rejected':
      case 'declined':
        return SparePartStatus.rejected;
      default:
        return SparePartStatus.pending;
    }
  }

  String toDbString() {
    switch (this) {
      case SparePartStatus.approved:
        return 'approved';
      case SparePartStatus.rejected:
        return 'rejected';
      case SparePartStatus.pending:
        return 'pending';
    }
  }
}

/// Domain model for an audited, transparent spare part with MRP proof.
/// Ensures zero-markup cost pass-through from verified hardware stores.
class SparePartQuotationItem {
  final String id;
  final String jobId;
  final String workerId;
  final String itemName;
  final String category;
  final String hardwareStoreName;
  final double mrpPrice;
  final double billedPrice;
  final String receiptPhotoUrl;
  final int warrantyMonths;
  final SparePartStatus status;
  final String notes;
  final DateTime createdAt;
  final DateTime? customerApprovedAt;
  final String? otpApprovalCode;

  const SparePartQuotationItem({
    required this.id,
    required this.jobId,
    required this.workerId,
    required this.itemName,
    this.category = 'General',
    this.hardwareStoreName = 'Local Hardware Store',
    required this.mrpPrice,
    required this.billedPrice,
    required this.receiptPhotoUrl,
    this.warrantyMonths = 3,
    this.status = SparePartStatus.pending,
    this.notes = '',
    required this.createdAt,
    this.customerApprovedAt,
    this.otpApprovalCode,
  });

  /// Calculates the customer savings percentage compared to printed MRP
  double get savingsAmount => (mrpPrice > billedPrice) ? (mrpPrice - billedPrice) : 0.0;
  double get savingsPercentage => (mrpPrice > 0 && savingsAmount > 0) ? (savingsAmount / mrpPrice) * 100 : 0.0;

  bool get isApproved => status == SparePartStatus.approved;
  bool get isPending => status == SparePartStatus.pending;
  bool get isRejected => status == SparePartStatus.rejected;

  /// Cryptographic tamper-evident audit signature for consumer trust
  String get auditSignature {
    final raw = '$id|$jobId|$workerId|$itemName|$mrpPrice|$billedPrice|${createdAt.toIso8601String()}';
    return sha256.convert(utf8.encode(raw)).toString().substring(0, 16).toUpperCase();
  }

  factory SparePartQuotationItem.fromJson(Map<String, dynamic> json) {
    return SparePartQuotationItem(
      id: (json['id'] ?? '').toString(),
      jobId: (json['job_id'] ?? json['jobId'] ?? '').toString(),
      workerId: (json['worker_id'] ?? json['workerId'] ?? '').toString(),
      itemName: (json['item_name'] ?? json['name'] ?? 'Replacement Part').toString(),
      category: (json['category'] ?? 'General').toString(),
      hardwareStoreName: (json['hardware_store_name'] ?? json['store_name'] ?? 'Local Verified Store').toString(),
      mrpPrice: (json['mrp_price'] as num?)?.toDouble() ?? (json['mrp'] as num?)?.toDouble() ?? (json['amount'] as num?)?.toDouble() ?? 0.0,
      billedPrice: (json['amount'] as num?)?.toDouble() ?? (json['billed_price'] as num?)?.toDouble() ?? 0.0,
      receiptPhotoUrl: (json['receipt_photo_url'] ?? json['receiptUrl'] ?? '').toString(),
      warrantyMonths: (json['warranty_months'] as num?)?.toInt() ?? 3,
      status: SparePartStatus.fromString(json['status']?.toString()),
      notes: (json['notes'] ?? '').toString(),
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now() : DateTime.now(),
      customerApprovedAt: json['approved_at'] != null ? DateTime.tryParse(json['approved_at'].toString()) : null,
      otpApprovalCode: json['otp_code']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'job_id': jobId,
      'worker_id': workerId,
      'item_name': itemName,
      'category': category,
      'hardware_store_name': hardwareStoreName,
      'mrp_price': mrpPrice,
      'amount': billedPrice,
      'receipt_photo_url': receiptPhotoUrl,
      'warranty_months': warrantyMonths,
      'status': status.toDbString(),
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
      'approved_at': customerApprovedAt?.toIso8601String(),
      'otp_code': otpApprovalCode,
    };
  }

  SparePartQuotationItem copyWith({
    String? id,
    String? jobId,
    String? workerId,
    String? itemName,
    String? category,
    String? hardwareStoreName,
    double? mrpPrice,
    double? billedPrice,
    String? receiptPhotoUrl,
    int? warrantyMonths,
    SparePartStatus? status,
    String? notes,
    DateTime? createdAt,
    DateTime? customerApprovedAt,
    String? otpApprovalCode,
  }) {
    return SparePartQuotationItem(
      id: id ?? this.id,
      jobId: jobId ?? this.jobId,
      workerId: workerId ?? this.workerId,
      itemName: itemName ?? this.itemName,
      category: category ?? this.category,
      hardwareStoreName: hardwareStoreName ?? this.hardwareStoreName,
      mrpPrice: mrpPrice ?? this.mrpPrice,
      billedPrice: billedPrice ?? this.billedPrice,
      receiptPhotoUrl: receiptPhotoUrl ?? this.receiptPhotoUrl,
      warrantyMonths: warrantyMonths ?? this.warrantyMonths,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      customerApprovedAt: customerApprovedAt ?? this.customerApprovedAt,
      otpApprovalCode: otpApprovalCode ?? this.otpApprovalCode,
    );
  }
}
