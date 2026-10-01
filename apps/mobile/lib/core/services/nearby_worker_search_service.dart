// lib/core/services/nearby_worker_search_service.dart
// ═══════════════════════════════════════════════════════════════════
// Production-grade nearby worker search service.
//
// Calls the FastAPI GET /workers/search endpoint which uses PostGIS
// ST_DWithin + GiST index for fast spatial queries.
//
// Features:
//   - Auto-radius expansion: 5km → 10km if zero results (Uber-style)
//   - Returns typed List<NearbyWorkerModel> (not raw JSON)
//   - GPS coordinate acquisition with graceful fallbacks
//   - Full error handling with meaningful user-facing messages
//   - Pagination support (page + hasMore)
// ═══════════════════════════════════════════════════════════════════

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import '../models/nearby_worker_model.dart';
import '../network/dio_client.dart';

/// Result wrapper for nearby worker search operations.
class NearbyWorkerSearchResult {
  /// List of workers sorted by distance (nearest first)
  final List<NearbyWorkerModel> workers;

  /// Total number of matching workers across all pages
  final int total;

  /// Current page index (zero-based)
  final int page;

  /// Whether more pages are available
  final bool hasMore;

  /// The actual radius used for this search (may differ from requested
  /// if auto-expansion was triggered)
  final double radiusKm;

  /// True if the backend auto-expanded the search radius because
  /// zero workers were found in the originally requested radius
  final bool expandedRadius;

  const NearbyWorkerSearchResult({
    required this.workers,
    required this.total,
    required this.page,
    required this.hasMore,
    required this.radiusKm,
    required this.expandedRadius,
  });

  /// True if zero workers were found even after radius expansion
  bool get isEmpty => workers.isEmpty;

  @override
  String toString() =>
      'NearbyWorkerSearchResult(total: $total, page: $page, '
      'radius: ${radiusKm}km, expanded: $expandedRadius)';
}

/// Service for searching nearby workers using PostGIS spatial queries.
class NearbyWorkerSearchService {
  // ─── Singleton ──────────────────────────────────────────────────
  static final NearbyWorkerSearchService _instance =
      NearbyWorkerSearchService._internal();
  factory NearbyWorkerSearchService() => _instance;
  NearbyWorkerSearchService._internal();

  // ─── Fallback coordinates (Mysuru center) ───────────────────────
  // Used when GPS is unavailable or permissions are denied.
  // Mysuru Palace coordinates — center of the service area.
  static const double _fallbackLat = 12.3051;
  static const double _fallbackLng = 76.6551;

  // ─── Search defaults ────────────────────────────────────────────
  static const double defaultRadiusKm = 5.0;
  static const int defaultLimit = 10;

  // ─── Performance Caches ─────────────────────────────────────────
  (double, double)? _cachedCoords;
  DateTime? _cachedCoordsTime;
  static const Duration _coordsCacheTtl = Duration(seconds: 30);

  final Map<String, (DateTime, NearbyWorkerSearchResult)> _searchCache = {};
  static const Duration _searchCacheTtl = Duration(seconds: 15);

  /// Search for nearby workers by calling the FastAPI backend.
  ///
  /// [lat], [lng] — User's GPS coordinates.
  /// [radiusKm] — Search radius in km (default 5.0, server expands to 10 if empty).
  /// [serviceType] — Optional category filter (e.g. 'electrician', 'plumber').
  /// [page] — Zero-based page index for pagination.
  /// [limit] — Results per page (clamped to [1, 50] server-side).
  ///
  /// Returns a [NearbyWorkerSearchResult] with typed [NearbyWorkerModel] objects.
  Future<NearbyWorkerSearchResult> searchNearbyWorkers({
    required double lat,
    required double lng,
    double radiusKm = defaultRadiusKm,
    String? serviceType,
    int page = 0,
    int limit = defaultLimit,
  }) async {
    final cacheKey = '${lat.toStringAsFixed(3)}_${lng.toStringAsFixed(3)}_${serviceType ?? "all"}_${radiusKm}_$page';
    final cached = _searchCache[cacheKey];
    if (cached != null && DateTime.now().difference(cached.$1) < _searchCacheTtl) {
      debugPrint('[SEARCH] Returning memoized search results for $cacheKey');
      return cached.$2;
    }

    debugPrint(
      '[SEARCH] Searching nearby workers: '
      'lat=$lat, lng=$lng, radius=${radiusKm}km, '
      'category=$serviceType, page=$page',
    );

    try {
      final response = await DioClient.instance.get(
        '/v1/workers/search',
        queryParameters: {
          'lat': lat,
          'lng': lng,
          'radius_km': radiusKm,
          if (serviceType != null && serviceType.isNotEmpty)
            'service_type': serviceType,
          'page': page,
          'limit': limit,
        },
      );

      final data = response.data as Map<String, dynamic>;

      // Parse the workers list into typed NearbyWorkerModel objects
      final List<NearbyWorkerModel> workers = (data['workers'] as List<dynamic>?)
              ?.map((w) =>
                  NearbyWorkerModel.fromJson(w as Map<String, dynamic>))
              .toList() ??
          [];

      final result = NearbyWorkerSearchResult(
        workers: workers,
        total: data['total'] as int? ?? 0,
        page: data['page'] as int? ?? page,
        hasMore: data['has_more'] as bool? ?? false,
        radiusKm: (data['radius_km'] as num?)?.toDouble() ?? radiusKm,
        expandedRadius: data['expanded_radius'] as bool? ?? false,
      );

      if (_searchCache.length > 50) {
        _searchCache.clear();
      }
      _searchCache[cacheKey] = (DateTime.now(), result);

      debugPrint(
        '[SEARCH] Found ${result.total} workers '
        '(page ${result.page}, radius ${result.radiusKm}km, '
        'expanded: ${result.expandedRadius})',
      );

      return result;
    } catch (e) {
      debugPrint('[SEARCH] Error searching workers: $e');
      rethrow;
    }
  }

  /// Convenience method: search using the device's current GPS coordinates.
  ///
  /// 1. Requests location permission if not already granted
  /// 2. Acquires the current position (with fast cached fallback)
  /// 3. Falls back to Mysuru center if GPS is unavailable
  /// 4. Calls [searchNearbyWorkers] with the resolved coordinates
  Future<NearbyWorkerSearchResult> searchFromCurrentLocation({
    double radiusKm = defaultRadiusKm,
    String? serviceType,
    int page = 0,
    int limit = defaultLimit,
  }) async {
    final position = await _resolveCurrentPosition();
    return searchNearbyWorkers(
      lat: position.$1,
      lng: position.$2,
      radiusKm: radiusKm,
      serviceType: serviceType,
      page: page,
      limit: limit,
    );
  }

  /// Update the authenticated worker's location on the backend.
  ///
  /// Calls PATCH /v1/workers/location which uses the PostGIS
  /// update_worker_location RPC to atomically set the geography point.
  Future<void> updateWorkerLocation({
    required double lat,
    required double lng,
    bool isAvailable = true,
  }) async {
    debugPrint('[LOCATION] Updating worker location: lat=$lat, lng=$lng');

    try {
      await DioClient.instance.patch(
        '/v1/workers/location',
        data: {
          'lat': lat,
          'lng': lng,
          'is_available': isAvailable,
        },
      );
      debugPrint('[LOCATION] Worker location updated successfully');
    } catch (e) {
      debugPrint('[LOCATION] Failed to update worker location: $e');
      rethrow;
    }
  }

  /// Resolve the user's current GPS position with smart caching.
  /// Returns (lat, lng) tuple.
  /// Checks memory cache, then last known position, then acquires a fast fix.
  Future<(double, double)> _resolveCurrentPosition() async {
    // 1. Fast in-memory cache check (<30 seconds old)
    if (_cachedCoords != null && _cachedCoordsTime != null) {
      if (DateTime.now().difference(_cachedCoordsTime!) < _coordsCacheTtl) {
        return _cachedCoords!;
      }
    }

    try {
      // Check if location services are enabled
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('[LOCATION] Location services disabled. Using Mysuru fallback.');
        return (_fallbackLat, _fallbackLng);
      }

      // Check and request location permission
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          debugPrint('[LOCATION] Location permission denied. Using Mysuru fallback.');
          return (_fallbackLat, _fallbackLng);
        }
      }
      if (permission == LocationPermission.deniedForever) {
        debugPrint('[LOCATION] Location permission permanently denied. Using Mysuru fallback.');
        return (_fallbackLat, _fallbackLng);
      }

      // 2. Check if a recent last known position is available (instant 0ms resolution)
      final lastKnown = await Geolocator.getLastKnownPosition();
      if (lastKnown != null &&
          DateTime.now().difference(lastKnown.timestamp) < const Duration(seconds: 45)) {
        final coords = (lastKnown.latitude, lastKnown.longitude);
        _cachedCoords = coords;
        _cachedCoordsTime = DateTime.now();
        debugPrint('[LOCATION] Used recent last-known position: (${lastKnown.latitude}, ${lastKnown.longitude})');
        return coords;
      }

      // 3. Fast GPS fix with 4s timeout (medium accuracy locks much faster than high)
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 4),
        ),
      );

      final coords = (position.latitude, position.longitude);
      _cachedCoords = coords;
      _cachedCoordsTime = DateTime.now();
      debugPrint('[LOCATION] GPS position acquired: (${position.latitude}, ${position.longitude})');
      return coords;
    } catch (e) {
      debugPrint('[LOCATION] Error or timeout acquiring position: $e. Checking last known...');
      try {
        final fallbackLast = await Geolocator.getLastKnownPosition();
        if (fallbackLast != null) {
          final coords = (fallbackLast.latitude, fallbackLast.longitude);
          _cachedCoords = coords;
          _cachedCoordsTime = DateTime.now();
          return coords;
        }
      } catch (_) {}
      return (_fallbackLat, _fallbackLng);
    }
  }
}
