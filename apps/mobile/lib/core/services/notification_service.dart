import 'dart:convert';
import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('[FCM_BG] Background message received: id=${message.messageId}');
  debugPrint('[FCM_BG] Data: ${message.data}');
  debugPrint('[FCM_BG] Notification: title=${message.notification?.title}, body=${message.notification?.body}');
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  StreamSubscription<RemoteMessage>? _foregroundSub;
  StreamSubscription<RemoteMessage>? _openedSub;
  bool _isInitialized = false;
  
  GlobalKey<NavigatorState>? navigatorKey;

  /// Stream controller for dispatch events that screens can listen to.
  /// Used by IncomingRequestScreen to auto-dismiss when JOB_TAKEN arrives.
  final StreamController<Map<String, dynamic>> _dispatchEvents =
      StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get dispatchEvents => _dispatchEvents.stream;

  Future<void> init(GlobalKey<NavigatorState> navKey) async {
    navigatorKey = navKey;
    if (_isInitialized) return;
    _isInitialized = true;
    
    // Request permissions
    NotificationSettings settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    print('[FCM] User granted permission: ${settings.authorizationStatus}');

    // Setup Local Notifications for foreground — NOT supported on web
    if (!kIsWeb) {
      const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
      const darwinInit = DarwinInitializationSettings();
      const initSettings = InitializationSettings(android: androidInit, iOS: darwinInit);
      await _localNotifications.initialize(
        settings: initSettings,
        onDidReceiveNotificationResponse: (details) {
          if (details.payload != null) {
            final data = jsonDecode(details.payload!);
            _handleNavigation(data);
          }
        },
      );
    }

    // Setup Background Handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Terminated state — app was killed and user tapped notification to open
    final initialMessage = await _fcm.getInitialMessage();
    if (initialMessage != null) {
      debugPrint('[FCM] App opened from terminated state via notification');
      debugPrint('[FCM] Terminated data: ${initialMessage.data}');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _handleNavigation(initialMessage.data);
      });
    } else {
      debugPrint('[FCM] No initial message (app opened normally)');
    }

    // Foreground state — app is open and visible
    _foregroundSub = FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('[FCM_FG] ═══════════════════════════════════════');
      debugPrint('[FCM_FG] Foreground message received!');
      debugPrint('[FCM_FG] type=${message.data['type']}');
      debugPrint('[FCM_FG] job_id=${message.data['job_id']}');
      debugPrint('[FCM_FG] All data keys: ${message.data.keys.toList()}');
      debugPrint('[FCM_FG] Notification: ${message.notification?.title}');
      debugPrint('[FCM_FG] ═══════════════════════════════════════');
      
      final type = message.data['type'];
      
      // ─── Dispatch System FCM Handlers ─────────────────
      if (type == 'JOB_OFFER' || type == 'job_offer') {
        // Worker received a job offer → show full notification + navigate
        _showLocalNotification(message);
        _handleNavigation(message.data);
        return;
      }
      if (type == 'job_accepted' || type == 'WORKER_ASSIGNED') {
        _dispatchEvents.add(message.data);
        _showToast("Worker found! On the way.");
        _handleNavigation(message.data);
        return;
      }
      if (type == 'JOB_TAKEN' || type == 'job_offer_withdrawn') {
        // Offer cancelled or taken → dismiss screen
        _dispatchEvents.add(message.data);
        return;
      }
      if (type == 'JOB_TIMEOUT' || type == 'rejected_all') {
        // Dispatch timeout / all rejected → no workers found
        _showToast("No workers available nearby right now.");
        _dispatchEvents.add(message.data);
        return;
      }

      // ─── Existing FCM Handlers (unchanged) ────────────
      if (type == 'worker_arrived') {
        _showToast("Your worker is almost here");
        return;
      }
      if (type == 'payment_received') {
        final amount = message.data['amount'] ?? '0';
        _showToast("₹$amount added to your earnings");
        return;
      }
      if (type == 'scheduled_confirmed') {
        final service = message.data['service'] ?? 'service';
        final time = message.data['time'] ?? '';
        _showToast("Your $service job is confirmed for $time");
        return;
      }

      // Otherwise show local notification
      _showLocalNotification(message);
    });

    // Background state (App in background, user taps notification)
    _openedSub = FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('[FCM_BG_TAP] Notification tapped from background: type=${message.data['type']}');
      debugPrint('[FCM_BG_TAP] Data: ${message.data}');
      _handleNavigation(message.data);
    });
  }

  Future<void> dispose() async {
    await _foregroundSub?.cancel();
    await _openedSub?.cancel();
    // Fix M7: close the broadcast StreamController to avoid memory leak
    if (!_dispatchEvents.isClosed) {
      await _dispatchEvents.close();
    }
    _isInitialized = false;
  }

  void _showLocalNotification(RemoteMessage message) {
    final notification = message.notification;
    if (notification == null) return;

    _localNotifications.show(
      id: notification.hashCode,
      title: notification.title,
      body: notification.body,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'jugaad_high_importance',
          'High Importance Notifications',
          importance: Importance.max,
          priority: Priority.high,
        ),
      ),
      payload: jsonEncode(message.data),
    );
  }

  void _handleNavigation(Map<String, dynamic> data) {
    debugPrint('[FCM_NAV] _handleNavigation called with data: $data');
    if (navigatorKey?.currentContext == null) {
      debugPrint('[FCM_NAV] WARNING: navigatorKey context is null — cannot navigate!');
      return;
    }
    final context = navigatorKey!.currentContext!;
    
    final type = data['type'];
    final reqId = data['job_request_id'] ?? data['job_id'];
    final jobId = reqId;

    debugPrint('[FCM_NAV] Navigating: type=$type, reqId=$reqId');

    switch (type) {
      // ─── Dispatch System Routes ─────────────────────
      case 'job_offer':
      case 'JOB_OFFER':
        if (reqId != null) {
          final skill = data['service_type'] ?? data['skill'] ?? '';
          final budget = data['budget'] ?? '0';
          final distance = data['distance_km'] ?? '';
          final description = data['description'] ?? '';
          final timeout = data['timeout_seconds'] ?? '30';
          context.go(
            '/worker/incoming'
            '?job_id=$reqId'
            '&skill=${Uri.encodeComponent(skill)}'
            '&budget=$budget'
            '&distance=$distance'
            '&description=${Uri.encodeComponent(description)}'
            '&timeout=$timeout',
          );
        }
        break;
      case 'job_accepted':
      case 'WORKER_ASSIGNED':
        if (reqId != null) context.go('/user/matching?job_id=$reqId');
        break;

      // ─── Existing Routes (unchanged) ──────────────
      case 'job_incoming':
      case 'job_manual_assign':
        if (jobId != null) context.go('/worker/incoming?job_id=$jobId');
        break;
      case 'job_assigned':
        if (jobId != null) context.go('/user/matching?job_id=$jobId');
        break;
      case 'worker_arrived':
        _showToast('Your worker is almost here');
        break;
      case 'job_completed':
        if (jobId != null) {
          final amount = data['payment_amount'] ?? data['amount'] ?? 350;
          context.go('/user/payment?job_id=$jobId&amount=$amount');
        }
        break;
      case 'payment_received':
        _showToast("Payment received: ${data['amount'] ?? data['payment_amount'] ?? ''}");
        context.go('/worker/home');
        break;
      case 'scheduled_confirmed':
        _showToast('Scheduled job confirmed');
        break;
    }
  }

  void _showToast(String message) {
    if (navigatorKey?.currentContext == null) return;
    ScaffoldMessenger.of(navigatorKey!.currentContext!).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }
}
