import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/offline_mutation.dart';

/// Manages an on-device resilient FIFO queue for optimistic worker and user actions.
/// Persists mutations to SharedPreferences so that even if the app process terminates
/// or crashes in low-bandwidth basements, actions are not lost.
class OfflineQueueService {
  static const String _storageKey = 'jugaad_offline_mutations_queue_v1';

  static final OfflineQueueService _instance = OfflineQueueService._internal();
  factory OfflineQueueService() => _instance;
  OfflineQueueService._internal();

  final List<OfflineMutation> _queue = [];
  bool _isInitialized = false;

  final ValueNotifier<int> pendingCountNotifier = ValueNotifier<int>(0);
  final StreamController<List<OfflineMutation>> _queueStreamController =
      StreamController<List<OfflineMutation>>.broadcast();

  Stream<List<OfflineMutation>> get queueStream => _queueStreamController.stream;
  List<OfflineMutation> get currentQueue => List.unmodifiable(_queue);

  /// Initializes the service and loads stored mutations from local storage.
  Future<void> initialize() async {
    if (_isInitialized) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final rawData = prefs.getString(_storageKey);
      if (rawData != null && rawData.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(rawData) as List<dynamic>;
        _queue.clear();
        for (final item in decoded) {
          if (item is Map<String, dynamic>) {
            _queue.add(OfflineMutation.fromMap(item));
          }
        }
      }
      _isInitialized = true;
      _updateListeners();
      debugPrint('[OfflineQueue] Initialized with ${_queue.length} items');
    } catch (e) {
      debugPrint('[OfflineQueue] Error initializing storage: $e');
      _isInitialized = true;
    }
  }

  /// Adds a new mutation to the persistent queue.
  Future<OfflineMutation> enqueue({
    required String jobId,
    required String actionType,
    Map<String, dynamic> payload = const {},
  }) async {
    await initialize();

    final mutation = OfflineMutation(
      id: 'mut_${DateTime.now().millisecondsSinceEpoch}_${_queue.length}',
      jobId: jobId,
      actionType: actionType,
      payload: payload,
      createdAt: DateTime.now(),
      status: MutationStatus.pending,
    );

    _queue.add(mutation);
    await _saveToDisk();
    _updateListeners();

    debugPrint('[OfflineQueue] Enqueued ${mutation.actionType} for job ${mutation.jobId}');
    return mutation;
  }

  /// Returns all mutations that require execution.
  List<OfflineMutation> getPendingMutations() {
    return _queue
        .where((m) => m.status == MutationStatus.pending || m.status == MutationStatus.failed)
        .toList();
  }

  /// Marks a mutation as currently syncing to prevent parallel execution.
  Future<void> markSyncing(String id) async {
    final index = _queue.indexWhere((m) => m.id == id);
    if (index != -1) {
      _queue[index].status = MutationStatus.syncing;
      await _saveToDisk();
      _updateListeners();
    }
  }

  /// Removes a succeeded mutation from the queue.
  Future<void> markCompleted(String id) async {
    _queue.removeWhere((m) => m.id == id);
    await _saveToDisk();
    _updateListeners();
    debugPrint('[OfflineQueue] Mutation $id completed and pruned');
  }

  /// Records a failure and updates the retry counter.
  Future<void> markFailed(String id, String errorReason) async {
    final index = _queue.indexWhere((m) => m.id == id);
    if (index != -1) {
      _queue[index].status = MutationStatus.failed;
      _queue[index].retryCount += 1;
      _queue[index].lastError = errorReason;
      await _saveToDisk();
      _updateListeners();
      debugPrint('[OfflineQueue] Mutation $id failed (attempt ${_queue[index].retryCount}): $errorReason');
    }
  }

  /// Clears all completed or failed items.
  Future<void> clearQueue() async {
    _queue.clear();
    await _saveToDisk();
    _updateListeners();
  }

  Future<void> _saveToDisk() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final serialized = jsonEncode(_queue.map((m) => m.toMap()).toList());
      await prefs.setString(_storageKey, serialized);
    } catch (e) {
      debugPrint('[OfflineQueue] Failed saving to disk: $e');
    }
  }

  void _updateListeners() {
    final pendingCount = getPendingMutations().length;
    pendingCountNotifier.value = pendingCount;
    _queueStreamController.add(List.unmodifiable(_queue));
  }
}
