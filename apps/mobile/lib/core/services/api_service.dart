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

  /// Update user profile through the backend API using service role (bypasses RLS issues).
  Future<void> updateUserProfile({required String name, Map<String, dynamic>? address}) async {
    final payload = <String, dynamic>{'name': name};
    if (address != null) {
      payload['address'] = address;
    }
    await client.put('/v1/users/me', data: payload);
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
    String? area,
    String? division,
    int page = 0,
    int limit = 10,
  }) async {
    final double safeLat = (lat != 0.0) ? lat : 12.3051;
    final double safeLng = (lng != 0.0) ? lng : 76.6551;

    final cleanCategory = (serviceType != null &&
            serviceType.trim().isNotEmpty &&
            serviceType.trim().toLowerCase() != 'all')
        ? serviceType.trim().toLowerCase().replaceAll(' ', '_')
        : null;

    final response = await client.get('/v1/workers/search', queryParameters: {
      'lat': safeLat,
      'lng': safeLng,
      'radius_km': radiusKm,
      'category': ?cleanCategory,
      'service_type': ?cleanCategory,
      if (area != null && area.isNotEmpty) 'area': area,
      if (division != null && division.isNotEmpty) 'division': division,
      'page': page,
      'limit': limit,
    });
    return response.data is Map<String, dynamic>
        ? response.data as Map<String, dynamic>
        : <String, dynamic>{};
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

  /// Start job with customer's 4-digit doorstep PIN
  Future<Map<String, dynamic>> startJobWithPin(String jobId, String pin) async {
    final response = await client.post('/v1/jobs/$jobId/start-with-pin', data: {'pin': pin});
    return response.data;
  }

  /// Complete job with customer's 4-digit inspection PIN
  Future<Map<String, dynamic>> completeJobWithPin(String jobId, String pin) async {
    final response = await client.post('/v1/jobs/$jobId/complete-with-pin', data: {'pin': pin});
    return response.data;
  }

  /// Delete user account and anonymize PII (Google Play & DPDP compliance)
  Future<Map<String, dynamic>> deleteAccount() async {
    final response = await client.post('/v1/users/delete-account');
    return response.data;
  }

  /// Transmit emergency SOS with partner coordinates
  Future<Map<String, dynamic>> sendEmergencySos({
    String? jobId,
    required double lat,
    required double lng,
    int? batteryLevel,
    String? notes,
  }) async {
    final payload = <String, dynamic>{
      'lat': lat,
      'lng': lng,
    };
    if (jobId != null) payload['job_id'] = jobId;
    if (batteryLevel != null) payload['battery_level'] = batteryLevel;
    if (notes != null) payload['notes'] = notes;

    final response = await client.post('/v1/workers/sos', data: payload);
    return response.data;
  }

  /// Discover nearby on-the-way candidate gigs near active job destination
  Future<List<dynamic>> getStackedJobCandidates(String jobId, {double radiusKm = 3.0}) async {
    final response = await client.get('/v1/jobs/$jobId/stacked-candidates', queryParameters: {
      'radius_km': radiusKm,
    });
    return response.data['stacked_candidates'] ?? [];
  }

  /// Add spare part to active job ledger
  Future<Map<String, dynamic>> addSparePart(String jobId, {
    required String name,
    required double price,
    String? receiptUrl,
    String? notes,
  }) async {
    final payload = <String, dynamic>{
      'name': name,
      'price': price,
    };
    if (receiptUrl != null) payload['receipt_url'] = receiptUrl;
    if (notes != null) payload['notes'] = notes;

    final response = await client.post('/v1/jobs/$jobId/spare-parts', data: payload);
    return response.data;
  }
}




