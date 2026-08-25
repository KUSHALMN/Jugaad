import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:jugaad_mvp/core/theme/app_colors.dart';
import 'package:jugaad_mvp/core/theme/portal_mode.dart';

class ModeSwitchSheet extends StatelessWidget {
  final PortalMode currentMode;

  const ModeSwitchSheet({super.key, required this.currentMode});

  void _switchMode(BuildContext context) {
    final targetMode = currentMode == PortalMode.user ? PortalMode.worker : PortalMode.user;
    print('[MODE_SWITCH] Switching from ${currentMode.name} to ${targetMode.name}');
    
    // Update Mode in Provider
    Provider.of<PortalModeProvider>(context, listen: false).setMode(targetMode);
    print('[MODE_SWITCH] Mode saved to preferences.');
    
    // Close the bottom sheet
    Navigator.pop(context);
    
    // Router naturally redirects because it listens to the ModeProvider,
    // but just to be safe, we can manually trigger the root routing:
    if (targetMode == PortalMode.worker) {
      context.go('/worker/home');
    } else {
      context.go('/user/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isToWorker = currentMode == PortalMode.user;
    final targetModeName = isToWorker ? 'Worker' : 'User';
    final targetColor = isToWorker ? AppColors.kWorkerPrimary : AppColors.kUserPrimary;

    return Container(
      padding: const EdgeInsets.only(top: 12, left: 24, right: 24, bottom: 32),
      decoration: const BoxDecoration(
        color: AppColors.kBackground,
        borderRadius: BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 32,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.kTextTertiary.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),
          
          Text('Switch to $targetModeName mode?', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.kTextPrimary)),
          const SizedBox(height: 12),
          Text(
            isToWorker
                ? "Your bookings stay saved. You'll start receiving job requests."
                : "Your earnings and job history stay saved.",
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, color: AppColors.kTextSecond),
          ),
          const SizedBox(height: 32),
          
          ElevatedButton(
            onPressed: () => _switchMode(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: targetColor,
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text('Yes, switch to ${targetModeName.toLowerCase()} mode', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () => Navigator.pop(context),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.kNeutralBorder),
              minimumSize: const Size.fromHeight(44),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text('Stay in ${currentMode.name} mode', style: const TextStyle(color: AppColors.kTextSecond, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
