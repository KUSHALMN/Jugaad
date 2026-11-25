import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jugaad_mvp/features/user/screens/worker_list_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget buildTestableScreen() {
    return const MaterialApp(
      home: WorkerListScreen(),
    );
  }

  group('Jugaad Experts Redesign Widget Tests', () {
    testWidgets('renders dual-tone title, KPI trust pills, and city dropdown', (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(buildTestableScreen());
      await tester.pump(const Duration(milliseconds: 200));

      // Header KPI trust pills
      expect(find.text('120+'), findsOneWidget);
      expect(find.text('Verified Workers'), findsOneWidget);
      expect(find.text('4.8 ★'), findsOneWidget);
      expect(find.text('Avg. Rating'), findsOneWidget);
      expect(find.text('24/7'), findsOneWidget);
      expect(find.text('Service Available'), findsOneWidget);

      // Search bar and integrated city selector
      expect(find.text('Search by name, skill, area, or email...'), findsOneWidget);
      expect(find.text('Mysuru'), findsOneWidget);
      expect(find.byIcon(Icons.build_rounded), findsOneWidget);
    });

    testWidgets('renders category filter chips with dedicated icons', (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(buildTestableScreen());
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('All'), findsOneWidget);
      expect(find.byIcon(Icons.grid_view_rounded), findsOneWidget);

      expect(find.text('Electrician'), findsWidgets);
      expect(find.byIcon(Icons.bolt_rounded), findsWidgets);

      expect(find.text('Plumber'), findsWidgets);
      expect(find.byIcon(Icons.plumbing_rounded), findsWidgets);

      expect(find.text('Laptop repair'), findsWidgets);
      expect(find.byIcon(Icons.laptop_mac_rounded), findsWidgets);

      expect(find.text('AC service'), findsWidgets);
      expect(find.byIcon(Icons.ac_unit_rounded), findsWidgets);

      // Verify Book Now CTA and direct call buttons on rich expert cards
      expect(find.text('Book Now'), findsWidgets);
      expect(find.byIcon(Icons.call_rounded), findsWidgets);
    });
  });
}
