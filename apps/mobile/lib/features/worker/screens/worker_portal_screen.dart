import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:jugaad_mvp/core/config/supabase_config.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shimmer/shimmer.dart';
import 'package:jugaad_mvp/core/theme/app_colors.dart';
import 'package:jugaad_mvp/core/theme/app_text_styles.dart';
import 'package:jugaad_mvp/shared/widgets/jugaad_card.dart';
import 'package:lottie/lottie.dart';

import 'account_settings_screen.dart';
import 'payment_methods_screen.dart';
import 'notification_settings_screen.dart';
import 'payout_settings_screen.dart';
import 'bank_account_screen.dart';
import 'edit_worker_profile_screen.dart';
import '../widgets/worker_job_history_bottom_sheet.dart';
import '../../shared/screens/help_support_screen.dart';
import 'package:jugaad_mvp/core/utils/jugaad_haptics.dart';


class WorkerPortalScreen extends StatefulWidget {
  final VoidCallback onSwitchMode;
  const WorkerPortalScreen({super.key, required this.onSwitchMode});

  @override
  State<WorkerPortalScreen> createState() => _WorkerPortalScreenState();
}

class _WorkerPortalScreenState extends State<WorkerPortalScreen> with TickerProviderStateMixin {
  bool? _optimisticOnlineStatus;

  late AnimationController _entryController;
  late AnimationController _ratingController;
  late AnimationController _shimmerController;

  @override
  void initState() {
    super.initState();
    _entryController = AnimationController(vsync: this, duration: 800.ms)..forward();
    _ratingController = AnimationController(vsync: this, duration: 600.ms);
    _shimmerController = AnimationController(vsync: this, duration: 1800.ms)..repeat();

    _ratingController.addStatusListener((s) {
      if (s == AnimationStatus.forward) JugaadHaptics.light();
      if (s == AnimationStatus.completed) JugaadHaptics.selection();
    });

    Future.delayed(400.ms, () {
      if (mounted) _ratingController.forward();
    });

    WidgetsBinding.instance.addPostFrameCallback((_) => JugaadHaptics.light());
  }

  @override
  void dispose() {
    _entryController.dispose();
    _ratingController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  String _getInitials(String name) {
    if (name.trim().isEmpty) return '??';
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length > 1) {
      return (parts[0][0] + parts[parts.length - 1][0]).toUpperCase();
    }
    return parts[0].substring(0, parts[0].length >= 2 ? 2 : 1).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final primaryColor = AppColors.kWorkerPrimary;
    final primaryLightColor = AppColors.kWorkerPrimaryLight;

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: SupabaseConfig.client
          .from('workers')
          .stream(primaryKey: ['id'])
          .eq('id', uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData && !snapshot.hasError) {
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

        final list = (snapshot.hasData && snapshot.data != null) ? snapshot.data! : <Map<String, dynamic>>[];
        final data = list.isNotEmpty ? list.first : <String, dynamic>{};
        String name = data['name'] as String? ?? '';
        if (name.trim().isEmpty || name == 'No Name') {
          final user = FirebaseAuth.instance.currentUser;
          final firebaseName = user?.displayName;
          if (firebaseName != null && firebaseName.trim().isNotEmpty) {
            name = firebaseName;
          } else {
            final email = user?.email;
            if (email != null && email.contains('@')) {
              name = email.split('@').first;
            } else {
              name = 'No Name';
            }
          }
        }
        final phone = data['phone'] as String? ?? '';
        final specialities = List<String>.from(data['specialities'] as List? ?? []);
        final currentOnlineStatus = data['isOnline'] as bool? ?? false;
        final activeOnlineStatus = _optimisticOnlineStatus ?? currentOnlineStatus;

        final initials = _getInitials(name);

        final profileCard = JugaadCard(
          borderRadius: 24.0,
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              Center(
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(4.0),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: primaryColor.withValues(alpha: 0.3),
                          width: 2,
                        ),
                      ),
                      child: CircleAvatar(
                        radius: 36,
                        backgroundColor: primaryLightColor,
                        child: Text(
                          initials,
                          style: AppTextStyles.heading1(color: primaryColor),
                        ),
                      ),
                    ).animate()
                     .scale(begin: const Offset(0.8, 0.8), delay: 0.ms, duration: 500.ms, curve: Curves.easeOutBack)
                     .fadeIn(duration: 400.ms),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          name,
                          style: AppTextStyles.heading3(color: AppColors.textPrimary),
                        ).animate()
                         .fadeIn(delay: 150.ms, duration: 400.ms)
                         .slideX(begin: -0.1, delay: 150.ms, duration: 400.ms),
                        if (data['isVerified'] as bool? ?? true)
                          Padding(
                            padding: const EdgeInsets.only(left: 6.0),
                            child: RepaintBoundary(
                              child: SizedBox(
                                width: 32,
                                height: 32,
                                child: Lottie.asset(
                                  'assets/lottie/profile_verified.json',
                                  repeat: false,
                                  frameRate: const FrameRate(30),
                                ),
                              ),
                            ).animate().scale(delay: 300.ms, duration: 300.ms, curve: Curves.elasticOut),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      phone.isNotEmpty ? '$phone · Mysuru' : 'Mysuru',
                      style: AppTextStyles.bodyMedium(color: AppColors.textSecondary),
                    ).animate()
                     .fadeIn(delay: 200.ms, duration: 400.ms),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Container(
                height: 1.0,
                color: AppColors.kBorder.withValues(alpha: 0.6),
              ),
              const SizedBox(height: 20),
              LayoutBuilder(
                builder: (context, constraints) {
                  final rawRating = data['rating'];
                  final totalJobsCompleted = data['totalJobsCompleted'] ?? data['total_jobs'] ?? 0;
                  final ratingDisplay = (rawRating != null && totalJobsCompleted > 0)
                      ? (rawRating as num).toDouble().toStringAsFixed(1)
                      : 'New';

                  final statCards = [
                    _buildStatCard('Jobs Completed', '$totalJobsCompleted', null, data),
                    _buildStatCard('Earnings', '₹${data['totalEarnings'] ?? '0'}', null, data),
                    _buildStatCard('Average Rating', ratingDisplay, _ratingController, data),
                    _buildStatCard('Experience', '${data['experience'] ?? '1+'} yrs', null, data),
                  ];

                  
                  final cardWidth = (constraints.maxWidth - 12) / 2;
                  
                  return Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: statCards.asMap().entries.map((entry) {
                      return SizedBox(
                        width: cardWidth,
                        child: entry.value
                          .animate()
                          .fadeIn(delay: Duration(milliseconds: 300 + entry.key * 80))
                          .slideY(
                            begin: 0.15,
                            delay: Duration(milliseconds: 300 + entry.key * 80),
                            duration: 400.ms,
                            curve: Curves.easeOut,
                          ),
                      );
                    }).toList(),
                  );
                }
              ),
            ],
          ),
        );

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textPrimary),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(
              'Worker Portal',
              style: AppTextStyles.heading3(color: AppColors.textPrimary),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => EditWorkerProfileScreen(currentData: data),
                    ),
                  );
                },
                child: Text(
                  'Edit',
                  style: AppTextStyles.bodyMedium(color: primaryColor, weight: FontWeight.bold),
                ),
              ),
            ],
          ),
          body: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              children: [
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: profileCard,
                ),
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: JugaadCard(
                    borderRadius: 20.0,
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.swap_horizontal_circle_outlined,
                              color: primaryColor,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'PORTAL SELECTOR',
                              style: AppTextStyles.bodySmall(
                                color: AppColors.textSecondary,
                                weight: FontWeight.bold,
                              ).copyWith(letterSpacing: 1.0),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(4.0),
                          decoration: BoxDecoration(
                            color: AppColors.background,
                            borderRadius: BorderRadius.circular(14.0),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: GestureDetector(
                                  onTap: widget.onSwitchMode,
                                  child: Container(
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: Colors.transparent,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      'User Portal',
                                      style: AppTextStyles.bodyMedium(
                                        color: AppColors.textSecondary,
                                        weight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Container(
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: AppColors.kWorkerPrimary,
                                    borderRadius: BorderRadius.circular(10),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppColors.kWorkerPrimary.withValues(alpha: 0.25),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      )
                                    ],
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    'Worker Portal',
                                    style: AppTextStyles.bodyMedium(
                                      color: Colors.white,
                                      weight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: JugaadCard(
                    borderRadius: 20.0,
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.verified_user_rounded,
                              color: primaryColor,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'REGISTERED SPECIALITIES',
                              style: AppTextStyles.bodySmall(
                                color: AppColors.textSecondary,
                                weight: FontWeight.bold,
                              ).copyWith(letterSpacing: 1.0),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        if (specialities.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8.0),
                            child: Text(
                              'No specialities registered yet',
                              style: AppTextStyles.bodyMedium(
                                color: AppColors.textSecondary,
                              ).copyWith(fontStyle: FontStyle.italic),
                            ),
                          )
                        else
                          Wrap(
                            spacing: 8.0,
                            runSpacing: 8.0,
                            children: specialities.asMap().entries.map((entry) {
                              final idx = entry.key;
                              final skill = entry.value;
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: primaryLightColor,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: primaryColor.withValues(alpha: 0.25), width: 1.2),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.check_circle_rounded, color: primaryColor, size: 14),
                                    const SizedBox(width: 6),
                                    Text(
                                      skill,
                                      style: AppTextStyles.bodySmall(
                                        color: primaryColor,
                                        weight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                              .animate()
                              .scale(
                                begin: const Offset(0.0, 0.0),
                                end: const Offset(1.0, 1.0),
                                duration: 350.ms,
                                delay: (idx * 60).ms,
                                curve: Curves.elasticOut,
                              );
                            }).toList(),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: JugaadCard(
                    borderRadius: 16.0,
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
                    color: AppColors.background,
                    animate: false,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: activeOnlineStatus ? AppColors.success : AppColors.textSecondary.withValues(alpha: 0.5),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Online status',
                                  style: AppTextStyles.bodyLarge(
                                    color: AppColors.textPrimary,
                                    weight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            CupertinoSwitch(
                              value: activeOnlineStatus,
                              activeTrackColor: AppColors.kSuccess,
                              onChanged: (val) async {
                                setState(() {
                                  _optimisticOnlineStatus = val;
                                });

                                try {
                                  // Supabase: update online status
                                  await SupabaseConfig.client
                                      .from('workers')
                                      .update({
                                    'is_online': val,
                                    'last_online_at': DateTime.now().toUtc().toIso8601String(),
                                  }).eq('id', uid);
                                  if (mounted) {
                                    setState(() {
                                      _optimisticOnlineStatus = null;
                                    });
                                  }
                                } catch (e) {
                                  if (context.mounted) {
                                    setState(() {
                                      _optimisticOnlineStatus = null;
                                    });
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Error updating status: $e'),
                                        backgroundColor: AppColors.danger,
                                        behavior: SnackBarBehavior.floating,
                                      ),
                                    );
                                  }
                                }
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Workers are expected to stay online during pilot.',
                          style: AppTextStyles.bodySmall(
                            color: AppColors.warning,
                            weight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: JugaadCard(
                    borderRadius: 20.0,
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Column(
                      children: [
                        _buildMenuListItem(
                          context,
                          Icons.work_history_outlined,
                          'Performance & Job History',
                          () => WorkerJobHistoryBottomSheet.show(context),
                        ),
                        _buildMenuListItem(
                          context,
                          Icons.person_outline_rounded,
                          'Account settings',
                          () => Navigator.push(context, MaterialPageRoute(builder: (context) => AccountSettingsScreen(currentData: data))),
                        ),

                        _buildMenuListItem(
                          context,
                          Icons.payment_outlined,
                          'Payment methods',
                          () => Navigator.push(context, MaterialPageRoute(builder: (context) => PaymentMethodsScreen(currentData: data))),
                        ),
                        _buildMenuListItem(
                          context,
                          Icons.notifications_none_rounded,
                          'Notification settings',
                          () => Navigator.push(context, MaterialPageRoute(builder: (context) => NotificationSettingsScreen(currentData: data))),
                        ),
                        _buildMenuListItem(
                          context,
                          Icons.account_balance_wallet_outlined,
                          'Payout settings',
                          () => Navigator.push(context, MaterialPageRoute(builder: (context) => PayoutSettingsScreen(currentData: data))),
                        ),
                        _buildMenuListItem(
                          context,
                          Icons.account_balance_rounded,
                          'Bank account',
                          () => Navigator.push(context, MaterialPageRoute(builder: (context) => BankAccountScreen(currentData: data))),
                        ),
                        _buildMenuListItem(
                          context,
                          Icons.help_outline_rounded,
                          'Help & support',
                          () => Navigator.push(context, MaterialPageRoute(builder: (context) => const HelpSupportScreen())),
                        ),
                        InkWell(
                          onTap: () async {
                            await FirebaseAuth.instance.signOut();
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6.0),
                                  decoration: BoxDecoration(
                                    color: AppColors.danger.withValues(alpha: 0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.logout_rounded,
                                    color: AppColors.danger,
                                    size: 18,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  'Logout',
                                  style: AppTextStyles.bodyLarge(
                                    color: AppColors.danger,
                                    weight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 48),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMenuListItem(BuildContext context, IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: AppColors.kBorder.withValues(alpha: 0.4),
              width: 0.8,
            ),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.textSecondary, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: AppTextStyles.bodyMedium(
                  color: AppColors.textPrimary,
                  weight: FontWeight.bold,
                ),
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              color: AppColors.textSecondary,
              size: 14,
            ),
          ],
        ),
      ),
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

  Widget _buildStatCard(String label, String value, AnimationController? ratingController, Map<String, dynamic> data) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.kBorder.withValues(alpha: 0.4)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: AppTextStyles.heading2(color: AppColors.textPrimary),
          ),
          if (ratingController != null)
            Padding(
              padding: const EdgeInsets.only(top: 2.0),
              child: RepaintBoundary(
                child: SizedBox(
                  width: 90,
                  height: 24,
                  child: Lottie.asset(
                    'assets/lottie/stars_rating.json',
                    repeat: false,
                    controller: ratingController.drive(
                      Tween<double>(
                        begin: 0.0,
                        end: ((data['rating'] as num? ?? 4.8).toDouble()) / 5.0,
                      ),
                    ),
                    frameRate: const FrameRate(30),
                  ),
                ),
              ),
            ),
          SizedBox(height: ratingController != null ? 4 : 8),
          Text(
            label,
            style: AppTextStyles.bodySmall(color: AppColors.textSecondary, weight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
