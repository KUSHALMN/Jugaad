import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shimmer/shimmer.dart';
import 'package:jugaad_mvp/core/config/supabase_config.dart';
import 'package:jugaad_mvp/core/theme/app_colors.dart';
import 'package:jugaad_mvp/core/theme/portal_mode.dart';
import 'package:jugaad_mvp/features/shared/widgets/mode_switch_sheet.dart';

import '../../worker/screens/worker_portal_screen.dart';
import '../../user/screens/user_portal_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  void _showModeSwitchSheet(BuildContext context, PortalMode currentMode) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ModeSwitchSheet(currentMode: currentMode),
    );
  }

  // BUG FIX
  Widget _buildSkeleton() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Profile header skeleton
          Container(
            width: double.infinity,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          const SizedBox(height: 12),
          // Chips row skeleton
          Row(children: [
            _skeletonBox(120, 36),
            const SizedBox(width: 8),
            _skeletonBox(100, 36),
          ]),
          const SizedBox(height: 12),
          // List items skeleton
          ...List.generate(4, (_) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _skeletonBox(double.infinity, 52),
          )),
        ],
      ),
    );
  }

  // BUG FIX
  Widget _skeletonBox(double width, double height) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final modeProvider = Provider.of<PortalModeProvider>(context);
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: Text('Not authenticated. Please log in.'),
        ),
      );
    }

    final uid = user.uid;

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: SupabaseConfig.client
          .from('workers')
          .stream(primaryKey: ['id'])
          .eq('id', uid),
      builder: (context, snapshot) {
        // BUG FIX
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            backgroundColor: AppColors.background,
            body: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: _buildSkeleton(),
              ),
            ),
          );
        }

        // Dispatch based on selected Mode or fallback to UserPortalScreen
        if (modeProvider.mode == PortalMode.worker) {
          return WorkerPortalScreen(
            onSwitchMode: () => _showModeSwitchSheet(context, modeProvider.mode),
          );
        } else {
          return UserPortalScreen(
            onSwitchMode: () => _showModeSwitchSheet(context, modeProvider.mode),
          );
        }
      },
    );
  }
}
