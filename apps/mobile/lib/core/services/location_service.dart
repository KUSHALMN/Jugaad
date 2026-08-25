import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/foundation.dart';
import '../config/supabase_config.dart';

/// Service for real-time worker location tracking and fetching.
/// When worker goes online, starts streaming position updates to Supabase.
class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  StreamSubscription<Position>? _positionSub;
  bool _isTracking = false;
  Position? _lastPosition;
  Position? _currentPosition;

  bool get isTracking => _isTracking;
  Position? get lastPosition => _lastPosition;
  Position? get currentPosition => _currentPosition;

  Position _getFallbackPosition() {
    return Position(
      latitude: 12.9716,
      longitude: 77.5946,
      timestamp: DateTime.now(),
      accuracy: 1.0,
      altitude: 0.0,
      altitudeAccuracy: 1.0,
      heading: 0.0,
      headingAccuracy: 1.0,
      speed: 0.0,
      speedAccuracy: 1.0,
    );
  }

  // ─── Get Current Location ─────────────────────────────────
  Future<Position?> getCurrentLocation() async {
    try {
      // Step 1: Check if location service is on
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        print('❌ Location service disabled — fallback to Bangalore');
        final pos = _getFallbackPosition();
        _currentPosition = pos;
        _lastPosition = pos;
        return pos;
      }

      // Step 2: Check permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          print('❌ Location permission denied — fallback to Bangalore');
          final pos = _getFallbackPosition();
          _currentPosition = pos;
          _lastPosition = pos;
          return pos;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        print('❌ Location permission permanently denied — fallback to Bangalore');
        final pos = _getFallbackPosition();
        _currentPosition = pos;
        _lastPosition = pos;
        return pos;
      }

      // Step 3: Get position
      print('📍 Getting current location...');
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );

      _currentPosition = position;
      _lastPosition = position;
      print('✅ Location: ${position.latitude}, ${position.longitude}');
      return position;

    } catch (e) {
      print('❌ Location error: $e — fallback to Bangalore');
      final pos = _getFallbackPosition();
      _currentPosition = pos;
      _lastPosition = pos;
      return pos;
    }
  }

  // ─── Save Worker Location to Supabase ─────────────────────
  // Fix C5: Removed dead `worker_profiles` fallback — that table doesn't exist.
  // All location writes go directly to the `workers` table, consistent with the rest of the codebase.
  Future<void> updateWorkerLocation(String workerId) async {
    final position = await getCurrentLocation();
    if (position == null) return;

    try {
      await SupabaseConfig.client.from('workers').update({
        'location': 'POINT(${position.longitude} ${position.latitude})',
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', workerId);
      debugPrint('✅ Worker location updated in Supabase (workers)');
    } catch (e) {
      debugPrint('❌ Failed to update location in workers: $e');
    }
  }

  // ─── Start Tracking ───────────────────────────────────────
  /// Begin streaming worker position updates.
  /// Call when worker sets status to ONLINE.
  Future<void> startTracking() async {
    if (_isTracking) return;

    // Check and request location permissions
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        debugPrint('[LOCATION] Permission denied. Fallback to Bangalore.');
        _isTracking = true;
        _onPositionUpdate(_getFallbackPosition());
        return;
      }
    }
    if (permission == LocationPermission.deniedForever) {
      debugPrint('[LOCATION] Permission permanently denied. Fallback to Bangalore.');
      _isTracking = true;
      _onPositionUpdate(_getFallbackPosition());
      return;
    }

    _isTracking = true;
    debugPrint('[LOCATION] Starting position stream (distanceFilter: 50m)');

    _positionSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 50, // Only fire when moved 50m+
      ),
    ).listen(
      _onPositionUpdate,
      onError: (e) {
        debugPrint('[LOCATION] Position stream error: $e. Fallback to Bangalore.');
        _onPositionUpdate(_getFallbackPosition());
      },
    );

    // Immediately get current position too
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      _onPositionUpdate(pos);
    } catch (e) {
      debugPrint('[LOCATION] Error getting initial position: $e. Fallback to Bangalore.');
      _onPositionUpdate(_getFallbackPosition());
    }
  }

  // ─── Stop Tracking ────────────────────────────────────────
  /// Stop streaming position. Call when worker goes OFFLINE.
  Future<void> stopTracking() async {
    _isTracking = false;
    await _positionSub?.cancel();
    _positionSub = null;
    debugPrint('[LOCATION] Position tracking stopped');
  }

  // ─── Position Update Handler ──────────────────────────────
  void _onPositionUpdate(Position position) async {
    _lastPosition = position;
    _currentPosition = position;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    debugPrint(
      '[LOCATION] Update: ${position.latitude}, ${position.longitude}',
    );

    try {
      // Update Supabase workers table with PostGIS point
      await SupabaseConfig.client.from('workers').update({
        'location': 'POINT(${position.longitude} ${position.latitude})',
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', uid);
    } catch (e) {
      debugPrint('[LOCATION] Error updating Supabase: $e');
    }
  }

  // ─── Dispose ──────────────────────────────────────────────
  Future<void> dispose() async {
    await stopTracking();
  }
}
