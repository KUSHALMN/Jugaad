import 'package:shared_preferences/shared_preferences.dart';

class SearchHistoryService {
  static const String _keyHistory = 'search_history_items';
  static const int _maxHistoryCount = 8;

  // Private constructor
  SearchHistoryService._privateConstructor();

  static final SearchHistoryService instance = SearchHistoryService._privateConstructor();

  /// Retrieves the stored search history items.
  Future<List<String>> getHistory() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_keyHistory) ?? [];
  }

  /// Adds a new search term to history, moving it to the top.
  Future<void> addTerm(String term) async {
    final cleanTerm = term.trim();
    if (cleanTerm.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final List<String> current = prefs.getStringList(_keyHistory) ?? [];

    // Remove duplicates
    current.removeWhere((item) => item.toLowerCase() == cleanTerm.toLowerCase());

    // Insert at front
    current.insert(0, cleanTerm);

    // Keep only the most recent items
    if (current.length > _maxHistoryCount) {
      current.removeRange(_maxHistoryCount, current.length);
    }

    await prefs.setStringList(_keyHistory, current);
  }

  /// Removes a single term from history.
  Future<void> removeTerm(String term) async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> current = prefs.getStringList(_keyHistory) ?? [];
    current.removeWhere((item) => item.toLowerCase() == term.trim().toLowerCase());
    await prefs.setStringList(_keyHistory, current);
  }

  /// Clears the entire search history.
  Future<void> clearHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyHistory);
  }
}
