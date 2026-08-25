import 'package:flutter/foundation.dart';
import '../network/dio_client.dart';
import '../network/environment_config.dart';

/// Singleton service that holds platform configuration fetched from the backend.
class PlatformConfigService {
  static final PlatformConfigService _instance = PlatformConfigService._internal();
  factory PlatformConfigService() => _instance;
  PlatformConfigService._internal();

  double _surgeFee = 50.0;
  double _dispatchRadiusKm = 5.0;
  String _smsMode = 'sandbox';

  double get surgeFee => _surgeFee;
  double get dispatchRadiusKm => _dispatchRadiusKm;
  String get smsMode => _smsMode;

  bool _isLoaded = false;
  bool get isLoaded => _isLoaded;

  /// Fetch the latest platform config from the backend.
  Future<void> fetchConfig() async {
    try {
      final dio = DioClient.instance;
      final response = await dio.get(EnvironmentConfig.platformConfig);
      
      if (response.statusCode == 200 && response.data != null) {
        final data = response.data;
        
        if (data['surge_fee'] != null) {
          _surgeFee = (data['surge_fee'] as num).toDouble();
        }
        if (data['dispatch_radius_km'] != null) {
          _dispatchRadiusKm = (data['dispatch_radius_km'] as num).toDouble();
        }
        if (data['sms_mode'] != null) {
          _smsMode = data['sms_mode'].toString();
        }
        
        _isLoaded = true;
        debugPrint('[PlatformConfig] Loaded: surge=₹$_surgeFee, radius=${_dispatchRadiusKm}km, sms=$_smsMode');
      }
    } catch (e) {
      debugPrint('[PlatformConfig] Error fetching config: $e');
      // Keep defaults
    }
  }
}
