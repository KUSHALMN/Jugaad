import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:jugaad_mvp/core/utils/haptic_feedback_utils.dart';
import 'package:jugaad_mvp/core/services/sound_service.dart';
import 'package:jugaad_mvp/core/providers/locale_provider.dart';
import 'package:jugaad_mvp/core/theme/worker_app_theme.dart';
import 'package:jugaad_mvp/features/shared/widgets/shimmer_skeletons.dart';
import 'package:jugaad_mvp/features/user/widgets/landmark_route_tracker.dart';
import 'package:jugaad_mvp/features/user/widgets/trusted_technicians_tray.dart';
import 'package:jugaad_mvp/features/shared/widgets/spare_parts_quotation_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Micro-Haptics & Sound System Tests', () {
    test('AppHaptics methods execute cleanly', () async {
      await AppHaptics.lightTick();
      await AppHaptics.mediumSnap();
      await AppHaptics.heavySuccess();
      await AppHaptics.selectionChange();
      await AppHaptics.sliderNotch();
      await AppHaptics.errorBuzz();
    });

    test('SoundService triggers security chirp and milestone cues safely', () async {
      final service = SoundService();
      await service.initialize();
      expect(service.isSoundEnabled, isTrue);
      await service.playSecurityChirp();
      await service.playMilestoneUnlocked();
    });
  });

  group('LocaleNotifier Bilingual State Tests', () {
    test('Cycles correctly between English, Kannada, and Hindi', () async {
      final container = ProviderContainer();
      expect(container.read(localeProvider), AppLanguage.english);

      await container.read(localeProvider.notifier).cycleLanguage();
      expect(container.read(localeProvider), AppLanguage.hindi);

      await container.read(localeProvider.notifier).cycleLanguage();
      expect(container.read(localeProvider), AppLanguage.kannada);

      await container.read(localeProvider.notifier).cycleLanguage();
      expect(container.read(localeProvider), AppLanguage.english);
    });
  });

  group('Worker Theme Sunlight High-Contrast Tests', () {
    test('Sunlight high contrast palette is defined for outdoor readability', () {
      expect(WorkerAppTheme.sunlightBackground, const Color(0xFF000000));
      expect(WorkerAppTheme.sunlightTextPrimary, const Color(0xFFFFFFFF));
      expect(WorkerAppTheme.sunlightAmber, const Color(0xFFF59E0B));
      expect(WorkerAppTheme.sunlightEmerald, const Color(0xFF10B981));
    });
  });

  group('UI Components & Skeleton Render Tests', () {
    testWidgets('ShimmerSkeletons render without throwing', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: [
                  ShimmerSkeletons.workerCard(),
                  ShimmerSkeletons.rateCardItem(),
                  ShimmerSkeletons.storyBubble(),
                ],
              ),
            ),
          ),
        ),
      );
      expect(find.byType(SingleChildScrollView), findsOneWidget);
    });

    testWidgets('LandmarkRouteTracker renders milestones & vehicle info', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: LandmarkRouteTracker(
                workerName: 'Ramesh K.',
                vehicleInfo: '🛵 Hero Splendor (KA-09-EA-4821)',
                currentStep: 1,
                landmarkText: 'Near Saraswathipuram Fire Station',
              ),
            ),
          ),
        ),
      );
      expect(find.text('Doorstep Live Radar'), findsOneWidget);
      expect(find.text('Near Saraswathipuram Fire Station'), findsAtLeastNWidgets(1));
      expect(find.text('🛵 Hero Splendor (KA-09-EA-4821)'), findsOneWidget);
    });

    testWidgets('TrustedTechniciansTray renders without throwing', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: TrustedTechniciansTray(),
              ),
            ),
          ),
        ),
      );
      expect(find.text('Mane Technician / ನನ್ನ ಟೆಕ್ನಿಷಿಯನ್'), findsOneWidget);
    });

    testWidgets('SparePartsQuotationSheet renders digital quotation breakdown', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SparePartsQuotationSheet(
              jobId: 'job_test_123',
              isWorker: false,
            ),
          ),
        ),
      );
      expect(find.text('Spare Parts & Material Quotation'), findsOneWidget);
      expect(find.text('Havells 2.5µF Motor Capacitor'), findsOneWidget);
      expect(find.text('₹80'), findsOneWidget);
    });
  });
}
