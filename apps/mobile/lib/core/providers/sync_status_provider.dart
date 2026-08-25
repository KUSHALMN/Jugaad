import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../network/connectivity_service.dart';

class SyncStatusNotifier extends Notifier<ConnectivityState> {
  @override
  ConnectivityState build() {
    final notifier = ConnectivityService.state;

    void listener() {
      state = notifier.value;
    }

    notifier.addListener(listener);

    ref.onDispose(() {
      notifier.removeListener(listener);
    });

    return notifier.value;
  }
}

final syncStatusProvider = NotifierProvider<SyncStatusNotifier, ConnectivityState>(
  SyncStatusNotifier.new,
);
