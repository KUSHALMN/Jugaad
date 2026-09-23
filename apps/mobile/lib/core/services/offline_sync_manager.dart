import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/offline_mutation.dart';
import 'offline_queue_service.dart';
import 'api_service.dart';

/// Provider for overall network online status.
final isOnlineProvider = StreamProvider<bool>((ref) {
  return Connectivity().onConnectivityChanged.map((results) {
    if (results.isEmpty) return false;
    return results.any((r) => r != ConnectivityResult.none);
  });
});

/// Provider for real-time count of pending offline mutations.
final pendingOfflineMutationsCountProvider = StreamProvider<int>((ref) {
  final queueService = OfflineQueueService();
  return queueService.queueStream.map((queue) {
    return queue.where((m) => m.status == MutationStatus.pending || m.status == MutationStatus.failed).length;
  });
});

/// Coordinates real-time connectivity listening and automatic sequential replay of
/// queued offline mutations when internet access is restored.
class OfflineSyncManager {
  static final OfflineSyncManager _instance = OfflineSyncManager._internal();
  factory OfflineSyncManager() => _instance;
  OfflineSyncManager._internal();

  final Connectivity _connectivity = Connectivity();
  final OfflineQueueService _queueService = OfflineQueueService();
  final ApiService _apiService = ApiService();

  StreamSubscription<List<ConnectivityResult>>? _subscription;
  bool _isSyncing = false;

  /// Starts listening to connectivity transitions.
  void start() {
    _queueService.initialize();
    _subscription?.cancel();
    _subscription = _connectivity.onConnectivityChanged.listen((results) {
      final isConnected = results.any((r) => r != ConnectivityResult.none);
      if (isConnected) {
        debugPrint('[OfflineSyncManager] Connection restored! Triggering queue flush.');
        syncPendingMutations();
      }
    });
  }

  /// Manually or automatically flushes the queue of pending mutations sequentially.
  Future<void> syncPendingMutations() async {
    if (_isSyncing) return;
    _isSyncing = true;

    try {
      final pendingList = _queueService.getPendingMutations();
      if (pendingList.isEmpty) {
        _isSyncing = false;
        return;
      }

      debugPrint('[OfflineSyncManager] Flushing ${pendingList.length} pending mutations...');

      for (final mutation in pendingList) {
        await _processMutation(mutation);
      }
    } catch (e) {
      debugPrint('[OfflineSyncManager] Sync cycle encountered error: $e');
    } finally {
      _isSyncing = false;
    }
  }

  Future<void> _processMutation(OfflineMutation mutation) async {
    await _queueService.markSyncing(mutation.id);

    try {
      switch (mutation.actionType) {
        case 'confirm_on_the_way':
          await _apiService.confirmOnTheWay(mutation.jobId);
          break;

        case 'ack_arrival':
          await _apiService.ackJob(mutation.jobId);
          break;

        case 'complete_job':
          final confirmer = mutation.payload['confirmer'] as String? ?? 'worker';
          await _apiService.completeJob(mutation.jobId, confirmer: confirmer);
          break;

        case 'price_change':
          final newPrice = (mutation.payload['new_price'] as num?)?.toDouble() ?? 0.0;
          final reason = mutation.payload['reason'] as String? ?? 'Field adjustments';
          await _apiService.requestPriceChange(mutation.jobId, newPrice, reason);
          break;

        case 'location_ping':
          final lat = (mutation.payload['lat'] as num?)?.toDouble() ?? 0.0;
          final lng = (mutation.payload['lng'] as num?)?.toDouble() ?? 0.0;
          final isAvailable = mutation.payload['is_available'] as bool? ?? true;
          await _apiService.updateWorkerLocation(lat: lat, lng: lng, isAvailable: isAvailable);
          break;

        default:
          debugPrint('[OfflineSyncManager] Unknown mutation type: ${mutation.actionType}');
      }

      await _queueService.markCompleted(mutation.id);
      debugPrint('[OfflineSyncManager] Mutation ${mutation.id} (${mutation.actionType}) successfully synced.');
    } catch (e) {
      debugPrint('[OfflineSyncManager] Failed syncing mutation ${mutation.id}: $e');
      await _queueService.markFailed(mutation.id, e.toString());
    }
  }

  void stop() {
    _subscription?.cancel();
    _subscription = null;
  }
}
