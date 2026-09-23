import 'dart:convert';

/// Represents the status of an offline mutation in the retry queue.
enum MutationStatus {
  pending,
  syncing,
  succeeded,
  failed,
}

/// A persistent mutation task representing a worker or user action executed while
/// disconnected or in low-bandwidth network environments.
class OfflineMutation {
  final String id;
  final String jobId;
  final String actionType; // e.g., 'confirm_on_the_way', 'ack_arrival', 'complete_job', 'price_change', 'location_ping'
  final Map<String, dynamic> payload;
  final DateTime createdAt;
  int retryCount;
  MutationStatus status;
  String? lastError;

  OfflineMutation({
    required this.id,
    required this.jobId,
    required this.actionType,
    required this.payload,
    required this.createdAt,
    this.retryCount = 0,
    this.status = MutationStatus.pending,
    this.lastError,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'job_id': jobId,
      'action_type': actionType,
      'payload': payload,
      'created_at': createdAt.toIso8601String(),
      'retry_count': retryCount,
      'status': status.name,
      'last_error': lastError,
    };
  }

  factory OfflineMutation.fromMap(Map<String, dynamic> map) {
    return OfflineMutation(
      id: map['id'] as String,
      jobId: map['job_id'] as String,
      actionType: map['action_type'] as String,
      payload: Map<String, dynamic>.from(map['payload'] as Map? ?? {}),
      createdAt: DateTime.tryParse(map['created_at'] as String? ?? '') ?? DateTime.now(),
      retryCount: (map['retry_count'] as num?)?.toInt() ?? 0,
      status: MutationStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => MutationStatus.pending,
      ),
      lastError: map['last_error'] as String?,
    );
  }

  String toJson() => jsonEncode(toMap());

  factory OfflineMutation.fromJson(String source) =>
      OfflineMutation.fromMap(jsonDecode(source) as Map<String, dynamic>);
}
