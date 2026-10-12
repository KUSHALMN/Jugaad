import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:jugaad_mvp/core/config/supabase_config.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shimmer/shimmer.dart';
import 'package:jugaad_mvp/core/theme/app_colors.dart';
import 'package:lottie/lottie.dart';

import 'earnings_screen.dart';
import 'account_settings_screen.dart';
import 'payment_methods_screen.dart';
import 'notification_settings_screen.dart';
import 'payout_settings_screen.dart';
import 'bank_account_screen.dart';
import 'edit_worker_profile_screen.dart';
import '../widgets/worker_job_history_bottom_sheet.dart';
import '../widgets/worker_dashboard_sheets.dart';
import '../../shared/screens/help_support_screen.dart';
import '../../common/screens/legal_policy_screen.dart';
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
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _entryController = AnimationController(vsync: this, duration: 800.ms)..forward();
    _ratingController = AnimationController(vsync: this, duration: 600.ms);
    _shimmerController = AnimationController(vsync: this, duration: 1800.ms)..repeat();
    _pulseController = AnimationController(vsync: this, duration: 1200.ms)..repeat(reverse: true);

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
    _pulseController.dispose();
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
    String uid = '';
    try {
      uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    } catch (_) {}
    final primaryColor = AppColors.kWorkerPrimary;
    final primaryLightColor = AppColors.kWorkerPrimaryLight;

    Stream<List<Map<String, dynamic>>>? workerStream;
    try {
      workerStream = SupabaseConfig.client
          .from('workers')
          .stream(primaryKey: ['id'])
          .eq('id', uid);
    } catch (_) {
      workerStream = Stream.value(<Map<String, dynamic>>[]);
    }

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: workerStream,
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
          try {
            final user = FirebaseAuth.instance.currentUser;
            final firebaseName = user?.displayName;
            if (firebaseName != null && firebaseName.trim().isNotEmpty) {
              name = firebaseName;
            } else {
              final email = user?.email;
              if (email != null && email.contains('@')) {
                name = email.split('@').first;
              } else {
                name = 'Worker';
              }
            }
          } catch (_) {
            name = 'Worker';
          }
        }
        final phone = data['phone'] as String? ?? '';
        final specialities = List<String>.from(data['specialities'] as List? ?? []);
        final currentOnlineStatus = (data['isOnline'] ?? data['is_online']) as bool? ?? false;
        final activeOnlineStatus = _optimisticOnlineStatus ?? currentOnlineStatus;
        final initials = _getInitials(name);

        final totalJobsCompleted = data['totalJobsCompleted'] ?? data['total_jobs'] ?? 0;
        final rawRating = data['rating'];
        final ratingDisplay = (rawRating != null && totalJobsCompleted > 0)
            ? (rawRating as num).toDouble().toStringAsFixed(1)
            : '4.9';
        final totalEarnings = data['totalEarnings'] ?? data['total_earnings'] ?? '0';

        return Scaffold(
          backgroundColor: const Color(0xFFF8FAFC),
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            surfaceTintColor: Colors.transparent,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF0F172A), size: 20),
              onPressed: () => context.go('/worker/home'),
            ),
            title: Row(
              children: [
                Text(
                  'Partner Hub',
                  style: GoogleFonts.plusJakartaSans(
                    color: const Color(0xFF0F172A),
                    fontWeight: FontWeight.w800,
                    fontSize: 20,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.location_on_rounded, size: 12, color: Color(0xFF059669)),
                      const SizedBox(width: 3),
                      Text(
                        'Mysuru',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF475569),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 12.0),
                child: TextButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => EditWorkerProfileScreen(currentData: data),
                      ),
                    );
                  },
                  icon: const Icon(Icons.edit_outlined, size: 15, color: Color(0xFF059669)),
                  label: Text(
                    'Edit',
                    style: GoogleFonts.plusJakartaSans(
                      color: const Color(0xFF059669),
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  style: TextButton.styleFrom(
                    backgroundColor: const Color(0xFFECFDF5),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: const BorderSide(color: Color(0xFFA7F3D0)),
                    ),
                  ),
                ),
              ),
            ],
          ),
          body: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              children: [
                const SizedBox(height: 14),

                // 1. HERO DUTY RADAR CAPSULE
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: _buildDutyRadarCapsule(
                    activeOnlineStatus: activeOnlineStatus,
                    uid: uid,
                    context: context,
                  ),
                ),

                const SizedBox(height: 14),

                // 2. VERIFIED PARTNER IDENTITY CARD
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: _buildPartnerIdentityCard(
                    name: name,
                    phone: phone,
                    initials: initials,
                    ratingDisplay: ratingDisplay,
                    totalJobsCompleted: totalJobsCompleted,
                    isVerified: data['isVerified'] as bool? ?? true,
                    data: data,
                  ),
                ),

                const SizedBox(height: 14),

                // 3. HERO FINTECH EARNINGS CARD
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: _buildHeroEarningsCard(
                    totalEarnings: totalEarnings.toString(),
                    context: context,
                  ),
                ),

                const SizedBox(height: 16),

                // 4. TACTICAL 2x2 QUICK ACTION MATRIX
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: _buildQuickActionMatrix(context),
                ),

                const SizedBox(height: 16),

                // 5. FLUID SEGMENTED GLASS PORTAL SWITCHER
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: _buildPortalSelector(),
                ),

                const SizedBox(height: 16),

                // 6. REGISTERED SPECIALITIES PILLS
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: _buildSpecialitiesSection(
                    specialities: specialities,
                    primaryColor: primaryColor,
                    primaryLightColor: primaryLightColor,
                  ),
                ),

                const SizedBox(height: 16),

                // 7. PREFERENCES, FINANCIALS & OPERATIONAL MENU
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: _buildGroupedMenu(context: context, data: data),
                ),

                const SizedBox(height: 48),
              ],
            ),
          ),
        );
      },
    );
  }

  /// 1. Hero Online/Offline Duty Radar Capsule with Breathing Pulse Beacon
  Widget _buildDutyRadarCapsule({
    required bool activeOnlineStatus,
    required String uid,
    required BuildContext context,
  }) {
    final bgGradient = activeOnlineStatus
        ? const LinearGradient(
            colors: [Color(0xFF047857), Color(0xFF059669)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          )
        : const LinearGradient(
            colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          );

    return Container(
      decoration: BoxDecoration(
        gradient: bgGradient,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: activeOnlineStatus
                ? const Color(0xFF059669).withValues(alpha: 0.35)
                : Colors.black.withValues(alpha: 0.2),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 16.0),
          child: Row(
            children: [
              // Animated Pulse Radar Ring
              Stack(
                alignment: Alignment.center,
                children: [
                  if (activeOnlineStatus)
                    AnimatedBuilder(
                      animation: _pulseController,
                      builder: (context, child) {
                        final scale = 1.0 + (_pulseController.value * 0.45);
                        final opacity = (1.0 - _pulseController.value).clamp(0.0, 1.0);
                        return Container(
                          width: 44 * scale,
                          height: 44 * scale,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFF34D399).withValues(alpha: opacity * 0.4),
                          ),
                        );
                      },
                    ),
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: activeOnlineStatus ? const Color(0xFF10B981) : const Color(0xFF334155),
                      border: Border.all(
                        color: activeOnlineStatus ? const Color(0xFFA7F3D0) : const Color(0xFF475569),
                        width: 2.2,
                      ),
                    ),
                    child: Icon(
                      activeOnlineStatus ? Icons.radar_rounded : Icons.nightlight_round,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 14),

              // Status Description
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          activeOnlineStatus ? 'ONLINE — READY FOR JOBS' : 'OFFLINE — DUTY PAUSED',
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      activeOnlineStatus
                          ? 'Broadcasting GPS • Priority dispatch active'
                          : 'Switch online to receive new client bookings',
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white.withValues(alpha: 0.75),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

              // Cupertino Toggle Switch
              CupertinoSwitch(
                value: activeOnlineStatus,
                activeTrackColor: const Color(0xFF34D399),
                onChanged: (val) async {
                  JugaadHaptics.medium();
                  setState(() {
                    _optimisticOnlineStatus = val;
                  });

                  try {
                    await SupabaseConfig.client.from('workers').update({
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
                          content: Text('Failed to update status: $e'),
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
        ),
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.05, duration: 400.ms);
  }

  /// 2. Verified Partner Identity Card
  Widget _buildPartnerIdentityCard({
    required String name,
    required String phone,
    required String initials,
    required String ratingDisplay,
    required dynamic totalJobsCompleted,
    required bool isVerified,
    required Map<String, dynamic> data,
  }) {
    return Container(
      padding: const EdgeInsets.all(18.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Avatar with dual-ring border
              Container(
                padding: const EdgeInsets.all(3.0),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Color(0xFF059669), Color(0xFF10B981)],
                  ),
                ),
                child: CircleAvatar(
                  radius: 30,
                  backgroundColor: const Color(0xFFECFDF5),
                  child: Text(
                    initials,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF059669),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),

              // Name & Certification Tier
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            name,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF0F172A),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isVerified)
                          Padding(
                            padding: const EdgeInsets.only(left: 6.0),
                            child: RepaintBoundary(
                              child: SizedBox(
                                width: 22,
                                height: 22,
                                child: Lottie.asset(
                                  'assets/lottie/profile_verified.json',
                                  repeat: false,
                                  frameRate: const FrameRate(30),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      phone.isNotEmpty ? '$phone · Verified Partner' : 'Verified Jugaad Partner',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12.5,
                        color: const Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFBBF7D0)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.verified_outlined, size: 12, color: Color(0xFF16A34A)),
                          const SizedBox(width: 4),
                          Text(
                            'Level 2 Certified • Top Fleet',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF16A34A),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 14),

          // Micro Stats Pill Row
          Row(
            children: [
              _buildMiniMetric(
                icon: Icons.star_rounded,
                iconColor: const Color(0xFFF59E0B),
                label: 'Rating',
                value: '$ratingDisplay ★',
              ),
              Container(width: 1, height: 28, color: const Color(0xFFE2E8F0)),
              _buildMiniMetric(
                icon: Icons.check_circle_rounded,
                iconColor: const Color(0xFF10B981),
                label: 'Jobs Done',
                value: '$totalJobsCompleted',
              ),
              Container(width: 1, height: 28, color: const Color(0xFFE2E8F0)),
              _buildMiniMetric(
                icon: Icons.military_tech_rounded,
                iconColor: const Color(0xFF6366F1),
                label: 'Experience',
                value: '${data['experience'] ?? '2+'} yrs',
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(delay: 100.ms, duration: 400.ms).slideY(begin: 0.05, duration: 400.ms);
  }

  Widget _buildMiniMetric({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
  }) {
    return Expanded(
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: iconColor),
              const SizedBox(width: 4),
              Text(
                value,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }

  /// 3. Hero FinTech Earnings Card (The Daily Driver Engine)
  Widget _buildHeroEarningsCard({
    required String totalEarnings,
    required BuildContext context,
  }) {
    final double parsedEarnings = double.tryParse(totalEarnings.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0.0;
    const double dailyTarget = 2500.0;
    final double targetProgress = (parsedEarnings / dailyTarget).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF064E3B), Color(0xFF047857), Color(0xFF065F46)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF047857).withValues(alpha: 0.35),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row with Instant Cashout CTA
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.account_balance_wallet_rounded, size: 16, color: Color(0xFF6EE7B7)),
                  const SizedBox(width: 6),
                  Text(
                    'TODAY\'S NET EARNINGS',
                    style: GoogleFonts.plusJakartaSans(
                      color: const Color(0xFFA7F3D0),
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.0,
                    ),
                  ),
                ],
              ),
              InkWell(
                onTap: () {
                  JugaadHaptics.selection();
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const EarningsScreen()),
                  );
                },
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.bolt_rounded, size: 14, color: Color(0xFF047857)),
                      const SizedBox(width: 4),
                      Text(
                        'Instant Payout',
                        style: GoogleFonts.plusJakartaSans(
                          color: const Color(0xFF047857),
                          fontWeight: FontWeight.w800,
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Large ₹ Currency Typography
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '₹',
                style: GoogleFonts.plusJakartaSans(
                  color: const Color(0xFF6EE7B7),
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                totalEarnings,
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white,
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'UPI Soundbox 🔊',
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          // Daily Target Progress Bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Daily Target: ₹2,500',
                style: GoogleFonts.plusJakartaSans(
                  color: const Color(0xFFA7F3D0),
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '${(targetProgress * 100).toInt()}% Achieved',
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: targetProgress,
              minHeight: 7,
              backgroundColor: Colors.white.withValues(alpha: 0.2),
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF34D399)),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 200.ms, duration: 400.ms).slideY(begin: 0.05, duration: 400.ms);
  }

  /// 4. Tactical 2x2 Quick Action Matrix
  Widget _buildQuickActionMatrix(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.bolt_rounded, size: 18, color: Color(0xFF059669)),
            const SizedBox(width: 6),
            Text(
              'QUICK FLEET ACTIONS',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF64748B),
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildActionTile(
                title: 'Job Radar',
                subtitle: 'Active dispatches',
                icon: Icons.radar_rounded,
                iconColor: const Color(0xFF059669),
                iconBg: const Color(0xFFECFDF5),
                onTap: () => context.go('/worker/home'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildActionTile(
                title: 'UPI Wallet',
                subtitle: 'Direct payouts',
                icon: Icons.account_balance_wallet_rounded,
                iconColor: const Color(0xFFD97706),
                iconBg: const Color(0xFFFFFBEB),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const EarningsScreen()),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildActionTile(
                title: 'Job History',
                subtitle: 'Performance logs',
                icon: Icons.work_history_rounded,
                iconColor: const Color(0xFF2563EB),
                iconBg: const Color(0xFFEFF6FF),
                onTap: () => WorkerJobHistoryBottomSheet.show(context),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildActionTile(
                title: 'Safety SOS',
                subtitle: '24/7 Police & desk',
                icon: Icons.health_and_safety_rounded,
                iconColor: const Color(0xFFDC2626),
                iconBg: const Color(0xFFFEF2F2),
                onTap: () => WorkerDashboardSheets.showSupportSheet(context),
              ),
            ),
          ],
        ),
      ],
    ).animate().fadeIn(delay: 250.ms, duration: 400.ms);
  }

  Widget _buildActionTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: () {
        JugaadHaptics.selection();
        onTap();
      },
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0F172A).withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF0F172A),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF64748B),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 5. Fluid Segmented Glass Portal Switcher
  Widget _buildPortalSelector() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.swap_horizontal_circle_outlined, size: 16, color: Color(0xFF059669)),
              const SizedBox(width: 6),
              Text(
                'APP MODE SWITCHER',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF64748B),
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () {
                      JugaadHaptics.selection();
                      widget.onSwitchMode();
                    },
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      height: 42,
                      decoration: BoxDecoration(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'User Portal',
                        style: GoogleFonts.plusJakartaSans(
                          color: const Color(0xFF64748B),
                          fontWeight: FontWeight.w700,
                          fontSize: 13.5,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Container(
                    height: 42,
                    decoration: BoxDecoration(
                      color: const Color(0xFF059669),
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF059669).withValues(alpha: 0.25),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        )
                      ],
                    ),
                    alignment: Alignment.center,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.shield_rounded, size: 15, color: Colors.white),
                        const SizedBox(width: 6),
                        Text(
                          'Worker Mode',
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 13.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 6. Registered Specialities Section
  Widget _buildSpecialitiesSection({
    required List<String> specialities,
    required Color primaryColor,
    required Color primaryLightColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.verified_user_rounded, color: Color(0xFF059669), size: 16),
              const SizedBox(width: 6),
              Text(
                'REGISTERED TRADE SPECIALITIES',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF64748B),
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (specialities.isEmpty)
            Text(
              'No trade specialities registered yet',
              style: GoogleFonts.plusJakartaSans(
                color: const Color(0xFF94A3B8),
                fontSize: 13,
                fontStyle: FontStyle.italic,
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: specialities.map((skill) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFA7F3D0), width: 1.2),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.check_circle_rounded, color: Color(0xFF059669), size: 14),
                      const SizedBox(width: 6),
                      Text(
                        skill,
                        style: GoogleFonts.plusJakartaSans(
                          color: const Color(0xFF065F46),
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  /// 7. Grouped Settings & Operational List
  Widget _buildGroupedMenu({
    required BuildContext context,
    required Map<String, dynamic> data,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          _buildMenuListItem(
            icon: Icons.person_outline_rounded,
            label: 'Account Settings',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => AccountSettingsScreen(currentData: data)),
            ),
          ),
          _buildMenuListItem(
            icon: Icons.account_balance_rounded,
            label: 'Linked Bank Account',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => BankAccountScreen(currentData: data)),
            ),
          ),
          _buildMenuListItem(
            icon: Icons.payment_outlined,
            label: 'Payment Methods',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => PaymentMethodsScreen(currentData: data)),
            ),
          ),
          _buildMenuListItem(
            icon: Icons.account_balance_wallet_outlined,
            label: 'Payout Preferences',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => PayoutSettingsScreen(currentData: data)),
            ),
          ),
          _buildMenuListItem(
            icon: Icons.notifications_none_rounded,
            label: 'Notifications & Alerts',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => NotificationSettingsScreen(currentData: data)),
            ),
          ),
          _buildMenuListItem(
            icon: Icons.help_outline_rounded,
            label: 'Help & Support Desk',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const HelpSupportScreen()),
            ),
          ),
          _buildMenuListItem(
            icon: Icons.shield_outlined,
            label: 'Privacy, Terms & Grievance',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const LegalPolicyScreen()),
            ),
          ),
          InkWell(
            onTap: () async {
              JugaadHaptics.medium();
              await FirebaseAuth.instance.signOut();
            },
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(22)),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: const BoxDecoration(
                      color: Color(0xFFFEF2F2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.logout_rounded, color: Color(0xFFDC2626), size: 18),
                  ),
                  const SizedBox(width: 14),
                  Text(
                    'Logout from Worker Session',
                    style: GoogleFonts.plusJakartaSans(
                      color: const Color(0xFFDC2626),
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuListItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: () {
        JugaadHaptics.light();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: Color(0xFFF1F5F9),
              width: 1.0,
            ),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: const Color(0xFF64748B), size: 20),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                  color: const Color(0xFF0F172A),
                  fontWeight: FontWeight.w700,
                  fontSize: 13.5,
                ),
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              color: Color(0xFF94A3B8),
              size: 13,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSkeleton() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            height: 72,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            height: 140,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            height: 110,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
          ),
        ],
      ),
    );
  }
}
