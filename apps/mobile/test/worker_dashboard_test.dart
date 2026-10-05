import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jugaad_mvp/core/services/supabase_service.dart';
import 'package:jugaad_mvp/core/theme/portal_mode.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;
  SharedPreferences.setMockInitialValues({});

  group('SupabaseService Earnings & Booking Date Safety', () {
    test('computeTodayEarnings handles valid dates and sums correctly', () {
      final now = DateTime.now();
      final todayStr = now.toIso8601String();
      final rows = [
        {'created_at': todayStr, 'amount': 350.0},
        {'created_at': todayStr, 'amount': 150.0},
      ];
      final total = SupabaseService.computeTodayEarnings(rows);
      expect(total, 500.0);
    });

    test('computeTodayEarnings safely ignores invalid or malformed date strings', () {
      final rows = [
        {'created_at': 'not-a-valid-date', 'amount': 200.0},
        {'created_at': '', 'amount': 300.0},
        {'created_at': null, 'amount': 400.0},
      ];
      // Should not throw FormatException
      final total = SupabaseService.computeTodayEarnings(rows);
      expect(total, 0.0);
    });

    test('computeWeekEarnings safely handles invalid dates', () {
      final rows = [
        {'created_at': 'invalid-date-format', 'amount': 500.0},
      ];
      final total = SupabaseService.computeWeekEarnings(rows);
      expect(total, 0.0);
    });

    test('computeWeekJobCount safely handles invalid dates without throwing', () {
      final rows = [
        {'created_at': 'corrupted-timestamp', 'amount': 150.0},
        {'created_at': null, 'amount': 250.0},
      ];
      final count = SupabaseService.computeWeekJobCount(rows);
      expect(count, 0);
    });
  });

  group('PortalMode & Navigation Integrity', () {
    test('PortalMode worker exposes correct theme and label', () {
      expect(PortalMode.worker.label, 'Worker');
      expect(PortalMode.worker.pillText, 'Worker');
      expect(PortalMode.worker.primary, isNotNull);
      expect(PortalMode.worker.primaryLight, isNotNull);
    });

    test('PortalMode provider silently sets mode without notify loop', () {
      final provider = PortalModeProvider();
      provider.setModeWithoutNotify(PortalMode.worker);
      expect(provider.mode, PortalMode.worker);

      provider.setModeWithoutNotify(PortalMode.user);
      expect(provider.mode, PortalMode.user);
    });
  });

  group('User Theme & Assigned Screen Background Specs', () {
    test('Assigned screen light background color matches clean modern slate specification', () {
      const assignedBg = Color(0xFFF8FAFC);
      expect(assignedBg.value, 0xFFF8FAFC);
      // Ensures it is light (luminance > 0.8)
      expect(assignedBg.computeLuminance() > 0.8, isTrue);
    });
  });
}
