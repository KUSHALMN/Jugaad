import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'api_service.dart';

/// Manages FCM token lifecycle — uploads via backend API to bypass RLS.
///
/// Key fixes over previous version:
/// 1. Routes token upload through backend API (not direct Supabase write)
///    because the Flutter client uses the anon key and auth.uid() is null
///    (Firebase Auth ≠ Supabase Auth), so RLS blocks direct writes.
/// 2. Cancels previous onTokenRefresh listener to prevent leak.
/// 3. Removed broken workers table write (no fcm_token column in schema).
class FCMTokenManager {
  static final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Prevent listener leak — cancel previous before adding new one.
  static StreamSubscription<String>? _tokenRefreshSub;

  /// Refresh and upload the FCM token for the current user.
  /// Safe to call multiple times (idempotent).
  static Future<void> refreshAndUploadToken() async {
    final user = _auth.currentUser;
    if (user == null) {
      debugPrint('[FCM_TOKEN] No user logged in, skipping token upload');
      return;
    }

    try {
      final token = await _fcm.getToken();
      debugPrint('[FCM_TOKEN] Got token: ${token != null ? "${token.substring(0, 20)}..." : "null"}');

      if (token != null) {
        await _uploadToken(token);
      }

      // Cancel previous listener to prevent stacking duplicates
      await _tokenRefreshSub?.cancel();
      _tokenRefreshSub = _fcm.onTokenRefresh.listen((newToken) {
        debugPrint('[FCM_TOKEN] Token refreshed, uploading new token...');
        _uploadToken(newToken);
      });

      debugPrint('[FCM_TOKEN] Token refresh listener registered');
    } catch (e) {
      debugPrint('[FCM_TOKEN] Failed to refresh FCM token: $e');
    }
  }

  /// Upload token via the backend API endpoint (POST /v1/users/me/fcm-token).
  /// The backend uses the service role key, which bypasses RLS.
  static Future<void> _uploadToken(String token) async {
    try {
      await ApiService().updateFcmToken(token);
      debugPrint('[FCM_TOKEN] Token uploaded successfully via API');
    } catch (e) {
      debugPrint('[FCM_TOKEN] API upload failed: $e');
      // Don't rethrow — token upload failure shouldn't crash the app
    }
  }
}
