import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/services_list.dart';
import '../services/api_service.dart';

final servicesProvider = FutureProvider<List<ServiceDef>>((ref) async {
  try {
    final response = await ApiService.client.get('/v1/services');
    final list = (response.data['services'] as List)
        .map((json) => ServiceDef.fromJson(json as Map<String, dynamic>))
        .toList();
    return list;
  } catch (e) {
    print('Failed to fetch services from API: $e. Falling back to static catalog.');
    return kAllServices;
  }
});
