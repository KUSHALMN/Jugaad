import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';


/// Replaces FirestoreService — single source of truth for all Supabase
/// read/write operations used by both the Worker Portal and User Portal.
///
/// Supabase tables (replaces Firestore collections):
///   workers     — worker profile (FK to users)
///   users       — user profile
///   bookings    — booking records
///   jobs        — job records
///   reviews     — reviews (flat table, no subcollections)
///   payments    — payment records
class SupabaseService {
  static final SupabaseService _instance = SupabaseService._internal();
  factory SupabaseService() => _instance;
  SupabaseService._internal();

  final SupabaseClient _client = Supabase.instance.client;

  // In-memory TTL caches
  Map<String, int>? _cachedWorkerCounts;
  DateTime? _workerCountsCacheTime;

  final Map<String, List<Map<String, dynamic>>> _cachedTopRatedWorkers = {};
  final Map<String, DateTime> _topRatedCacheTime = {};

  /// Invalidate worker caches when worker statuses change
  void invalidateWorkerCaches() {
    _cachedWorkerCounts = null;
    _workerCountsCacheTime = null;
    _cachedTopRatedWorkers.clear();
    _topRatedCacheTime.clear();
  }

  // ─── Worker Streams ──────────────────────────────────────────────────────

  /// Real-time stream of the worker record for [uid].
  /// BEFORE: _workers.doc(uid).snapshots()
  /// AFTER:  Supabase realtime stream
  Stream<List<Map<String, dynamic>>> workerStream(String uid) =>
      _client.from('workers').stream(primaryKey: ['id']).eq('id', uid);

  /// Real-time stream of all bookings where worker_id == [uid] and
  /// status is in [statuses]. Ordered by created_at descending.
  /// BEFORE: _bookings.where('workerId', isEqualTo: uid).snapshots()
  Stream<List<Map<String, dynamic>>> workerBookingsStream(
    String uid, {
    List<String> statuses = const ['completed'],
  }) =>
      _client
          .from('bookings')
          .stream(primaryKey: ['id'])
          .eq('worker_id', uid)
          .map((data) =>
              data.where((b) => statuses.contains(b['status'])).toList()
                ..sort((a, b) => (b['created_at'] ?? '')
                    .compareTo(a['created_at'] ?? '')));

  /// One-time fetch of completed bookings for a worker (earnings computation).
  /// BEFORE: _bookings.where('workerId', isEqualTo: uid).where('status', isEqualTo: 'completed').get()
  Future<List<Map<String, dynamic>>> fetchCompletedBookings(String uid) async {
    final response = await _client
        .from('bookings')
        .select()
        .eq('worker_id', uid)
        .eq('status', 'completed')
        .order('created_at', ascending: false)
        .limit(100);
    return List<Map<String, dynamic>>.from(response);
  }

  // ─── User Streams ────────────────────────────────────────────────────────

  /// Real-time stream of the user record for [uid].
  /// BEFORE: _users.doc(uid).snapshots()
  Stream<List<Map<String, dynamic>>> userStream(String uid) =>
      _client.from('users').stream(primaryKey: ['id']).eq('id', uid);

  /// Real-time stream of recent bookings for [uid] as a customer.
  /// BEFORE: _bookings.where('userId', isEqualTo: uid).snapshots()
  Stream<List<Map<String, dynamic>>> userBookingsStream(
    String uid, {
    List<String> statuses = const ['completed', 'cancelled'],
    int limit = 3,
  }) =>
      _client
          .from('bookings')
          .stream(primaryKey: ['id'])
          .eq('employer_id', uid)
          .map((data) {
            // Fix N5: ..take(limit) on a list cascade is a no-op; use take().toList()
            final filtered = data
                .where((b) => statuses.contains(b['status']))
                .toList()
              ..sort((a, b) => (b['created_at'] ?? '')
                  .compareTo(a['created_at'] ?? ''));
            return filtered.take(limit).toList();
          });

  // ─── Nearby Workers (for User Home service cards) ────────────────────────

  /// Returns a map of `skill → onlineWorkerCount` for the service grid.
  /// BEFORE: _workers.where('isOnline', isEqualTo: true).get()
  /// AFTER:  Supabase query on workers.is_available (cached with 30s TTL)
  Future<Map<String, int>> fetchNearbyWorkerCounts() async {
    if (_cachedWorkerCounts != null &&
        _workerCountsCacheTime != null &&
        DateTime.now().difference(_workerCountsCacheTime!) < const Duration(seconds: 30)) {
      return _cachedWorkerCounts!;
    }
    try {
      final response = await _client
          .from('workers')
          .select('skills')
          .eq('is_available', true);

      final Map<String, int> counts = {};
      for (final row in response) {
        // Fix C6: guard against null skills column
        final rawSkills = row['skills'];
        if (rawSkills == null) continue;
        final skills = List<String>.from(rawSkills as List);
        for (final s in skills) {
          counts[s] = (counts[s] ?? 0) + 1;
        }
      }
      _cachedWorkerCounts = counts;
      _workerCountsCacheTime = DateTime.now();
      return counts;
    } catch (e) {
      debugPrint('[SupabaseService] fetchNearbyWorkerCounts error: $e');
      return _cachedWorkerCounts ?? {};
    }
  }

  /// Fetches approved workers filtered by category/skill, sorted by rating DESC (cached with 60s TTL).
  Future<List<Map<String, dynamic>>> fetchTopRatedWorkersByCategory({
    String? category,
    int limit = 10,
  }) async {
    final cacheKey = '${category ?? "all"}_$limit';
    final cachedTime = _topRatedCacheTime[cacheKey];
    if (_cachedTopRatedWorkers.containsKey(cacheKey) &&
        cachedTime != null &&
        DateTime.now().difference(cachedTime) < const Duration(seconds: 60)) {
      return _cachedTopRatedWorkers[cacheKey]!;
    }
    try {
      final response = await _client
          .from('workers')
          .select('id, name, rating, total_jobs, totalJobsCompleted, skills, specialities, category, work_category, hourly_rate, is_available, status, approval_status, is_verified, isVerified, area, phone')
          .order('rating', ascending: false)
          .limit(50);

      List<Map<String, dynamic>> workers = List<Map<String, dynamic>>.from(response);

      // Filter to approved workers
      workers = workers.where((w) {
        final st = (w['status'] ?? w['approval_status'] ?? 'approved').toString().toLowerCase();
        return st == 'approved';
      }).toList();

      if (category != null && category.trim().isNotEmpty && category.toLowerCase() != 'all') {
        final normalizedCat = category.toLowerCase().replaceAll(' ', '_');
        final filtered = workers.where((w) {
          final cat = (w['category'] ?? w['work_category'] ?? '').toString().toLowerCase();
          final skills = List<String>.from(w['skills'] as List? ?? []).map((s) => s.toLowerCase().replaceAll(' ', '_')).toList();
          final specs = List<String>.from(w['specialities'] as List? ?? []).map((s) => s.toLowerCase().replaceAll(' ', '_')).toList();
          
          return cat.contains(normalizedCat) ||
                 normalizedCat.contains(cat) ||
                 skills.any((s) => s.contains(normalizedCat) || normalizedCat.contains(s)) ||
                 specs.any((s) => s.contains(normalizedCat) || normalizedCat.contains(s));
        }).toList();

        if (filtered.isNotEmpty) {
          workers = filtered;
        }
      }

      final result = workers.take(limit).toList();
      _cachedTopRatedWorkers[cacheKey] = result;
      _topRatedCacheTime[cacheKey] = DateTime.now();
      return result;
    } catch (e) {
      debugPrint('[SupabaseService] fetchTopRatedWorkersByCategory error: $e');
      return _cachedTopRatedWorkers[cacheKey] ?? [];
    }
  }

      // Sort by rating DESC, total_jobs DESC
      workers.sort((a, b) {
        final double rA = (a['rating'] as num?)?.toDouble() ?? 0.0;
        final double rB = (b['rating'] as num?)?.toDouble() ?? 0.0;
        if (rB != rA) return rB.compareTo(rA);
        final int jA = (a['total_jobs'] ?? a['totalJobsCompleted'] as num?)?.toInt() ?? 0;
        final int jB = (b['total_jobs'] ?? b['totalJobsCompleted'] as num?)?.toInt() ?? 0;
        return jB.compareTo(jA);
      });

      return workers.take(limit).toList();
    } catch (e) {
      debugPrint('[SupabaseService] fetchTopRatedWorkersByCategory error: $e');
      return [];
    }
  }

  // ─── Earnings Computation (client-side, no extra schema fields) ──────────

  /// Filters [rows] to bookings whose `created_at` falls on today (local).
  static double computeTodayEarnings(List<Map<String, dynamic>> rows) {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    double total = 0;
    for (final row in rows) {
      final dateStr = row['created_at'] as String?;
      if (dateStr == null) continue;
      final date = DateTime.parse(dateStr).toLocal();
      if (!date.isBefore(todayStart)) {
        total += (row['amount'] as num? ?? 0).toDouble();
      }
    }
    return total;
  }

  /// Filters [rows] to bookings whose `created_at` falls in current week.
  static double computeWeekEarnings(List<Map<String, dynamic>> rows) {
    final now = DateTime.now();
    final weekStart = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: now.weekday - 1));
    double total = 0;
    for (final row in rows) {
      final dateStr = row['created_at'] as String?;
      if (dateStr == null) continue;
      final date = DateTime.parse(dateStr).toLocal();
      if (!date.isBefore(weekStart)) {
        total += (row['amount'] as num? ?? 0).toDouble();
      }
    }
    return total;
  }

  /// Count of bookings in current week.
  static int computeWeekJobCount(List<Map<String, dynamic>> rows) {
    final now = DateTime.now();
    final weekStart = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: now.weekday - 1));
    int count = 0;
    for (final row in rows) {
      final dateStr = row['created_at'] as String?;
      if (dateStr == null) continue;
      final date = DateTime.parse(dateStr).toLocal();
      if (!date.isBefore(weekStart)) count++;
    }
    return count;
  }

  // ─── Worker Online Status ────────────────────────────────────────────────

  /// Writes `is_available` to the worker record.
  /// BEFORE: _workers.doc(uid).update({'isOnline': isOnline})
  Future<void> setWorkerOnline(String uid, {required bool isOnline}) async {
    await setWorkerAvailabilityState(uid, isAvailable: isOnline, emergencyAvailable: false);
  }

  /// Writes `is_available` and `emergency_available` to the worker record.
  Future<void> setWorkerAvailabilityState(
    String uid, {
    required bool isAvailable,
    required bool emergencyAvailable,
  }) async {
    await _client.from('workers').update({
      'is_available': isAvailable,
      'emergency_available': emergencyAvailable,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', uid);
  }

  // ─── Payout / UPI ────────────────────────────────────────────────────────

  /// Updates UPI ID for the worker.
  /// BEFORE: _workers.doc(uid).update({'payoutSettings.upiId': upiId})
  Future<void> saveWorkerUpi(String uid, String upiId) async {
    await _client.from('workers').update({
      'upi_id': upiId,
    }).eq('id', uid);
  }

  /// Real-time stream of pending payout requests for [uid].
  Stream<List<Map<String, dynamic>>> pendingPayoutsStream(String uid) =>
      _client
          .from('payout_requests')
          .stream(primaryKey: ['id'])
          .eq('worker_id', uid)
          .map((data) =>
              data.where((p) => p['status'] == 'pending').toList());

  /// Creates a payout request and decrements withdrawable balance.
  /// BEFORE: Firestore batch write
  /// AFTER:  Sequential Supabase inserts (consider RPC for atomicity)
  Future<void> requestPayout({
    required String uid,
    required double amount,
    required String upiId,
  }) async {
    // Fix C2: Use a Postgres RPC to atomically insert payout + decrement balance.
    // This prevents race conditions where two simultaneous withdrawals could overdraw.
    try {
      await _client.rpc('create_payout_request', params: {
        'p_worker_id': uid,
        'p_amount': amount,
        'p_upi_id': upiId,
      });
    } catch (e) {
      // Fallback: if the RPC doesn't exist yet, do sequential inserts.
      // WARNING: This is NOT atomic — migrate to RPC ASAP.
      debugPrint('[SupabaseService] RPC create_payout_request failed, using non-atomic fallback: $e');
      await _client.from('payout_requests').insert({
        'worker_id': uid,
        'amount': amount,
        'upi_id': upiId,
        'status': 'pending',
      });
      // Decrement withdrawable_balance directly (non-atomic fallback)
      await _client.rpc('decrement_worker_balance', params: {
        'p_worker_id': uid,
        'p_amount': amount,
      });
    }
  }

  // ─── Realtime Job Status Updates ─────────────────────────────────────────

  /// Subscribe to job status changes in real-time.
  /// BEFORE: _db.collection('jobs').doc(jobId).snapshots()
  /// AFTER:  Supabase Realtime channel
  RealtimeChannel subscribeToJob(String jobId, Function(Map) onUpdate) {
    return _client
        .channel('job:$jobId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'jobs',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: jobId,
          ),
          callback: (payload) => onUpdate(payload.newRecord),
        )
        .subscribe();
  }

  /// Get available workers for a specific skill (with realtime).
  /// BEFORE: _db.collection('workers').where('is_available', isEqualTo: true).snapshots()
  Stream<List<Map<String, dynamic>>> getAvailableWorkers(String skill) {
    return _client
        .from('workers')
        .stream(primaryKey: ['id'])
        .eq('is_available', true)
        // Fix C6: guard against null skills column to prevent cast exceptions
        .map((data) => data
            .where((w) => (w['skills'] as List? ?? []).contains(skill))
            .toList());
  }

  /// Get employer's jobs.
  /// BEFORE: _db.collection('jobs').where('employer_id', isEqualTo: uid)
  Future<List<Map<String, dynamic>>> getEmployerJobs(String employerId) async {
    final response = await _client
        .from('jobs')
        .select()
        .eq('employer_id', employerId)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────

  /// Returns the sum of `amount` across pending payouts.
  static double sumPendingPayouts(List<Map<String, dynamic>> rows) {
    double total = 0;
    for (final row in rows) {
      total += (row['amount'] as num? ?? 0).toDouble();
    }
    return total;
  }

  /// Time-of-day greeting string.
  static String timeGreeting() {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 12) {
      return 'Good morning';
    } else if (hour >= 12 && hour < 17) {
      return 'Good afternoon';
    } else if (hour >= 17 && hour < 21) {
      return 'Good evening';
    } else {
      return 'Good night';
    }
  }

  // ─── Chat Messages ────────────────────────────────────────────────────────

  /// Stream messages for a specific [jobId] in real-time, ordered by created_at.
  Stream<List<Map<String, dynamic>>> jobMessagesStream(String jobId) {
    return _client
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('job_id', jobId)
        .map((data) =>
            data.toList()
              ..sort((a, b) => (a['created_at'] ?? '')
                  .compareTo(b['created_at'] ?? '')));
  }

  /// Sends a message.
  Future<void> sendMessage({
    required String jobId,
    required String senderId,
    required String text,
  }) async {
    await _client.from('messages').insert({
      'job_id': jobId,
      'sender_id': senderId,
      'text': text,
    });
  }

  // ─── User Notifications ───────────────────────────────────────────────────

  /// Stream notifications for a user in real-time, ordered by created_at.
  Stream<List<Map<String, dynamic>>> notificationsStream(String uid) {
    return _client
        .from('notifications')
        .stream(primaryKey: ['id'])
        .eq('user_id', uid)
        .map((data) =>
            data.toList()
              ..sort((a, b) => (b['created_at'] ?? '')
                  .compareTo(a['created_at'] ?? '')));
  }
}

