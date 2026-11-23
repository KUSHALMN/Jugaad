import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jugaad_mvp/core/models/high_demand_zone.dart';
import 'package:jugaad_mvp/core/providers/locale_provider.dart';
import 'package:jugaad_mvp/core/services/demand_hotspot_service.dart';
import 'package:jugaad_mvp/core/services/voice_briefing_service.dart';
import 'package:jugaad_mvp/features/shared/widgets/voice_briefing_pill.dart';
import 'package:jugaad_mvp/features/worker/widgets/demand_hotspot_radar_card.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('VoiceBriefingService Vernacular Synthesis Tests', () {
    final service = VoiceBriefingService.instance;

    tearDown(() {
      service.stopBriefing();
    });

    test('Generates verified bill transcript in Kannada ("Keli Thiliri")', () {
      final text = service.getBriefingTranscript(
        amount: 237,
        language: AppLanguage.kannada,
        hasVerifiedParts: true,
      );
      expect(text, contains('ನಿಮ್ಮ ಒಟ್ಟು ಬಿಲ್ ₹237'));
      expect(text, contains('ಬಿಡಿಭಾಗಗಳ ಎಂಆರ್‌ಪಿ ರಶೀದಿ ಪರಿಶೀಲಿಸಲಾಗಿದೆ'));
      expect(text, contains('ಯಾವುದೇ ಹೆಚ್ಚುವರಿ ಹಣ ನೀಡಬೇಡಿ'));
    });

    test('Generates verified bill transcript in Hindi ("Sunke Samjho")', () {
      final text = service.getBriefingTranscript(
        amount: 350,
        language: AppLanguage.hindi,
        hasVerifiedParts: true,
      );
      expect(text, contains('आपका कुल बिल ₹350 है'));
      expect(text, contains('स्पेयर पार्ट्स की एमआरपी रसीद सत्यापित है'));
      expect(text, contains('कोई अतिरिक्त नकद न दें'));
    });

    test('Generates verified bill transcript in English', () {
      final text = service.getBriefingTranscript(
        amount: 199,
        language: AppLanguage.english,
        hasVerifiedParts: true,
      );
      expect(text, contains('Your total bill is ₹199'));
      expect(text, contains('Spare parts MRP receipt is verified'));
      expect(text, contains('Do not pay any extra cash'));
    });

    test('Tracks playback state and closed captions reactively', () async {
      await service.playBriefing(
        amount: 237,
        language: AppLanguage.kannada,
        duration: const Duration(milliseconds: 150),
      );

      expect(service.isPlaying.value, isTrue);
      expect(service.activeCaption.value, contains('ನಿಮ್ಮ ಒಟ್ಟು ಬಿಲ್ ₹237'));

      // Wait for playback cycle to complete
      await Future.delayed(const Duration(milliseconds: 200));

      expect(service.isPlaying.value, isFalse);
      expect(service.activeCaption.value, isEmpty);
    });
  });

  group('HighDemandZone Domain Model & Surge Tests', () {
    const zone = HighDemandZone(
      id: 'test_gokulam',
      name: 'Gokulam Center',
      city: 'Mysuru',
      latitude: 12.3308,
      longitude: 76.6267,
      activeRequestsCount: 6,
      demandTier: DemandTier.high,
      surgeBonus: 50,
      surgeReason: 'Weekend Rain Bonus',
      dominantTrade: 'Plumbing & RO Purifier',
    );

    test('Computes distance and estimated scooter transit time accurately', () {
      // Coordinate approximately 2.5 km away in Mysore
      const workerLat = 12.3051;
      const workerLng = 76.6551;

      final km = zone.distanceInKm(workerLat, workerLng);
      expect(km, greaterThan(1.0));
      expect(km, lessThan(8.0));

      final distString = zone.formattedDistance(workerLat, workerLng);
      expect(distString, contains('km away'));

      final minutes = zone.estimatedScooterMinutes(workerLat, workerLng);
      expect(minutes, greaterThanOrEqualTo(3));
    });

    test('Generates expressive summary tagline with surge bonus details', () {
      expect(zone.summaryTagline, equals('6 requests in last 15 mins • +₹50 Weekend Rain Bonus'));
    });

    test('Serializes to and from JSON correctly', () {
      final json = zone.toJson();
      final revived = HighDemandZone.fromJson(json);

      expect(revived.id, equals('test_gokulam'));
      expect(revived.name, equals('Gokulam Center'));
      expect(revived.surgeBonus, equals(50));
      expect(revived.demandTier, equals(DemandTier.high));
    });
  });

  group('DemandHotspotService Directory & Dispatch Tests', () {
    final service = DemandHotspotService.instance;

    test('Retrieves curated Mysuru hotspots with Vijayanagar & Kuvempunagar', () {
      final mysoreHotspots = service.getHotspots(city: 'Mysuru');
      expect(mysoreHotspots, isNotEmpty);
      expect(mysoreHotspots.any((z) => z.name.contains('Vijayanagar')), isTrue);
      expect(mysoreHotspots.any((z) => z.name.contains('Gokulam')), isTrue);
    });

    test('Retrieves curated Bengaluru hotspots with Koramangala & Indiranagar', () {
      final blrHotspots = service.getHotspots(city: 'Bengaluru');
      expect(blrHotspots, isNotEmpty);
      expect(blrHotspots.any((z) => z.name.contains('Koramangala')), isTrue);
    });

    test('Identifies nearest hotspot from worker coordinates', () {
      final nearest = service.getNearestHotspot(12.3374, 76.6111, city: 'Mysuru');
      expect(nearest, isNotNull);
      expect(nearest!.name, contains('Vijayanagar'));
    });
  });

  group('VoiceBriefingPill & DemandHotspotRadarCard UI Widget Tests', () {
    testWidgets('VoiceBriefingPill renders localized audio button and handles tap', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: VoiceBriefingPill(
                totalAmount: 237,
                hasVerifiedParts: true,
                isAnimated: false,
              ),
            ),
          ),
        ),
      );

      // Verify pill button renders
      expect(find.byType(VoiceBriefingPill), findsOneWidget);
      expect(find.text('Listen to Bill'), findsOneWidget);

      // Tap speaker pill to trigger playback
      await tester.tap(find.byType(GestureDetector).first);
      await tester.pump();

      expect(VoiceBriefingService.instance.isPlaying.value, isTrue);

      // Stop briefing
      VoiceBriefingService.instance.stopBriefing();
      await tester.pump();
      expect(VoiceBriefingService.instance.isPlaying.value, isFalse);
    });

    testWidgets('DemandHotspotRadarCard renders live beacon and zone chips', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: DemandHotspotRadarCard(
                currentLat: 12.3051,
                currentLng: 76.6551,
                city: 'Mysuru',
                isAnimated: false,
              ),
            ),
          ),
        ),
      );

      expect(find.byType(DemandHotspotRadarCard), findsOneWidget);
      expect(find.text('Live Demand Radar'), findsOneWidget);
      expect(find.text('Surge Active'), findsOneWidget);
      expect(find.textContaining('Vijayanagar'), findsWidgets);
    });
  });
}
