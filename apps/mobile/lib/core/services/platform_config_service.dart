import 'dart:async';
import 'package:flutter/foundation.dart';
import '../config/supabase_config.dart';
import '../network/dio_client.dart';
import '../network/environment_config.dart';

/// Singleton service that holds platform configuration fetched from the backend
/// and synchronized in real-time via Supabase Postgres changes.
/// Extends ChangeNotifier so UI portals can reactively reflect admin adjustments.
class PlatformConfigService extends ChangeNotifier {
  static final PlatformConfigService _instance = PlatformConfigService._internal();
  factory PlatformConfigService() => _instance;
  PlatformConfigService._internal();

  double _surgeFee = 50.0;
  double _surgeMultiplier = 1.0;
  double _dispatchRadiusKm = 5.0;
  double _expandedRadiusKm = 10.0;
  String _smsMode = 'sandbox';
  String _systemLoad = 'optimal';
  bool _maintenanceMode = false;
  bool _isLoaded = false;
  StreamSubscription? _realtimeSubscription;

  double get surgeFee => _surgeFee;
  double get surgeMultiplier => _surgeMultiplier;
  double get dispatchRadiusKm => _dispatchRadiusKm;
  double get expandedRadiusKm => _expandedRadiusKm;
  String get smsMode => _smsMode;
  String get systemLoad => _systemLoad;
  bool get maintenanceMode => _maintenanceMode;
  bool get isLoaded => _isLoaded;
  bool get isSurgeActive => _surgeFee > 50.0 || _surgeMultiplier > 1.0;

  void _applyConfigMap(Map<String, dynamic> data) {
    bool hasChanged = false;

    if (data['surge_fee'] != null) {
      final newSurge = (data['surge_fee'] as num).toDouble();
      if (_surgeFee != newSurge) {
        _surgeFee = newSurge;
        hasChanged = true;
      }
    }
    if (data['surge_multiplier'] != null) {
      final newMult = (data['surge_multiplier'] as num).toDouble();
      if (_surgeMultiplier != newMult) {
        _surgeMultiplier = newMult;
        hasChanged = true;
      }
    }
    if (data['dispatch_radius_km'] != null) {
      final newRad = (data['dispatch_radius_km'] as num).toDouble();
      if (_dispatchRadiusKm != newRad) {
        _dispatchRadiusKm = newRad;
        hasChanged = true;
      }
    }
    if (data['expanded_radius_km'] != null) {
      _expandedRadiusKm = (data['expanded_radius_km'] as num).toDouble();
    }
    if (data['sms_mode'] != null) {
      _smsMode = data['sms_mode'].toString();
    }
    if (data['system_load'] != null) {
      _systemLoad = data['system_load'].toString();
    }
    if (data['maintenance_mode'] != null) {
      final newMaint = data['maintenance_mode'] == true;
      if (_maintenanceMode != newMaint) {
        _maintenanceMode = newMaint;
        hasChanged = true;
      }
    }

    _isLoaded = true;

    if (hasChanged) {
      debugPrint('[PlatformConfig] Live config updated from Admin: surge=₹$_surgeFee, mult=${_surgeMultiplier}x, radius=${_dispatchRadiusKm}km');
      notifyListeners();
    }
  }

  /// Start real-time sync with Supabase platform_config table
  void startRealtimeSync() {
    if (_realtimeSubscription != null) return;
    try {
      _realtimeSubscription = SupabaseConfig.client
          .from('platform_config')
          .stream(primaryKey: ['id'])
          .listen((List<Map<String, dynamic>> rows) {
        if (rows.isNotEmpty) {
          _applyConfigMap(rows.first);
        }
      }, onError: (err) {
        debugPrint('[PlatformConfig] Realtime stream error: $err');
      });
      debugPrint('[PlatformConfig] Subscribed to real-time platform_config changes.');
    } catch (e) {
      debugPrint('[PlatformConfig] Failed to start realtime sync: $e');
    }
  }

  /// Fetch the latest platform config from the backend with Supabase fallback.
  Future<void> fetchConfig() async {
    // Start realtime subscription alongside initial fetch
    startRealtimeSync();

    try {
      final dio = DioClient.instance;
      final response = await dio.get(EnvironmentConfig.platformConfig);

      if (response.statusCode == 200 && response.data != null) {
        final data = Map<String, dynamic>.from(response.data as Map);
        _applyConfigMap(data);
        return;
      }
    } catch (e) {
      debugPrint('[PlatformConfig] HTTP fetch failed, trying direct Supabase fallback: $e');
    }

    // Direct Supabase fallback
    try {
      final row = await SupabaseConfig.client
          .from('platform_config')
          .select()
          .eq('id', 1)
          .maybeSingle();
      if (row != null) {
        _applyConfigMap(Map<String, dynamic>.from(row));
      }
    } catch (dbErr) {
      debugPrint('[PlatformConfig] Supabase direct fallback error: $dbErr');
    }
  }

  /// Helper to calculate the surge component for any fare
  double computeSurgeAddition(double baseFare, {bool isEmergency = false}) {
    if (isEmergency) {
      return _surgeFee;
    }
    if (_surgeMultiplier > 1.0) {
      return baseFare * (_surgeMultiplier - 1.0);
    }
    return 0.0;
  }

  @override
  void dispose() {
    _realtimeSubscription?.cancel();
    super.dispose();
  }
}
