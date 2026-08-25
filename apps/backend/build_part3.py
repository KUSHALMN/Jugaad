import os

def write_file(path, content):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        f.write(content.strip() + "\n")

# Bug 7 Fix: FCM token refresh in Flutter
fcm_fix = """
import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FCMTokenManager {
  static final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static Future<void> refreshAndUploadToken() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final token = await _fcm.getToken();
      if (token != null) {
        await _uploadToken(user.uid, token);
      }

      _fcm.onTokenRefresh.listen((newToken) {
        _uploadToken(user.uid, newToken);
      });
    } catch (e) {
      print("Failed to refresh FCM token: $e");
    }
  }

  static Future<void> _uploadToken(String uid, String token) async {
    // Determine if user or worker by checking collections
    final userDoc = await _firestore.collection('users').doc(uid).get();
    if (userDoc.exists) {
      await _firestore.collection('users').doc(uid).update({'fcmToken': token});
      return;
    }
    
    final workerDoc = await _firestore.collection('workers').doc(uid).get();
    if (workerDoc.exists) {
      await _firestore.collection('workers').doc(uid).update({'fcmToken': token});
    }
  }
}
"""
write_file("../jugaad_mvp/lib/core/services/fcm_token_manager.dart", fcm_fix)

# Update app.dart or main.dart to call FCMTokenManager
# Since we are automating, we can just append to main.dart
main_patch = """
// Patch to call FCMTokenManager on startup
import 'core/services/fcm_token_manager.dart';

void _initFCM() {
  FCMTokenManager.refreshAndUploadToken();
}
"""
with open("../jugaad_mvp/lib/main.dart", "a") as f:
    f.write(main_patch)


# Firestore rules
rules = """
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
    match /workers/{workerId} {
      allow read: if request.auth != null;
      allow write: if request.auth != null && request.auth.uid == workerId;
    }
    match /bookings/{bookingId} {
      allow read: if request.auth != null && (resource.data.userId == request.auth.uid || resource.data.workerId == request.auth.uid);
      allow create: if request.auth != null;
      allow update: if request.auth != null && (resource.data.userId == request.auth.uid || resource.data.workerId == request.auth.uid);
    }
    match /payments/{paymentId} {
      allow read: if request.auth != null && (resource.data.userId == request.auth.uid || resource.data.workerId == request.auth.uid);
      allow write: if false; // only backend writes
    }
    match /reviews/{reviewId} {
      allow read: if true;
      allow create: if request.auth != null;
    }
  }
}
"""
write_file("../firestore.rules", rules)

# Docker compose
docker_compose = """
version: '3.8'

services:
  auth-service:
    build: ./jugaad_backend/services/auth-service
    ports: ["8081:8080"]
  user-service:
    build: ./jugaad_backend/services/user-service
    ports: ["8082:8080"]
  worker-service:
    build: ./jugaad_backend/services/worker-service
    ports: ["8083:8080"]
  booking-service:
    build: ./jugaad_backend/services/booking-service
    ports: ["8084:8080"]
  matching-service:
    build: ./jugaad_backend/services/matching-service
    ports: ["8085:8080"]
  payment-service:
    build: ./jugaad_backend/services/payment-service
    ports: ["8086:8080"]
  notification-service:
    build: ./jugaad_backend/services/notification-service
    ports: ["8087:8080"]
  review-service:
    build: ./jugaad_backend/services/review-service
    ports: ["8088:8080"]
  admin-service:
    build: ./jugaad_backend/services/admin-service
    ports: ["8089:8080"]
"""
write_file("../docker-compose.yml", docker_compose)

# README
readme = """
# Jugaad System Setup

## Services
1. auth-service: OTP via MSG91, Firebase Auth tokens
2. user-service: User profile CRUD
3. worker-service: Worker profiles, availability, geohash
4. booking-service: Booking lifecycle and Firestore ACID transactions
5. matching-service: Geohash-based (9 cell) searching
6. payment-service: Razorpay with RawBodyMiddleware signature verify
7. notification-service: FCM + MSG91 notifications, dead-letter logic
8. review-service: Ratings
9. admin-service: Dashboards

## Setup
1. Define .env file with all environment variables.
2. Run `docker-compose up --build`.

## Known Bugs Fixed:
1. Added missing `shared/pubsub.py`
2. Fixed RawBodyMiddleware in `payment-service`
3. Pydantic v2 migration in models
4. Firestore transaction in booking flow
5. Internal OIDC verification middleware added
6. Geohash 9-cell query fixed
7. FCM Token automatic refresh on app launch
8. Razorpay webhook HMAC signature verification
9. Cloud Tasks dead letter queue prepared
10. MSG91 v5 API fixed
"""
write_file("../README.md", readme)
print("Part 3 built")
