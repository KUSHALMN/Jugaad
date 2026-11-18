import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart' as pkg_provider;
import 'package:jugaad_mvp/core/theme/portal_mode.dart';
import 'package:jugaad_mvp/features/auth/screens/login_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  testWidgets('LoginScreen renders without throwing on wide desktop', (tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final portalProvider = PortalModeProvider();

    await tester.pumpWidget(
      pkg_provider.ChangeNotifierProvider<PortalModeProvider>.value(
        value: portalProvider,
        child: const ProviderScope(
          child: MaterialApp(
            home: LoginScreen(selectedRole: PortalMode.user),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);
  });
}
