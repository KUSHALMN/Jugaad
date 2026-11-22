import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Ultra-low latency, in-memory synchronous L1 storage cache for Jugaad.
///
/// Eliminates asynchronous MethodChannel disk I/O bottlenecks during widget builds.
/// Reads execute in O(1) synchronous time directly from memory. Writes update
/// memory instantly and flush to persistent storage asynchronously in the background.
class FastStorageService {
  FastStorageService._();
  static final FastStorageService instance = FastStorageService._();

  final Map<String, dynamic> _memoryCache = {};
  SharedPreferences? _prefs;
  bool _isInitialized = false;

  bool get isInitialized => _isInitialized;

  /// Warm the in-memory cache at app startup
  Future<void> initialize() async {
    if (_isInitialized) return;
    try {
      _prefs = await SharedPreferences.getInstance();
      final keys = _prefs!.getKeys();
      for (final key in keys) {
        _memoryCache[key] = _prefs!.get(key);
      }
      _isInitialized = true;
      debugPrint('[FAST-STORAGE] Initialized with ${_memoryCache.length} cached keys in RAM');
    } catch (e) {
      debugPrint('[FAST-STORAGE] Initialization error: $e');
      _isInitialized = true; // Fallback to memory-only
    }
  }

  // ─── Synchronous O(1) Memory Reads ────────────────────────

  String? getString(String key, {String? defaultValue}) {
    final val = _memoryCache[key];
    if (val is String) return val;
    return defaultValue;
  }

  bool getBool(String key, {bool defaultValue = false}) {
    final val = _memoryCache[key];
    if (val is bool) return val;
    return defaultValue;
  }

  int getInt(String key, {int defaultValue = 0}) {
    final val = _memoryCache[key];
    if (val is int) return val;
    return defaultValue;
  }

  double getDouble(String key, {double defaultValue = 0.0}) {
    final val = _memoryCache[key];
    if (val is double) return val;
    if (val is int) return val.toDouble();
    return defaultValue;
  }

  List<String> getStringList(String key, {List<String> defaultValue = const []}) {
    final val = _memoryCache[key];
    if (val is List<String>) return val;
    if (val is List) return val.map((e) => e.toString()).toList();
    return defaultValue;
  }

  bool containsKey(String key) => _memoryCache.containsKey(key);

  Set<String> getKeys() => Set.unmodifiable(_memoryCache.keys);

  // ─── Immediate Write-Through Operations ───────────────────

  Future<bool> setString(String key, String value) async {
    _memoryCache[key] = value;
    if (_prefs != null) {
      unawaited(_prefs!.setString(key, value));
    }
    return true;
  }

  Future<bool> setBool(String key, bool value) async {
    _memoryCache[key] = value;
    if (_prefs != null) {
      unawaited(_prefs!.setBool(key, value));
    }
    return true;
  }

  Future<bool> setInt(String key, int value) async {
    _memoryCache[key] = value;
    if (_prefs != null) {
      unawaited(_prefs!.setInt(key, value));
    }
    return true;
  }

  Future<bool> setDouble(String key, double value) async {
    _memoryCache[key] = value;
    if (_prefs != null) {
      unawaited(_prefs!.setDouble(key, value));
    }
    return true;
  }

  Future<bool> setStringList(String key, List<String> value) async {
    _memoryCache[key] = List<String>.from(value);
    if (_prefs != null) {
      unawaited(_prefs!.setStringList(key, value));
    }
    return true;
  }

  Future<bool> remove(String key) async {
    _memoryCache.remove(key);
    if (_prefs != null) {
      unawaited(_prefs!.remove(key));
    }
    return true;
  }

  Future<bool> clear() async {
    _memoryCache.clear();
    if (_prefs != null) {
      unawaited(_prefs!.clear());
    }
    return true;
  }
}
