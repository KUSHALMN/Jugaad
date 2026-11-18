import 'package:flutter_test/flutter_test.dart';
import 'package:jugaad_mvp/core/services/supabase_service.dart';
import 'package:jugaad_mvp/core/utils/category_utils.dart';

void main() {
  group('CategoryUtils & Worker Search Categorization Tests', () {
    test('CategoryUtils normalizes bilingual strings accurately', () {
      expect(CategoryUtils.normalize('Plumber / ಪ್ಲಂಬರ್'), 'Plumber');
      expect(CategoryUtils.normalize('Plumber / प्लंबर'), 'Plumber');
      expect(CategoryUtils.normalize('Electrician / ಇಲೆಕ್ಟ್ರಿಷಿಯನ್'), 'Electrician');
      expect(CategoryUtils.normalize('Electrician / इलेक्ट्रीशियन'), 'Electrician');
      expect(CategoryUtils.normalize('Fan Repair / पंखा रिपेयर'), 'Electrician');
      expect(CategoryUtils.normalize('AC Cooling / एसी सर्विस'), 'AC Service');
      expect(CategoryUtils.normalize('Laptop Repair / लैपटॉप'), 'Laptop Repair');
      expect(CategoryUtils.normalize('Home Cleaning / ಮನೆ ಸ್ವಚ್ಛತೆ'), 'Cleaning');
    });

    test('CategoryUtils maps natural language vernacular phrases', () {
      expect(CategoryUtils.normalize('pipe leak aagide'), 'Plumber');
      expect(CategoryUtils.normalize('neeru problem'), 'Plumber');
      expect(CategoryUtils.normalize('light switch repair'), 'Electrician');
      expect(CategoryUtils.normalize('pankha chal nahi raha'), 'Electrician');
      expect(CategoryUtils.normalize('deep cleaning'), 'Cleaning');
      expect(CategoryUtils.normalize('macbook screen'), 'Laptop Repair');
    });

    test('SupabaseService.getMysoreFallbackWorkers returns ONLY matching category', () {
      final plumbers = SupabaseService.getMysoreFallbackWorkers(category: 'Plumber', limit: 10);
      expect(plumbers, isNotEmpty);
      for (final w in plumbers) {
        final cat = (w['category'] ?? w['work_category'] ?? '').toString().toLowerCase();
        final skills = List<String>.from(w['skills'] as List? ?? []).map((s) => s.toLowerCase()).toList();
        final matches = cat.contains('plumb') || skills.any((s) => s.contains('plumb') || s.contains('purifier'));
        expect(matches, isTrue, reason: 'Worker ${w['name']} with category $cat and skills $skills should be a plumber');
      }

      final electricians = SupabaseService.getMysoreFallbackWorkers(category: 'Electrician', limit: 10);
      expect(electricians, isNotEmpty);
      for (final w in electricians) {
        final cat = (w['category'] ?? w['work_category'] ?? '').toString().toLowerCase();
        final skills = List<String>.from(w['skills'] as List? ?? []).map((s) => s.toLowerCase()).toList();
        final matches = cat.contains('electric') || skills.any((s) => s.contains('electric') || s.contains('fan') || s.contains('switch'));
        expect(matches, isTrue, reason: 'Worker ${w['name']} should be an electrician');
      }
    });

    test('Bilingual category input correctly filters only specific workers', () {
      final plumbersFromVernacular = SupabaseService.getMysoreFallbackWorkers(
        category: 'Plumber / ಪ್ಲಂಬರ್',
        limit: 10,
      );
      expect(plumbersFromVernacular, isNotEmpty);
      for (final w in plumbersFromVernacular) {
        final cat = (w['category'] ?? w['work_category'] ?? '').toString().toLowerCase();
        final skills = List<String>.from(w['skills'] as List? ?? []).map((s) => s.toLowerCase()).toList();
        final isPlumber = cat.contains('plumb') || skills.any((s) => s.contains('plumb') || s.contains('purifier'));
        expect(isPlumber, isTrue);
      }
    });
  });
}
