import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jugaad_mvp/features/user/widgets/jugaad_stories_tray.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget buildTestableWidget(Widget child) {
    return MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: child,
        ),
      ),
    );
  }

  group('30s Video Diagnosis Redesign Widget Tests', () {
    testWidgets('renders 30s Video Diagnosis hero banner with badges and subtitle', (tester) async {
      await tester.pumpWidget(buildTestableWidget(const JugaadStoriesTray()));
      await tester.pumpAndSettle();

      // Check header title and badges
      expect(find.text('30s Video Diagnosis'), findsOneWidget);
      expect(find.text('GUIDES'), findsOneWidget);
      expect(find.text('30s'), findsOneWidget);
      expect(find.byIcon(Icons.videocam_rounded), findsOneWidget);
      expect(find.byIcon(Icons.menu_book_rounded), findsOneWidget);
      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);

      // Check subtitle description
      expect(
        find.text('Record a short video (30 seconds) and get quick help to identify the issue.'),
        findsOneWidget,
      );
    });

    testWidgets('renders all 5 new issue cards with two-line titles and icons', (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(buildTestableWidget(const JugaadStoriesTray()));
      await tester.pumpAndSettle();

      // Verify all 5 issue cards exist
      expect(find.text('AC'), findsOneWidget);
      expect(find.text('Leaking Issue'), findsOneWidget);
      expect(find.byIcon(Icons.ac_unit_rounded), findsOneWidget);

      expect(find.text('Fan Humming'), findsOneWidget);
      expect(find.text('Noise'), findsOneWidget);
      expect(find.byIcon(Icons.bolt_rounded), findsOneWidget);

      expect(find.text('Low Tap'), findsOneWidget);
      expect(find.text('Water Flow'), findsOneWidget);
      expect(find.byIcon(Icons.water_drop_rounded), findsOneWidget);

      expect(find.text('MCB'), findsOneWidget);
      expect(find.text('Tripping'), findsOneWidget);
      expect(find.byIcon(Icons.power_rounded), findsOneWidget);

      expect(find.text('Geyser'), findsOneWidget);
      expect(find.text('Not Heating'), findsOneWidget);
      expect(find.byIcon(Icons.shower_rounded), findsOneWidget);
    });

    testWidgets('tapping an issue card opens the diagnosis bottom sheet', (tester) async {
      await tester.pumpWidget(buildTestableWidget(const JugaadStoriesTray()));
      await tester.pumpAndSettle();

      // Tap the AC issue card
      await tester.tap(find.text('AC'));
      await tester.pumpAndSettle();

      // Bottom sheet should open with 3-step diagnosis guide
      expect(find.text('30-SECOND QUICK DIAGNOSIS GUIDE'), findsOneWidget);
      expect(find.textContaining('Turn off the AC indoor unit immediately'), findsOneWidget);
      expect(find.textContaining('15-Min Doorstep Guarantee'), findsOneWidget);
      expect(find.textContaining('Book Verified Technician (₹299)'), findsOneWidget);
    });

    testWidgets('tapping camera button opens 30s video recording sheet', (tester) async {
      await tester.pumpWidget(buildTestableWidget(const JugaadStoriesTray()));
      await tester.pumpAndSettle();

      // Tap the video camera badge
      await tester.tap(find.byIcon(Icons.videocam_rounded));
      await tester.pumpAndSettle();

      // Video recording bottom sheet appears
      expect(find.text('AI AUDIO/VIDEO'), findsOneWidget);
      expect(find.text('MAX 30s'), findsOneWidget);
      expect(find.text('Record 30s Video'), findsOneWidget);
      expect(find.text('Upload Video'), findsOneWidget);
    });

    test('each diagnosis story maps accurately to its local 30s MP4 video asset', () {
      final map = {for (final s in JugaadStoriesTray.stories) s.id: s.videoAssetPath};
      expect(map['ac_leak'], 'assets/videos/ac.mp4');
      expect(map['fan_hum'], 'assets/videos/fan.mp4');
      expect(map['tap_low'], 'assets/videos/plumber.mp4');
      expect(map['mcb_trip'], 'assets/videos/mcb.mp4');
      expect(map['geyser_cold'], 'assets/videos/gyser.mp4');
    });
  });
}
