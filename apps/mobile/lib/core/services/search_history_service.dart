import 'fast_storage_service.dart';

class SearchHistoryService {
  static const String _keyHistory = 'search_history_items';
  static const int _maxHistoryCount = 8;

  SearchHistoryService._privateConstructor();
  static final SearchHistoryService instance = SearchHistoryService._privateConstructor();

  /// Retrieves search history synchronously from memory cache (O(1) latency).
  List<String> getHistorySync() {
    return FastStorageService.instance.getStringList(_keyHistory);
  }

  /// Retrieves the stored search history items (asynchronous compatibility wrapper).
  Future<List<String>> getHistory() async {
    return getHistorySync();
  }

  /// Adds a new search term to history, moving it to the top.
  Future<void> addTerm(String term) async {
    final cleanTerm = term.trim();
    if (cleanTerm.isEmpty) return;

    final List<String> current = List<String>.from(getHistorySync());

    // Remove duplicates
    current.removeWhere((item) => item.toLowerCase() == cleanTerm.toLowerCase());

    // Insert at front
    current.insert(0, cleanTerm);

    // Keep only the most recent items
    if (current.length > _maxHistoryCount) {
      current.removeRange(_maxHistoryCount, current.length);
    }

    await FastStorageService.instance.setStringList(_keyHistory, current);
  }

  /// Removes a single term from history.
  Future<void> removeTerm(String term) async {
    final List<String> current = List<String>.from(getHistorySync());
    current.removeWhere((item) => item.toLowerCase() == term.trim().toLowerCase());
    await FastStorageService.instance.setStringList(_keyHistory, current);
  }

  /// Clears the entire search history.
  Future<void> clearHistory() async {
    await FastStorageService.instance.remove(_keyHistory);
  }
}
