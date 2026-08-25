// lib/core/services/api_service.dart
// ═══════════════════════════════════════════════════════════════════
// Business-level API methods. All HTTP plumbing is delegated to
// DioClient — this file only contains endpoint-specific logic.
// ═══════════════════════════════════════════════════════════════════

import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../network/dio_client.dart';

class ApiService {
  /// Shared Dio instance — delegates to DioClient singleton.
  static Dio get client => DioClient.instance;
  static String get baseUrl => DioClient.baseUrl;

  // ─── Jobs ─────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getJob(String jobId) async {
    final response = await client.get('/v1/jobs/$jobId');
    return response.data;
  }

  Future<Map<String, dynamic>> createJob(Map<String, dynamic> data) async {
    final response = await client.post('/v1/jobs', data: data);
    return response.data;
  }

  Future<void> acceptJob(String jobId, int expectedVersion) async {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    await client.post('/v1/jobs/$jobId/accept', data: {
      'worker_id': uid,
      'expected_version': expectedVersion,
    });
  }

  Future<void> declineJob(String jobId) async {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    await client.post('/v1/jobs/$jobId/reject', data: {
      'worker_id': uid,
      'reason': 'declined',
    });
  }

  Future<void> ackJob(String jobId) async {
    await client.post('/v1/jobs/$jobId/ack');
  }

  Future<void> completeJob(String jobId, {String confirmer = 'user'}) async {
    await client.post('/v1/jobs/$jobId/complete', data: {
      'confirmer': confirmer,
    });
  }

  Future<void> deleteJob(String jobId) async {
    await client.delete('/v1/jobs/$jobId');
  }

  // ─── Payments ─────────────────────────────────────────────────

  Future<Map<String, dynamic>> createRazorpayOrder(String jobId) async {
    final response = await client.post('/v1/jobs/$jobId/create-order');
    return response.data;
  }

  /// Verify Razorpay payment signature server-side after checkout success.
  Future<Map<String, dynamic>> verifyPayment({
    required String orderId,
    required String paymentId,
    required String signature,
  }) async {
    final response = await client.post('/v1/payments/verify', data: {
      'razorpay_order_id': orderId,
      'razorpay_payment_id': paymentId,
      'razorpay_signature': signature,
    });
    return response.data;
  }

  // ─── Users ────────────────────────────────────────────────────

  /// Upload FCM token through the backend API (bypasses RLS issues).
  Future<void> updateFcmToken(String token) async {
    await client.post('/v1/users/me/fcm-token', data: {'token': token});
  }

  /// Syncs the Firebase user to the Supabase users table bypassing RLS.
  // Fix M2: phone is nullable — omit from payload if null to avoid backend constraint errors.
  Future<void> syncUser(String email, String name, String? phone) async {
    await client.post('/v1/users/sync', data: {
      'email': email,
      'name': name,
      if (phone != null && phone.isNotEmpty) 'phone': phone,
    });
  }

  /// Search workers nearby using POSTGIS and Redis caching.
  ///
  /// Returns raw `Map<String, dynamic>` from the backend.
  /// For typed results with [NearbyWorkerModel] objects, use
  /// [NearbyWorkerSearchService.searchNearbyWorkers] instead.
  ///
  /// The backend automatically expands the search radius from 5km to 10km
  /// if zero results are found. Check `response['expanded_radius']` to
  /// know if auto-expansion was triggered.
  Future<Map<String, dynamic>> searchWorkers({
    required double lat,
    required double lng,
    double radiusKm = 5.0,
    String? serviceType,
    int page = 0,
    int limit = 10,
  }) async {
    final response = await client.get('/v1/workers/search', queryParameters: {
      'lat': lat,
      'lng': lng,
      'radius_km': radiusKm,
      if (serviceType != null && serviceType.isNotEmpty) 'service_type': serviceType,
      'page': page,
      'limit': limit,
    });
    return response.data;
  }

  /// Update the authenticated worker's GPS coordinates in Supabase.
  ///
  /// Calls PATCH /v1/workers/location which uses the PostGIS
  /// update_worker_location RPC to atomically set the geography point.
  /// Called when a worker goes online or refreshes their position.
  Future<Map<String, dynamic>> updateWorkerLocation({
    required double lat,
    required double lng,
    bool isAvailable = true,
  }) async {
    final response = await client.patch('/v1/workers/location', data: {
      'lat': lat,
      'lng': lng,
      'is_available': isAvailable,
    });
    return response.data;
  }

  /// Confirm that the worker is on the way for an accepted job.
  ///
  /// Calls POST /v1/jobs/{jobId}/confirm-on-the-way
  Future<Map<String, dynamic>> confirmOnTheWay(String jobId) async {
    final response = await client.post('/v1/jobs/$jobId/confirm-on-the-way');
    return response.data;
  }

  /// Propose a mid-job price change request.
  ///
  /// Calls POST /v1/jobs/{jobId}/price-change
  Future<Map<String, dynamic>> requestPriceChange(
    String jobId,
    double newPrice,
    String reason,
  ) async {
    final response = await client.post(
      '/v1/jobs/$jobId/price-change',
      data: {
        'new_price': newPrice,
        'reason': reason,
      },
    );
    return response.data;
  }

  /// Respond to a pending price change request as the customer.
  ///
  /// Calls POST /v1/jobs/{jobId}/price-change/respond
  Future<Map<String, dynamic>> respondPriceChange(
    String jobId,
    bool approved,
  ) async {
    final response = await client.post(
      '/v1/jobs/$jobId/price-change/respond',
      data: {
        'approved': approved,
      },
    );
    return response.data;
  }

  /// Get public profile of an approved worker.
  Future<Map<String, dynamic>> getWorkerPublicProfile(String workerId) async {
    final response = await client.get('/v1/workers/$workerId/public-profile');
    return response.data;
  }

  /// Get job history for worker.
  Future<List<dynamic>> getWorkerJobHistory() async {
    final response = await client.get('/v1/jobs/worker/history');
    return response.data['jobs'] ?? [];
  }
}



