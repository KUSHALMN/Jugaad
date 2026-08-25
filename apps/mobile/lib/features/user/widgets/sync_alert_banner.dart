import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/providers/sync_status_provider.dart';
import '../../../core/network/connectivity_service.dart';

class SyncAlertBanner extends ConsumerWidget {
  const SyncAlertBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final syncState = ref.watch(syncStatusProvider);

    if (syncState == ConnectivityState.online) {
      return const SizedBox.shrink();
    }

    final isWaking = syncState == ConnectivityState.serverWaking;
    final bgColor = isWaking
        ? Colors.orange.shade50.withValues(alpha: 0.9)
        : Colors.red.shade50.withValues(alpha: 0.9);
    final borderColor = isWaking ? Colors.orange.shade200 : Colors.red.shade200;
    final iconColor = isWaking ? Colors.orange.shade700 : Colors.red.shade700;
    final textColor = isWaking ? Colors.orange.shade900 : Colors.red.shade900;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor, width: 1.0),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                isWaking
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
                        ),
                      )
                    : Icon(Icons.cloud_off_rounded, color: iconColor, size: 18),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    isWaking
                        ? 'Waking up servers... (May take up to 45s on Render)'
                        : 'Offline Mode: Actions will sync once reconnected.',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    )
    .animate()
    .slideY(begin: -0.5, end: 0, duration: 300.ms, curve: Curves.easeOutBack)
    .fadeIn(duration: 200.ms);
  }
}
