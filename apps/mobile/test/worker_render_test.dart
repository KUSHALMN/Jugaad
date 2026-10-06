import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:jugaad_mvp/features/worker/worker_shell.dart';
import 'package:jugaad_mvp/features/worker/screens/worker_home_screen.dart';
import 'package:jugaad_mvp/features/worker/screens/worker_portal_screen.dart';
import 'package:jugaad_mvp/core/theme/worker_app_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;
  SharedPreferences.setMockInitialValues({});

  testWidgets('WorkerHomeScreen and WorkerShell render without throwing', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final router = GoRouter(
      initialLocation: '/worker/home',
      routes: [
        ShellRoute(
          builder: (context, state, child) => WorkerShell(child: child),
          routes: [
            GoRoute(
              path: '/worker/home',
              builder: (context, state) => const WorkerHomeScreen(),
            ),
            GoRoute(
              path: '/worker/dashboard',
              builder: (context, state) => const WorkerHomeScreen(),
            ),
            GoRoute(
              path: '/worker/active',
              builder: (context, state) => const Scaffold(body: Text('Active Jobs')),
            ),
            GoRoute(
              path: '/worker/earnings',
              builder: (context, state) => const Scaffold(body: Text('Earnings Screen')),
            ),
            GoRoute(
              path: '/worker/profile',
              builder: (context, state) => const Scaffold(body: Text('Profile Screen')),
            ),
          ],
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp.router(
          routerConfig: router,
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(WorkerHomeScreen), findsOneWidget);
    expect(find.text('PRO VERIFIED'), findsOneWidget);
    expect(find.text('Today\'s Earnings'), findsOneWidget);

    // Test clicking sidebar My Services
    final myServices = find.text('My Services');
    expect(myServices, findsOneWidget);
    await tester.tap(myServices);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('My Services & Rate Cards'), findsOneWidget);

    // Close the sheet by popping root navigator
    Navigator.of(tester.element(find.text('My Services & Rate Cards')), rootNavigator: true).pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    // Test clicking top nav bar Jobs tab
    final jobsTab = find.widgetWithText(InkWell, 'Jobs').first;
    await tester.tap(jobsTab);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('Active Jobs'), findsOneWidget);

    // Return to dashboard
    final dashTab = find.widgetWithText(InkWell, 'Dashboard').first;
    await tester.tap(dashTab);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byType(WorkerHomeScreen), findsOneWidget);
  });

  testWidgets('ElevatedButton renders safely within unconstrained Row under WorkerAppTheme', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: WorkerAppTheme.themeData,
        home: Scaffold(
          body: Row(
            children: [
              const Text('Label'),
              ElevatedButton(
                onPressed: () {},
                child: const Text('Action'),
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('Action'), findsOneWidget);
  });

  testWidgets('WorkerPortalScreen renders without throwing when measured with zero or narrow constraints', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: WorkerAppTheme.themeData,
        home: Scaffold(
          body: SizedBox(
            width: 0,
            child: WorkerPortalScreen(onSwitchMode: () {}),
          ),
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(WorkerPortalScreen), findsOneWidget);

    // Dispose widget so repeating animation controller is stopped
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 100));
  });
}


