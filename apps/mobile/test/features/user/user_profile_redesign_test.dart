import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jugaad_mvp/features/user/screens/user_portal_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget buildTestableProfile({VoidCallback? onSwitchMode}) {
    return MaterialApp(
      home: UserPortalScreen(
        onSwitchMode: onSwitchMode ?? () {},
      ),
    );
  }

  group('User Profile Redesign Widget Tests', () {
    testWidgets('renders User Account header, Edit Profile pill, and hero KPI cards', (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(buildTestableProfile());
      await tester.pumpAndSettle();

      // Header & Edit Profile pill
      expect(find.text('User Account'), findsOneWidget);
      expect(find.text('Edit Profile'), findsOneWidget);
      expect(find.byIcon(Icons.edit_rounded), findsOneWidget);
      expect(find.byIcon(Icons.camera_alt_rounded), findsOneWidget);

      // Hero Profile stats
      expect(find.text('Total Bookings'), findsOneWidget);
      expect(find.text('Your Rating'), findsOneWidget);
      expect(find.text('—'), findsOneWidget);
      expect(find.textContaining('Member since'), findsOneWidget);
    });

    testWidgets('renders rich Portal Selector dual cards and triggers switch callback', (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      var switched = false;
      await tester.pumpWidget(buildTestableProfile(onSwitchMode: () => switched = true));
      await tester.pumpAndSettle();

      expect(find.text('Portal Selector'), findsOneWidget);
      expect(find.text('Choose how you want to use Jugaad'), findsOneWidget);
      expect(find.text('User Portal'), findsOneWidget);
      expect(find.text('Book services, track jobs and more'), findsOneWidget);
      expect(find.text('Worker Portal'), findsOneWidget);
      expect(find.text('Offer your services and get jobs'), findsOneWidget);

      await tester.tap(find.text('Worker Portal'));
      await tester.pump();
      expect(switched, isTrue);
    });

    testWidgets('renders My Bookings empty state with Find & Book a Service CTA', (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(buildTestableProfile());
      await tester.pumpAndSettle();

      expect(find.text('My Bookings'), findsOneWidget);
      expect(find.text('View all'), findsOneWidget);
      expect(find.text('No bookings yet'), findsOneWidget);
      expect(find.text('Your booked services will appear here.'), findsOneWidget);
      expect(find.text('Find & Book a Service'), findsOneWidget);
    });
  });
}
