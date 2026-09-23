import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_locale.dart';
import 'app_translations.dart';

const String _kLanguagePrefKey = 'jugaad_selected_language_code';

/// Riverpod StateNotifier to manage and persist user language across app restarts.
class LocaleNotifier extends StateNotifier<AppLanguage> {
  LocaleNotifier() : super(AppLanguage.english) {
    _loadFromStorage();
  }

  Future<void> _loadFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final code = prefs.getString(_kLanguagePrefKey);
      if (code != null) {
        state = AppLanguage.fromCode(code);
      }
    } catch (_) {}
  }

  Future<void> setLanguage(AppLanguage language) async {
    state = language;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kLanguagePrefKey, language.code);
    } catch (_) {}
  }
}

/// Global provider for application language state.
final localeProvider = StateNotifierProvider<LocaleNotifier, AppLanguage>((ref) {
  return LocaleNotifier();
});

/// Reactive translation lookup provider.
final translationProvider = Provider.family<String, String>((ref, key) {
  final lang = ref.watch(localeProvider);
  return AppTranslations.get(key, language: lang);
});
