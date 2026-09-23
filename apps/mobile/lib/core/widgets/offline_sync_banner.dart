import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/offline_sync_manager.dart';
import '../utils/jugaad_haptics.dart';

/// An adaptive, animated banner that alerts field workers when operating in
/// offline/low-bandwidth environments and offers one-tap sync controls.
class OfflineSyncBanner extends ConsumerWidget {
  const OfflineSyncBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOnlineAsync = ref.watch(isOnlineProvider);
    final pendingCountAsync = ref.watch(pendingOfflineMutationsCountProvider);

    final isOnline = isOnlineAsync.value ?? true;
    final pendingCount = pendingCountAsync.value ?? 0;

    // If online and zero pending changes, hide banner completely
    if (isOnline && pendingCount == 0) {
      return const SizedBox.shrink();
    }

    final isOffline = !isOnline;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      decoration: BoxDecoration(
        color: isOffline ? const Color(0xFFFEF3C7) : const Color(0xFFEFF6FF),
        border: Border(
          bottom: BorderSide(
            color: isOffline ? const Color(0xFFFDE68A) : const Color(0xFFBFDBFE),
            width: 1.0,
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: isOffline ? const Color(0xFFF59E0B) : const Color(0xFF2563EB),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isOffline ? Icons.wifi_off_rounded : Icons.sync_rounded,
              color: Colors.white,
              size: 14,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  isOffline
                      ? 'Offline Mode Active'
                      : 'Syncing Pending Updates...',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: isOffline ? const Color(0xFF92400E) : const Color(0xFF1E40AF),
                  ),
                ),
                Text(
                  pendingCount > 0
                      ? '$pendingCount action${pendingCount > 1 ? 's' : ''} queued (will sync automatically)'
                      : 'Changes are saved securely on this device',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    color: isOffline ? const Color(0xFFB45309) : const Color(0xFF3B82F6),
                  ),
                ),
              ],
            ),
          ),
          if (isOnline && pendingCount > 0)
            InkWell(
              onTap: () {
                JugaadHaptics.light();
                OfflineSyncManager().syncPendingMutations();
              },
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Sync Now',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
