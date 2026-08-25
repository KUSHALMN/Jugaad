import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:jugaad_mvp/core/theme/portal_mode.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  test('portal modes expose labels and themes', () {
    expect(PortalMode.user.label, 'User');
    expect(PortalMode.worker.label, 'Worker');
    expect(PortalMode.user.theme.colorScheme.primary, PortalMode.user.primary);
    expect(PortalMode.worker.theme.colorScheme.primary, PortalMode.worker.primary);
  });
}
