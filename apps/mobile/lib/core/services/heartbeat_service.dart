import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:workmanager/workmanager.dart';
import 'package:jugaad_mvp/firebase_options.dart';
import 'package:flutter/foundation.dart';
import 'api_service.dart';

const String workerHeartbeatTask = 'workerHeartbeat';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    if (task == workerHeartbeatTask) {
      try {
        if (Firebase.apps.isEmpty) {
          await Firebase.initializeApp(
            options: DefaultFirebaseOptions.currentPlatform,
          );
        }

        final workerId = inputData?['worker_id'] as String?;
        if (workerId == null || workerId.isEmpty) {
          print('[HEARTBEAT] Missing worker_id. Skipping heartbeat.');
          return Future.value(false);
        }

        double lat = 12.9716;
        double lng = 77.5946;

        try {
          final serviceEnabled = await Geolocator.isLocationServiceEnabled();
          final permission = await Geolocator.checkPermission();
          
          if (serviceEnabled &&
              permission != LocationPermission.denied &&
              permission != LocationPermission.deniedForever) {
            final position = await Geolocator.getCurrentPosition(
              locationSettings: const LocationSettings(
                accuracy: LocationAccuracy.high,
                timeLimit: Duration(seconds: 10),
              ),
            );
            lat = position.latitude;
            lng = position.longitude;
          } else {
            print('[HEARTBEAT] Location unavailable. Using Bangalore Center fallback.');
          }
        } catch (e) {
          print('[HEARTBEAT] Error fetching GPS position: $e. Using Bangalore Center fallback.');
        }
        final token = await FirebaseAuth.instance.currentUser?.getIdToken();
        if (token == null) {
          print('[HEARTBEAT] No Firebase token available. Skipping heartbeat.');
          return Future.value(false);
        }
        
        print('[HEARTBEAT] Sending heartbeat: lat=$lat, lng=$lng for worker: $workerId');
        
        final response = await http.post(
          Uri.parse('${ApiService.baseUrl}/v1/workers/$workerId/heartbeat'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'lat': lat,
            'lng': lng,
            'timestamp': DateTime.now().toUtc().toIso8601String(),
          }),
        ).timeout(const Duration(seconds: 15));
        final statusCode = response.statusCode;
        
        print('[HEARTBEAT] Heartbeat sent. Response: $statusCode');
        
        return Future.value(statusCode >= 200 && statusCode < 300);
      } catch (e) {
        print('[HEARTBEAT] Error sending heartbeat: $e');
        return Future.value(false);
      }
    }
    return Future.value(true);
  });
}

class HeartbeatService {
  static final HeartbeatService _instance = HeartbeatService._internal();
  factory HeartbeatService() => _instance;
  HeartbeatService._internal();

  bool _isInitialized = false;

  Future<void> init() async {
    if (kIsWeb) return;
    if (_isInitialized) return;
    await Workmanager().initialize(
      callbackDispatcher,
    );
    _isInitialized = true;
  }

  void startHeartbeat(String workerId) {
    if (kIsWeb) return;
    print('[HEARTBEAT] Registering periodic heartbeat task for worker: $workerId');
    Workmanager().registerPeriodicTask(
      "worker_heartbeat_task_id",
      workerHeartbeatTask,
      frequency: const Duration(minutes: 15),
      inputData: {'worker_id': workerId},
      constraints: Constraints(networkType: NetworkType.connected),
    );
  }

  void stopHeartbeat() {
    if (kIsWeb) return;
    print('[HEARTBEAT] Cancelling heartbeat task');
    Workmanager().cancelByUniqueName("worker_heartbeat_task_id");
  }
}
