import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/services_list.dart';
import '../services/api_service.dart';

final servicesProvider = FutureProvider<List<ServiceDef>>((ref) async {
  const allowed = {
    'electrician',
    'plumber',
    'phone_repair',
    'laptop_repair',
    'ac_service',
    'carpenter',
    'stove_repair',
  };

  try {
    final response = await ApiService.client.get('/v1/services');
    final list = (response.data['services'] as List)
        .map((json) => ServiceDef.fromJson(json as Map<String, dynamic>))
        .where((s) => allowed.contains(s.id.toLowerCase()))
        .toList();
    return list.isNotEmpty ? list : kAllServices;
  } catch (e) {
    print('Failed to fetch services from API: $e. Falling back to static catalog.');
    return kAllServices;
  }
});

