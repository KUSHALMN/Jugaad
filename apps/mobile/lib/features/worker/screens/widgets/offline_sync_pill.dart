import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Non-blocking floating status indicator when worker is offline or on slow edge network.
/// Informs partner that all job updates and timestamps are saved locally and will auto-sync.
class OfflineSyncPill extends StatelessWidget {
  final bool isOffline;
  final int pendingActionsCount;
  final VoidCallback? onRetryTap;

  const OfflineSyncPill({
    super.key,
    required this.isOffline,
    this.pendingActionsCount = 0,
    this.onRetryTap,
  });

  @override
  Widget build(BuildContext context) {
    if (!isOffline && pendingActionsCount == 0) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB), // Soft warm amber
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFDE68A), width: 1.2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14D97706),
            blurRadius: 12,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: const BoxDecoration(
              color: Color(0xFFFEF3C7),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.cloud_off_rounded,
              color: Color(0xFFD97706),
              size: 16,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  isOffline ? 'Offline Mode Active' : 'Syncing updates...',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF92400E),
                  ),
                ),
                Text(
                  pendingActionsCount > 0
                      ? '$pendingActionsCount actions saved locally • Auto-syncs when online'
                      : 'Job data safe offline • Will auto-sync when network returns',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFFB45309),
                  ),
                ),
              ],
            ),
          ),
          if (onRetryTap != null)
            InkWell(
              onTap: onRetryTap,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'Retry',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
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
