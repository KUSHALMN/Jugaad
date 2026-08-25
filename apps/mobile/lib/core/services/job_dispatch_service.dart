import 'package:firebase_auth/firebase_auth.dart';
import '../../core/services/api_service.dart';
import '../../core/config/supabase_config.dart';
import 'package:flutter/foundation.dart';

/// Service for real-time job dispatch operations.
/// Handles job posting, status watching, and worker interactions.
class JobDispatchService {
  static final JobDispatchService _instance = JobDispatchService._internal();
  factory JobDispatchService() => _instance;
  JobDispatchService._internal();

  /// Set of job IDs explicitly rejected/passed by this worker in the current session.
  final Set<String> ignoredJobIds = {};

  // ─── Post Job ─────────────────────────────────────────────
  /// Creates a new job request via the backend API.
  /// Returns the job_id on success.
  Future<String> postJob({
    required String skill,
    required double lat,
    required double lng,
    required String description,
    String urgency = 'now',
    double budget = 0,
    String category = '',
    DateTime? scheduledAt,
  }) async {
    try {
      final response = await ApiService.client.post(
        '/v1/jobs',
        data: {
          'skill': skill,
          'lat': lat,
          'lng': lng,
          'description': description,
          'urgency': urgency,
          'budget': budget,
          'category': category,
          if (scheduledAt != null) 'scheduled_at': scheduledAt.toIso8601String(),
        },
      );
      final data = response.data;
      debugPrint('[JOB_DISPATCH] Job created: ${data['job_id']}');
      return data['job_id'] as String;
    } catch (e) {
      debugPrint('[JOB_DISPATCH] Error posting job: $e');
      rethrow;
    }
  }

  // ─── Watch Job (Real-time Supabase) ───────────────────────
  /// Returns a real-time stream of the job document.
  /// Use with StreamBuilder to react to status changes.
  Stream<Map<String, dynamic>?> watchJob(String jobId) {
    return SupabaseConfig.client
        .from('jobs')
        .stream(primaryKey: ['id'])
        .eq('id', jobId)
        .map((rows) => rows.isNotEmpty ? rows.first : null);
  }

  // ─── Accept Job (Worker) ──────────────────────────────────
  /// Worker accepts a job. Sends worker_id and expected version.
  /// Returns response data on success.
  /// Throws on 409 (taken) or 410 (expired).
  Future<Map<String, dynamic>> acceptJob(String jobId) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw Exception('Not authenticated');

    // Get current job version
    final jobData = await ApiService().getJob(jobId);
    final expectedVersion = jobData['version'] as int? ?? 1;

    final response = await ApiService.client.post(
      '/v1/jobs/$jobId/accept',
      data: {
        'worker_id': uid,
        'expected_version': expectedVersion,
      },
    );
    debugPrint('[JOB_DISPATCH] Accept response: ${response.data}');
    return response.data;
  }

  // ─── Reject Job (Worker) ──────────────────────────────────
  /// Worker rejects/declines a job offer.
  Future<void> rejectJob(String jobId, {String reason = ''}) async {
    ignoredJobIds.add(jobId);
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw Exception('Not authenticated');

    await ApiService.client.post(
      '/v1/jobs/$jobId/reject',
      data: {
        'worker_id': uid,
        'reason': reason,
      },
    );
    debugPrint('[JOB_DISPATCH] Job rejected: $jobId');
  }

  // ─── Cancel Job (Customer) ────────────────────────────────
  /// Customer cancels a job request.
  Future<void> cancelJob(String jobId) async {
    await ApiService().deleteJob(jobId);
    debugPrint('[JOB_DISPATCH] Job cancelled: $jobId');
  }

  // ─── Acknowledge Arrival (Worker) ─────────────────────────
  /// Worker confirms arrival at customer location.
  Future<void> acknowledgeArrival(String jobId) async {
    await ApiService().ackJob(jobId);
    debugPrint('[JOB_DISPATCH] Job acknowledged: $jobId');
  }

  // ─── Respond to Job Request (Worker) ──────────────────────
  Future<Map<String, dynamic>> respondJobRequest(String jobRequestId, {required String action}) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw Exception('Not authenticated');

    final response = await ApiService.client.post(
      '/v1/jobs/$jobRequestId/respond',
      data: {
        'worker_id': uid,
        'action': action,
      },
    );
    debugPrint('[JOB_DISPATCH] Respond response: ${response.data}');
    return response.data as Map<String, dynamic>;
  }

  // ─── Create Job Request (User) ────────────────────────────
  Future<Map<String, dynamic>> createJobRequest({
    required String serviceType,
    required double lat,
    required double lng,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw Exception('Not authenticated');

    final response = await ApiService.client.post(
      '/v1/jobs/request',
      data: {
        'user_id': uid,
        'service_type': serviceType,
        'lat': lat,
        'lng': lng,
      },
    );
    debugPrint('[JOB_DISPATCH] Create request response: ${response.data}');
    return response.data as Map<String, dynamic>;
  }

  // ─── Cancel Job Request (User) ────────────────────────────
  Future<void> cancelJobRequest(String jobRequestId) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw Exception('Not authenticated');

    await ApiService.client.post(
      '/v1/jobs/$jobRequestId/cancel',
      data: {
        'user_id': uid,
      },
    );
    debugPrint('[JOB_DISPATCH] Job request cancelled: $jobRequestId');
  }

  // ─── Poll Job Request Status (User Safety Net) ───────────
  Future<Map<String, dynamic>> getJobRequestStatus(String jobRequestId) async {
    final response = await ApiService.client.get('/v1/jobs/request/$jobRequestId');
    return response.data as Map<String, dynamic>;
  }
}

