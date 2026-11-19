import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppLanguage {
  kannada('kn', 'ಕನ್ನಡ', 'kn_IN'),
  english('en', 'ENG', 'en_IN'),
  hindi('hi', 'हिंदी', 'hi_IN');

  final String code;
  final String label;
  final String localeStr;
  const AppLanguage(this.code, this.label, this.localeStr);
}

class LocaleNotifier extends Notifier<AppLanguage> {
  static const String _prefKey = 'jugaad_app_language_code';

  @override
  AppLanguage build() {
    _loadLanguage();
    return AppLanguage.english;
  }

  Future<void> _loadLanguage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final code = prefs.getString(_prefKey);
      if (code != null) {
        state = AppLanguage.values.firstWhere(
          (l) => l.code == code,
          orElse: () => AppLanguage.english,
        );
      }
    } catch (_) {}
  }

  Future<void> setLanguage(AppLanguage language) async {
    state = language;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKey, language.code);
    } catch (_) {}
  }

  Future<void> cycleLanguage() async {
    final nextIndex = (state.index + 1) % AppLanguage.values.length;
    await setLanguage(AppLanguage.values[nextIndex]);
  }
}

final localeProvider = NotifierProvider<LocaleNotifier, AppLanguage>(
  LocaleNotifier.new,
);
