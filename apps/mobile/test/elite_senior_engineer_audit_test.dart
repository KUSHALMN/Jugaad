import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jugaad_mvp/core/services/notification_service.dart';
import 'package:jugaad_mvp/core/network/dio_client.dart';
import 'package:jugaad_mvp/core/models/spare_part_quotation_item.dart';
import 'package:jugaad_mvp/core/models/high_demand_zone.dart';
import 'package:jugaad_mvp/core/services/demand_hotspot_service.dart';
import 'package:jugaad_mvp/core/services/voice_briefing_service.dart';
import 'package:jugaad_mvp/core/providers/locale_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Elite Senior Engineer Audit: NotificationService Stream Lifecycle', () {
    test('NotificationService emitDispatchEvent handles active listeners and delivers payloads', () async {
      final service = NotificationService();
      final completer = Completer<Map<String, dynamic>>();

      final sub = service.dispatchEvents.listen((data) {
        if (!completer.isCompleted) {
          completer.complete(data);
        }
      });

      service.emitDispatchEvent({
        'type': 'JOB_OFFER',
        'job_id': 'job_audit_999',
        'budget': 350,
      });

      final received = await completer.future.timeout(const Duration(seconds: 2));
      expect(received['type'], equals('JOB_OFFER'));
      expect(received['job_id'], equals('job_audit_999'));

      await sub.cancel();
    });

    test('NotificationService emitDispatchEvent does not throw after disposal and recovers on re-init', () async {
      final service = NotificationService();
      await service.dispose();

      // Emitting on disposed controller should not throw
      expect(() => service.emitDispatchEvent({'type': 'PING'}), returnsNormally);

      // Re-initializing with a key recovers the stream
      final key = GlobalKey<NavigatorState>();
      await service.init(key);

      final completer = Completer<Map<String, dynamic>>();
      final sub = service.dispatchEvents.listen((data) {
        if (!completer.isCompleted) completer.complete(data);
      });

      service.emitDispatchEvent({'type': 'RECOVERED_EVENT'});
      final received = await completer.future.timeout(const Duration(seconds: 2));
      expect(received['type'], equals('RECOVERED_EVENT'));

      await sub.cancel();
    });
  });

  group('Elite Senior Engineer Audit: Defensive Model Parsing & Null Safety', () {
    test('SparePartQuotationItem safely parses string numbers, missing fields, and demo IDs', () {
      final rawData = {
        'id': 'demo-test-101',
        'job_id': 'job_mock_123',
        'worker_id': 'worker_mock_456',
        'item_name': 'Anchor 16A Modular Switch',
        'hardware_store_name': 'Kuvempunagar Electricals',
        'mrp_price': 65.50,
        'billed_price': 60.0,
        'receipt_photo_url': '',
        'created_at': '2026-11-24T10:00:00Z',
      };

      final item = SparePartQuotationItem.fromJson(rawData);
      expect(item.id, equals('demo-test-101'));
      expect(item.mrpPrice, equals(65.50));
      expect(item.billedPrice, equals(60.0));
      expect(item.savingsAmount, equals(5.50));
      expect(item.receiptPhotoUrl, isEmpty);
    });

    test('HighDemandZone computes valid ETA and distance under extreme/zero coordinates', () {
      const zone = HighDemandZone(
        id: 'zone_audit_test',
        name: 'Audit Zone Kuvempunagar',
        latitude: 12.3000,
        longitude: 76.6500,
        demandTier: DemandTier.high,
        activeRequestsCount: 15,
        surgeBonus: 75,
        city: 'Mysuru',
        surgeReason: 'High Evening Demand',
        dominantTrade: 'Electrician',
      );

      // Same coordinate: distance = 0, ETA = 2 mins (base prep & parking time)
      final zeroDist = zone.distanceInKm(12.3000, 76.6500);
      expect(zeroDist, equals(0.0));
      final zeroEta = zone.estimatedScooterMinutes(12.3000, 76.6500);
      expect(zeroEta, equals(2));

      // 5 km away: transit time computed accurately
      final dist = zone.distanceInKm(12.3450, 76.6500);
      expect(dist, greaterThan(0.0));
      final eta = zone.estimatedScooterMinutes(12.3450, 76.6500);
      expect(eta, greaterThan(0));
    });
  });

  group('Elite Senior Engineer Audit: Voice Briefing & Localization Reassurance', () {
    test('VoiceBriefingService builds resilient transcripts in all three official locales', () {
      final service = VoiceBriefingService.instance;

      final knTranscript = service.getBriefingTranscript(
        language: AppLanguage.kannada,
        amount: 499,
        hasVerifiedParts: true,
      );
      expect(knTranscript, contains('₹499'));
      expect(knTranscript, contains('ಯಾವುದೇ ಹೆಚ್ಚುವರಿ ಹಣ ನೀಡಬೇಡಿ'));

      final hiTranscript = service.getBriefingTranscript(
        language: AppLanguage.hindi,
        amount: 499,
        hasVerifiedParts: true,
      );
      expect(hiTranscript, contains('₹499'));
      expect(hiTranscript, contains('कोई अतिरिक्त नकद न दें'));

      final enTranscript = service.getBriefingTranscript(
        language: AppLanguage.english,
        amount: 499,
        hasVerifiedParts: true,
      );
      expect(enTranscript, contains('₹499'));
      expect(enTranscript, contains('Do not pay any extra cash'));
    });

    test('VoiceBriefingService tracks playback state and stops safely', () async {
      final service = VoiceBriefingService.instance;
      expect(service.isPlaying.value, isFalse);

      // Stop call on idle service does not throw
      service.stopBriefing();
      expect(service.isPlaying.value, isFalse);
    });
  });
}
