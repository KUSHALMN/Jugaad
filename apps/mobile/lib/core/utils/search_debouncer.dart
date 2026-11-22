import 'dart:async';

/// Production search debouncer with LRU query memoization for Jugaad.
///
/// Prevents redundant network queries during fast typing and instant-returns
/// cached results when backspacing or re-entering previously queried terms.
class SearchDebouncer<T> {
  final Duration delay;
  final int maxCacheEntries;
  Timer? _timer;
  final Map<String, T> _memoCache = {};

  SearchDebouncer({
    this.delay = const Duration(milliseconds: 300),
    this.maxCacheEntries = 40,
  });

  /// Run debounced action or return immediately from cache if available.
  void run({
    required String query,
    required Future<T> Function() action,
    required void Function(T result, bool fromCache) onResult,
  }) {
    final cleanQuery = query.trim().toLowerCase();

    // Cache hit: instant dispatch without waiting for debounce timer
    if (_memoCache.containsKey(cleanQuery)) {
      _timer?.cancel();
      onResult(_memoCache[cleanQuery] as T, true);
      return;
    }

    _timer?.cancel();
    _timer = Timer(delay, () async {
      final res = await action();
      if (_memoCache.length >= maxCacheEntries) {
        _memoCache.remove(_memoCache.keys.first);
      }
      _memoCache[cleanQuery] = res;
      onResult(res, false);
    });
  }

  /// Check whether a query is already memoized in RAM
  bool isMemoized(String query) => _memoCache.containsKey(query.trim().toLowerCase());

  /// Get memoized result directly
  T? getMemoized(String query) => _memoCache[query.trim().toLowerCase()];

  /// Clear in-memory memoization cache
  void clearCache() => _memoCache.clear();

  /// Cancel active timer
  void cancel() {
    _timer?.cancel();
    _timer = null;
  }

  /// Dispose debouncer resources
  void dispose() {
    cancel();
    clearCache();
  }
}
