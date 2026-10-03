import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:async';
import 'dart:math';
import 'package:jugaad_mvp/core/services/auth_service.dart';
import 'package:jugaad_mvp/core/services/supabase_service.dart';
import 'package:jugaad_mvp/core/services/fcm_token_manager.dart';
import 'package:jugaad_mvp/shared/widgets/shimmer_card.dart';
import 'package:jugaad_mvp/core/services/job_dispatch_service.dart';
import 'package:jugaad_mvp/core/config/supabase_config.dart';
import 'package:jugaad_mvp/core/services/location_service.dart';
import 'package:jugaad_mvp/core/services/platform_config_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class WorkerHomeScreen extends StatefulWidget {
  const WorkerHomeScreen({super.key});

  @override
  State<WorkerHomeScreen> createState() => _WorkerHomeScreenState();
}

class _WorkerHomeScreenState extends State<WorkerHomeScreen>
    with TickerProviderStateMixin {
  String _workerName = '';
  String? _workerAvatarUrl;
  bool _isOnline = false;
  bool _emergencyAvailable = false;
  bool _workerDocExists = false;
  String _approvalStatus = 'approved';
  String? _rejectionReason;
  bool _isBanned = false;
  int _strikesCount = 0;

  double _todayEarnings = 0;
  int _weekJobCount = 0;
  int _todayJobCount = 0;

  String? _activeBookingId;

  List<Map<String, dynamic>> _recentBookings = [];
  bool _recentLoading = true;

  double _prevTotalEarnings = -1;

  StreamSubscription<List<Map<String, dynamic>>>? _workerSub;
  StreamSubscription<List<Map<String, dynamic>>>? _activeBookingSub;
  StreamSubscription<List<Map<String, dynamic>>>? _recentBookingsSub;

  List<_ConfettiParticle> _particles = [];
  late AnimationController _confettiController;
  late AnimationController _radarPulseController;
  bool _showMilestoneBanner = false;

  final _fs = SupabaseService();

  List<String> _workerSkills = [];
  RealtimeChannel? _jobsChannel;

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
    );

    _confettiController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );

    _radarPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();

    _startListeners();
    FCMTokenManager.refreshAndUploadToken();
  }

  void _startListeners() {
    final uid = AuthService().currentUser?.uid;
    if (uid == null) return;

    _workerSub = _fs.workerStream(uid).listen((rows) {
      if (!mounted) return;
      if (rows.isEmpty) {
        setState(() => _workerDocExists = false);
        return;
      }
      final data = rows.first;
      final totalEarnings =
          (data['total_earnings'] as num? ?? 0).toDouble();

      if (_prevTotalEarnings >= 0 &&
          _prevTotalEarnings < 1000 &&
          totalEarnings >= 1000) {
        _triggerMilestoneBurst();
      }
      _prevTotalEarnings = totalEarnings;

      final appr = (data['approval_status'] ?? data['status'] ?? 'pending')
          .toString()
          .toLowerCase();
      final banned = (data['is_banned'] as bool? ?? false) || appr == 'suspended';
      final strikes = (data['strike_count'] as num? ?? data['strikes'] as num? ?? 0).toInt();
      final reason = data['rejection_reason'] as String?;
      final avatar = data['avatar_url'] as String? ?? data['photo_url'] as String?;

      setState(() {
        _workerDocExists = true;
        _workerName = data['name'] as String? ?? '';
        _workerAvatarUrl = avatar;
        _approvalStatus = appr;
        _isBanned = banned;
        _strikesCount = strikes;
        _rejectionReason = reason;
        _isOnline = (banned || appr != 'approved') ? false : (data['is_available'] as bool? ?? false);
        _emergencyAvailable = (banned || appr != 'approved') ? false : (data['emergency_available'] as bool? ?? false);

        final skillsData = data['skills'];
        if (skillsData is List) {
          _workerSkills = List<String>.from(
              skillsData.map((e) => e.toString().toLowerCase().replaceAll(' ', '_')));
        }
      });

      if (_isOnline) {
        _startJobsListener();
      } else {
        _stopJobsListener();
      }
    });

    _activeBookingSub = _fs
        .workerBookingsStream(uid, statuses: ['accepted', 'in_progress'])
        .listen((rows) {
      if (!mounted) return;
      setState(() {
        _activeBookingId =
            rows.isNotEmpty ? rows.first['job_id']?.toString() : null;
      });
    });

    _recentBookingsSub = _fs
        .workerBookingsStream(uid, statuses: ['completed'])
        .listen((rows) {
      if (!mounted) return;

      final today = SupabaseService.computeTodayEarnings(rows);
      final weekCount = SupabaseService.computeWeekJobCount(rows);
      final todayCount = _computeTodayJobCount(rows);

      final recent = rows.take(4).toList();

      setState(() {
        _todayEarnings = today;
        _weekJobCount = weekCount;
        _todayJobCount = todayCount;
        _recentBookings = recent;
        _recentLoading = false;
      });
    }, onError: (_) {
      if (mounted) setState(() => _recentLoading = false);
    });
  }

  int _computeTodayJobCount(List<Map<String, dynamic>> completedBookings) {
    final today = DateTime.now();
    int count = 0;
    for (var b in completedBookings) {
      final compTimeStr = b['completed_at'] ?? b['started_at'];
      if (compTimeStr is String) {
        final t = DateTime.tryParse(compTimeStr);
        if (t != null && t.year == today.year && t.month == today.month && t.day == today.day) {
          count++;
        }
      }
    }
    return count;
  }

  void _setAvailabilityState(bool isAvailable, bool emergencyAvailable) async {
    final uid = AuthService().currentUser?.uid;
    if (uid == null) return;

    HapticFeedback.mediumImpact();

    setState(() {
      _isOnline = isAvailable;
      _emergencyAvailable = emergencyAvailable;
    });

    if (isAvailable) {
      _startJobsListener();
    } else {
      _stopJobsListener();
    }

    try {
      await _fs.setWorkerAvailabilityState(uid,
          isAvailable: isAvailable, emergencyAvailable: emergencyAvailable);
      if (isAvailable) {
        FCMTokenManager.refreshAndUploadToken();
      }
      if (mounted) {
        String msg = '';
        Color bgColor = Colors.grey;
        if (!isAvailable) {
          msg = "Duty Paused: You are now Offline ⚫";
          bgColor = const Color(0xFF334155);
        } else if (emergencyAvailable) {
          msg = "Emergency Priority Fleet Active 🚨 High-hazard surge enabled!";
          bgColor = const Color(0xFFDC2626);
        } else {
          msg = "You are Live 🟢 Dispatch Radar is scanning for nearby jobs!";
          bgColor = const Color(0xFF059669);
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  !isAvailable
                      ? Icons.pause_circle_filled_rounded
                      : (emergencyAvailable ? Icons.bolt_rounded : Icons.radar_rounded),
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    msg,
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
            backgroundColor: bgColor,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('[WORKER_HOME] setWorkerAvailabilityState error: $e');
    }
  }

  void _cycleState() {
    if (_isBanned || _strikesCount >= 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Account Suspended by Admin Operations ($_strikesCount/3 strikes). Please contact partner support.",
            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
          ),
          backgroundColor: const Color(0xFFDC2626),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    if (_approvalStatus != 'approved') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _approvalStatus == 'rejected'
                ? "Application rejected: ${_rejectionReason ?? 'Criteria not met'}. Re-submit verification in profile."
                : "Verification in progress: Admin Ops is validating your Aadhaar & selfie.",
            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
          ),
          backgroundColor: Colors.amber.shade900,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    if (!_isOnline) {
      _setAvailabilityState(true, false);
    } else if (!_emergencyAvailable) {
      _setAvailabilityState(true, true);
    } else {
      _setAvailabilityState(false, false);
    }
  }

  void _triggerMilestoneBurst() {
    HapticFeedback.heavyImpact();
    Future.delayed(const Duration(milliseconds: 150),
        () => HapticFeedback.heavyImpact());
    Future.delayed(const Duration(milliseconds: 300),
        () => HapticFeedback.mediumImpact());

    final random = Random();
    final colors = [
      const Color(0xFFFFD700),
      const Color(0xFF10B981),
      const Color(0xFFFF5722),
      const Color(0xFF3B82F6),
      const Color(0xFFEC4899),
    ];

    _particles = List.generate(60, (i) {
      final xSpawn = random.nextDouble() * 400.0;
      return _ConfettiParticle(
        x: xSpawn,
        y: -10.0,
        vx: -1.5 + random.nextDouble() * 3.0,
        vy: 2.0 + random.nextDouble() * 4.0,
        size: 6.0 + random.nextDouble() * 8.0,
        color: colors[random.nextInt(colors.length)],
        rotation: random.nextDouble() * 2 * pi,
        rotationSpeed: -0.1 + random.nextDouble() * 0.2,
      );
    });

    if (mounted) {
      setState(() => _showMilestoneBanner = true);
    }

    _confettiController.forward(from: 0.0).then((_) {
      if (mounted) {
        setState(() {
          _showMilestoneBanner = false;
          _particles.clear();
        });
      }
    });
  }

  @override
  void dispose() {
    _stopJobsListener();
    _workerSub?.cancel();
    _activeBookingSub?.cancel();
    _recentBookingsSub?.cancel();
    _confettiController.dispose();
    _radarPulseController.dispose();
    super.dispose();
  }

  String getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return 'Good morning';
    } else if (hour < 17) {
      return 'Good afternoon';
    } else {
      return 'Good evening';
    }
  }

  void _showSafetySheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.shield_rounded, color: Color(0xFFDC2626), size: 24),
                ),
                const SizedBox(width: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Partner Safety & SOS 24/7',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    Text(
                      'Direct emergency assistance & security support',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                children: [
                  _buildSafetyRow(Icons.phone_in_talk_rounded, 'Emergency Police SOS', '112', const Color(0xFFDC2626)),
                  const Divider(height: 24),
                  _buildSafetyRow(Icons.support_agent_rounded, 'Jugaad Partner Desk', '+91 8000 554 991', const Color(0xFF059669)),
                  const Divider(height: 24),
                  _buildSafetyRow(Icons.local_hospital_rounded, 'Medical Ambulance', '108', const Color(0xFF2563EB)),
                ],
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF062E1F),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: Text(
                  'Dismiss',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Widget _buildSafetyRow(IconData icon, String title, String phone, Color accentColor) {
    return Row(
      children: [
        Icon(icon, color: accentColor, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1E293B),
                ),
              ),
              Text(
                phone,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: accentColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            'Call Now',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: accentColor,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isWide = screenWidth > 600;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ═══════════════════════════════════════════════════════════
                  // 1. EXECUTIVE HERO BANNER (Deep Emerald SaaS Curved Header)
                  // ═══════════════════════════════════════════════════════════
                  _buildExecutiveHeroHeader(),

                  // ═══════════════════════════════════════════════════════════
                  // 2. FLOATING PRO COMMAND CENTER (Tri-Mode Duty Controller)
                  // ═══════════════════════════════════════════════════════════
                  Transform.translate(
                    offset: const Offset(0, -28),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      child: _buildTriModeDutyCard(),
                    ),
                  ),

                  // ═══════════════════════════════════════════════════════════
                  // 3. ADMIN KYC / COMPLIANCE STATUS ALERTS
                  // ═══════════════════════════════════════════════════════════
                  Transform.translate(
                    offset: const Offset(0, -14),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      child: _buildComplianceBanners(),
                    ),
                  ),

                  // ═══════════════════════════════════════════════════════════
                  // 4. ACTIVE MISSION RADAR (When Job in Progress)
                  // ═══════════════════════════════════════════════════════════
                  if (_activeBookingId != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 0, 18, 16),
                      child: _buildActiveMissionCard(),
                    ),

                  // ═══════════════════════════════════════════════════════════
                  // 5. FINTECH EARNINGS HUD & WITHDRAW
                  // ═══════════════════════════════════════════════════════════
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    child: _buildEarningsFintechCard(),
                  ),

                  const SizedBox(height: 16),

                  // ═══════════════════════════════════════════════════════════
                  // 6. PRO 4-METRIC PERFORMANCE GRID
                  // ═══════════════════════════════════════════════════════════
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    child: _buildPerformanceGrid(isWide),
                  ),

                  const SizedBox(height: 24),

                  // ═══════════════════════════════════════════════════════════
                  // 7. PRO QUICK TOOLKIT
                  // ═══════════════════════════════════════════════════════════
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    child: _buildProToolkit(),
                  ),

                  const SizedBox(height: 24),

                  // ═══════════════════════════════════════════════════════════
                  // 8. RECENT ACTIVITY & JOB STREAM
                  // ═══════════════════════════════════════════════════════════
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "TODAY'S ACTIVITY",
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.1,
                                color: const Color(0xFF64748B),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Completed Job Receipts',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF0F172A),
                              ),
                            ),
                          ],
                        ),
                        InkWell(
                          onTap: () => context.go('/worker/earnings'),
                          borderRadius: BorderRadius.circular(8),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            child: Row(
                              children: [
                                Text(
                                  'Ledger History',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF059669),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Icon(Icons.arrow_forward_rounded,
                                    size: 14, color: Color(0xFF059669)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    child: _buildRecentJobsStream(),
                  ),

                  const SizedBox(height: 36),
                ],
              ),
            ),

            // Confetti Overlay on ₹1,000 Milestone
            if (_particles.isNotEmpty)
              IgnorePointer(
                child: CustomPaint(
                  painter: _ConfettiPainter(_particles),
                  size: Size.infinite,
                ),
              ),

            if (_showMilestoneBanner) ...[
              Positioned.fill(
                child: RepaintBoundary(
                  child: IgnorePointer(
                    child: AnimatedBuilder(
                      animation: _confettiController,
                      builder: (context, _) {
                        return CustomPaint(
                          painter: _ConfettiPainter(
                              _particles, _confettiController.value),
                        );
                      },
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 24,
                left: 20,
                right: 20,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF059669), Color(0xFF047857), Color(0xFF065F46)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF059669).withValues(alpha: 0.4),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.emoji_events_rounded,
                            color: Color(0xFFFBBF24), size: 24),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '₹1,000 Milestone Unlocked! 🎉',
                              style: GoogleFonts.plusJakartaSans(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                              ),
                            ),
                            Text(
                              'Keep going! High dispatch priority awarded to top performers.',
                              style: GoogleFonts.plusJakartaSans(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                )
                    .animate()
                    .slideY(
                        begin: -1.5,
                        end: 0,
                        duration: 450.ms,
                        curve: Curves.easeOutBack)
                    .shimmer(duration: 1200.ms, color: Colors.white30)
                    .fadeOut(delay: 3500.ms, duration: 400.ms),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SECTION BUILDERS
  // ═══════════════════════════════════════════════════════════════════════════

  /// 1. Executive Emerald Hero Header
  Widget _buildExecutiveHeroHeader() {
    final displayName = _workerName.isNotEmpty ? _workerName : 'Partner';

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0xFF042217),
            Color(0xFF063B28),
            Color(0xFF0A4E36),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 52),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Navigation Bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Pro Partner Identity Pill
              Row(
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _isOnline
                                ? const Color(0xFF34D399)
                                : Colors.white.withValues(alpha: 0.3),
                            width: 2.2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.25),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: _workerAvatarUrl != null && _workerAvatarUrl!.isNotEmpty
                              ? Image.network(
                                  _workerAvatarUrl!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) => _buildAvatarFallback(),
                                )
                              : _buildAvatarFallback(),
                        ),
                      ),
                      Positioned(
                        bottom: -2,
                        right: -2,
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            color: _isOnline ? const Color(0xFF10B981) : const Color(0xFF64748B),
                            shape: BoxShape.circle,
                            border: Border.all(color: const Color(0xFF042217), width: 2),
                          ),
                          child: Icon(
                            _isOnline ? Icons.bolt_rounded : Icons.power_settings_new_rounded,
                            color: Colors.white,
                            size: 10,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            getGreeting(),
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              color: const Color(0xFFA7F3D0),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981).withValues(alpha: 0.25),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: const Color(0xFF34D399), width: 0.8),
                            ),
                            child: Text(
                              'PRO VERIFIED',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF6EE7B7),
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        displayName,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              // Right Action Buttons: Safety SOS & Quick Duty Indicator
              Row(
                children: [
                  IconButton(
                    onPressed: _showSafetySheet,
                    tooltip: 'Safety & SOS Support',
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
                      ),
                      child: const Icon(Icons.security_rounded, color: Colors.white, size: 18),
                    ),
                  ),
                  const SizedBox(width: 4),
                  InkWell(
                    onTap: _cycleState,
                    borderRadius: BorderRadius.circular(24),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: !_isOnline
                            ? Colors.black.withValues(alpha: 0.3)
                            : (_emergencyAvailable
                                ? const Color(0xFFDC2626).withValues(alpha: 0.9)
                                : const Color(0xFF059669).withValues(alpha: 0.9)),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: !_isOnline
                              ? Colors.white.withValues(alpha: 0.2)
                              : (_emergencyAvailable ? const Color(0xFFF87171) : const Color(0xFF6EE7B7)),
                          width: 1.2,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: !_isOnline
                                  ? Colors.grey.shade400
                                  : (_emergencyAvailable ? Colors.white : const Color(0xFFA7F3D0)),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            !_isOnline
                                ? 'Offline'
                                : (_emergencyAvailable ? 'Emergency' : 'Live'),
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 18),

          // Zone Location Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.22),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.location_on_rounded, color: Color(0xFF34D399), size: 14),
                const SizedBox(width: 6),
                Text(
                  'Zone Dispatch: Active (15 km Coverage)',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFFE2E8F0),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 4,
                  height: 4,
                  decoration: const BoxDecoration(color: Color(0xFF64748B), shape: BoxShape.circle),
                ),
                const SizedBox(width: 8),
                Text(
                  'GPS Accurate',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF34D399),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarFallback() {
    return Container(
      color: const Color(0xFF0F3E2C),
      child: Center(
        child: Image.asset(
          'assets/images/app_icon.png',
          width: 28,
          height: 28,
          errorBuilder: (context, error, stackTrace) => const Icon(
            Icons.person_rounded,
            color: Colors.white,
            size: 26,
          ),
        ),
      ),
    );
  }

  /// 2. Tri-Mode Pro Duty Controller Card with Animated Radar
  Widget _buildTriModeDutyCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Status with Radar Graphic
          Row(
            children: [
              // Animated Pulse Radar Ring
              Stack(
                alignment: Alignment.center,
                children: [
                  if (_isOnline)
                    AnimatedBuilder(
                      animation: _radarPulseController,
                      builder: (context, child) {
                        return Container(
                          width: 36 * (1.0 + _radarPulseController.value * 0.4),
                          height: 36 * (1.0 + _radarPulseController.value * 0.4),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: (_emergencyAvailable
                                      ? const Color(0xFFDC2626)
                                      : const Color(0xFF10B981))
                                  .withValues(alpha: (1.0 - _radarPulseController.value).clamp(0.0, 1.0)),
                              width: 1.8,
                            ),
                          ),
                        );
                      },
                    ),
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: !_isOnline
                          ? const Color(0xFFF1F5F9)
                          : (_emergencyAvailable
                              ? const Color(0xFFFEE2E2)
                              : const Color(0xFFECFDF5)),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      !_isOnline
                          ? Icons.power_settings_new_rounded
                          : (_emergencyAvailable
                              ? Icons.warning_amber_rounded
                              : Icons.radar_rounded),
                      size: 20,
                      color: !_isOnline
                          ? const Color(0xFF64748B)
                          : (_emergencyAvailable
                              ? const Color(0xFFDC2626)
                              : const Color(0xFF059669)),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      !_isOnline
                          ? 'Duty is Currently Paused'
                          : (_emergencyAvailable
                              ? 'Emergency Priority Fleet Active'
                              : 'Live Dispatch Radar Scanning'),
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: !_isOnline
                            ? const Color(0xFF334155)
                            : (_emergencyAvailable
                                ? const Color(0xFFDC2626)
                                : const Color(0xFF047857)),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      !_isOnline
                          ? 'Go online to receive nearby repair requests'
                          : (_emergencyAvailable
                              ? 'Auto-dispatching urgent jobs with +hazard allowance'
                              : 'Ready for instant matching within 15 km'),
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Tri-State Segmented Control
          Container(
            height: 48,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _buildTriStateButton(
                    title: 'Offline',
                    icon: Icons.pause_circle_outline_rounded,
                    isSelected: !_isOnline,
                    activeColor: const Color(0xFF334155),
                    onTap: () => _setAvailabilityState(false, false),
                  ),
                ),
                Expanded(
                  child: _buildTriStateButton(
                    title: 'Online',
                    icon: Icons.check_circle_outline_rounded,
                    isSelected: _isOnline && !_emergencyAvailable,
                    activeColor: const Color(0xFF059669),
                    onTap: () => _setAvailabilityState(true, false),
                  ),
                ),
                Expanded(
                  child: _buildTriStateButton(
                    title: 'Emergency',
                    icon: Icons.bolt_rounded,
                    isSelected: _isOnline && _emergencyAvailable,
                    activeColor: const Color(0xFFDC2626),
                    onTap: () => _setAvailabilityState(true, true),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTriStateButton({
    required String title,
    required IconData icon,
    required bool isSelected,
    required Color activeColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 15,
              color: isSelected ? activeColor : const Color(0xFF64748B),
            ),
            const SizedBox(width: 6),
            Text(
              title,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected ? activeColor : const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 3. Real-Time Admin KYC & Compliance Status Banners
  Widget _buildComplianceBanners() {
    if (_isBanned || _strikesCount >= 3) {
      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFFEE2E2),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFEF4444), width: 1.5),
        ),
        child: Row(
          children: [
            const Icon(Icons.block_rounded, color: Color(0xFFDC2626), size: 24),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Partner Account Suspended',
                    style: GoogleFonts.plusJakartaSans(
                      color: const Color(0xFF991B1B),
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Strike limit reached ($_strikesCount/3). Please contact partner operations to appeal.',
                    style: GoogleFonts.plusJakartaSans(
                      color: const Color(0xFFB91C1C),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    if (_approvalStatus == 'rejected') {
      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF1F2),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFFB7185), width: 1.5),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline_rounded, color: Color(0xFFE11D48), size: 24),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Verification Application Rejected',
                    style: GoogleFonts.plusJakartaSans(
                      color: const Color(0xFF9F1239),
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _rejectionReason ?? 'Document criteria not met. Please re-submit selfie and Aadhaar.',
                    style: GoogleFonts.plusJakartaSans(
                      color: const Color(0xFFBE123C),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: () => context.go('/worker/register/step1'),
              child: Text(
                'Re-apply',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFFE11D48),
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (_approvalStatus == 'pending' || !_workerDocExists) {
      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFBEB),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFFBBF24), width: 1.5),
        ),
        child: Row(
          children: [
            const Icon(Icons.hourglass_top_rounded, color: Color(0xFFD97706), size: 24),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'KYC Pending Verification',
                    style: GoogleFonts.plusJakartaSans(
                      color: const Color(0xFF92400E),
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Admin Operations is validating your live selfie & Aadhaar photo. You will go live automatically upon approval.',
                    style: GoogleFonts.plusJakartaSans(
                      color: const Color(0xFFB45309),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // Surge Bonus Banner for Approved Workers
    return AnimatedBuilder(
      animation: PlatformConfigService(),
      builder: (context, _) {
        final cfg = PlatformConfigService();
        if (!cfg.isSurgeActive) return const SizedBox.shrink();
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFECFDF5), Color(0xFFD1FAE5)],
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFF34D399), width: 1.5),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF059669),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.bolt_rounded, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '⚡ Active Fleet Surge Hazard Bonus!',
                      style: GoogleFonts.plusJakartaSans(
                        color: const Color(0xFF065F46),
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Earn +₹${cfg.surgeFee.toInt()} hazard payout on every emergency service dispatch.',
                      style: GoogleFonts.plusJakartaSans(
                        color: const Color(0xFF047857),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// 4. Active Mission Card (When a job is accepted / in progress)
  Widget _buildActiveMissionCard() {
    return GestureDetector(
      onTap: () => context.go('/worker/active?job_id=$_activeBookingId'),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF064E3B), Color(0xFF059669)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF059669).withValues(alpha: 0.35),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.navigation_rounded, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF34D399),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'IN PROGRESS',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            color: const Color(0xFF064E3B),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Live Navigation & OTP',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          color: Colors.white70,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Active Mission in Progress →',
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 16),
          ],
        ),
      ),
    );
  }

  /// 5. Fintech Earnings HUD & Instant UPI Withdraw Card
  Widget _buildEarningsFintechCard() {
    const double dailyGoal = 2500.0;
    final double progress = (_todayEarnings / dailyGoal).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: Label & Instant Withdraw Action
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "TODAY'S NET EARNINGS",
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.0,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        '₹${_todayEarnings.toInt()}',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 34,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFF0F172A),
                          letterSpacing: -1,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFECFDF5),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.trending_up_rounded,
                                color: Color(0xFF059669), size: 14),
                            const SizedBox(width: 4),
                            Text(
                              '+14%',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF059669),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              // Instant Payout Button
              InkWell(
                onTap: () => context.go('/worker/earnings'),
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.account_balance_wallet_rounded,
                          color: Color(0xFF34D399), size: 16),
                      const SizedBox(width: 8),
                      Text(
                        'Wallet & UPI',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          // Daily Target Progress Indicator
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Daily Milestone Target: ₹${dailyGoal.toInt()}',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF475569),
                    ),
                  ),
                  Text(
                    '${(progress * 100).toInt()}% Achieved',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF059669),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 7,
                  backgroundColor: const Color(0xFFE2E8F0),
                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF059669)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 6. Pro 4-Metric Performance Grid
  Widget _buildPerformanceGrid(bool isWide) {
    return Row(
      children: [
        Expanded(
          child: _buildMetricCard(
            title: "Today's Jobs",
            value: '$_todayJobCount',
            subtitle: 'Completed',
            icon: Icons.checklist_rounded,
            iconColor: const Color(0xFF059669),
            bgColor: const Color(0xFFECFDF5),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildMetricCard(
            title: 'Week Volume',
            value: '$_weekJobCount',
            subtitle: 'Dispatches',
            icon: Icons.calendar_today_rounded,
            iconColor: const Color(0xFF2563EB),
            bgColor: const Color(0xFFEFF6FF),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildMetricCard(
            title: 'Partner Rating',
            value: '4.9★',
            subtitle: 'Top 5% Tier',
            icon: Icons.star_rounded,
            iconColor: const Color(0xFFD97706),
            bgColor: const Color(0xFFFFFBEB),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildMetricCard(
            title: 'Accept Rate',
            value: '98%',
            subtitle: 'Super Responsive',
            icon: Icons.electric_bolt_rounded,
            iconColor: const Color(0xFF7C3AED),
            bgColor: const Color(0xFFF5F3FF),
          ),
        ),
      ],
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 16),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }

  /// 7. Pro Partner Quick Toolkit
  Widget _buildProToolkit() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'PRO PARTNER TOOLKIT',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.1,
            color: const Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildToolTile(
                title: 'My Services & Rates',
                subtitle: '${_workerSkills.length} Verified Skills',
                icon: Icons.handyman_rounded,
                iconColor: const Color(0xFF059669),
                onTap: () => context.go('/worker/profile'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildToolTile(
                title: 'Bank & UPI Ledger',
                subtitle: 'Direct Payouts',
                icon: Icons.account_balance_rounded,
                iconColor: const Color(0xFF2563EB),
                onTap: () => context.go('/worker/earnings'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildToolTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 8. Recent Completed Jobs Stream
  Widget _buildRecentJobsStream() {
    if (_recentLoading) {
      return const ShimmerList(itemCount: 3);
    }

    if (_recentBookings.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFECFDF5),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.work_outline_rounded,
                  color: Color(0xFF059669), size: 30),
            ),
            const SizedBox(height: 14),
            Text(
              'No Jobs Completed Today',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Stay online to receive high-paying customer dispatch requests in your area.',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                color: const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: _recentBookings.map((b) {
        final service = b['service'] as String? ?? 'Service';
        final userName = b['userName'] as String? ?? 'Customer';
        final amount = (b['amount'] as num? ?? 0).toStringAsFixed(0);
        final status = b['status'] as String? ?? 'completed';

        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _buildRecentJobTicket(
            service: service,
            customerName: userName,
            amount: '₹$amount',
            status: status,
          ),
        );
      }).toList(),
    );
  }

  Widget _buildRecentJobTicket({
    required String service,
    required String customerName,
    required String amount,
    required String status,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFECFDF5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.check_circle_rounded,
                color: Color(0xFF059669), size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  service,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Customer: $customerName • Verified Payout',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    color: const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFECFDF5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFA7F3D0)),
            ),
            child: Text(
              amount,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF059669),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // BACKEND REALTIME JOB DISPATCH LISTENER
  // ═══════════════════════════════════════════════════════════════════════════

  void _startJobsListener() {
    if (_jobsChannel != null) return;

    print('[WORKER_HOME] Starting real-time jobs listener...');
    _jobsChannel = SupabaseConfig.client
        .channel('public:jobs_searching')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'jobs',
          callback: (payload) {
            if (!mounted || !_isOnline) return;
            print('[WORKER_HOME] Real-time job event: ${payload.eventType}');

            final data = payload.newRecord;
            if (data.isEmpty) return;

            final status = data['status'] as String? ?? '';
            if (status == 'searching') {
              _checkAndShowJobOffer(data);
            }
          },
        )
        .subscribe();

    _checkExistingSearchingJobs();
  }

  void _stopJobsListener() {
    if (_jobsChannel != null) {
      print('[WORKER_HOME] Stopping real-time jobs listener...');
      SupabaseConfig.client.removeChannel(_jobsChannel!);
      _jobsChannel = null;
    }
  }

  Future<void> _checkExistingSearchingJobs() async {
    if (!mounted || !_isOnline) return;
    try {
      final response = await SupabaseConfig.client
          .from('jobs')
          .select()
          .eq('status', 'searching');
      for (var job in response) {
        _checkAndShowJobOffer(job);
      }
    } catch (e) {
      print('[WORKER_HOME] Error checking existing searching jobs: $e');
    }
  }

  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const p = 0.017453292519943295;
    final c = cos;
    final a = 0.5 -
        c((lat2 - lat1) * p) / 2 +
        c(lat1 * p) * c(lat2 * p) * (1 - c((lon2 - lon1) * p)) / 2;
    return 12742 * asin(sqrt(a));
  }

  void _checkAndShowJobOffer(Map<String, dynamic> data) {
    final jobId = data['id'] as String? ?? '';
    if (jobId.isEmpty) return;

    if (_activeBookingId != null) {
      print('[WORKER_HOME] Skip job $jobId: worker is busy with booking $_activeBookingId');
      return;
    }

    if (JobDispatchService().ignoredJobIds.contains(jobId)) {
      print('[WORKER_HOME] Skip job $jobId: already ignored/rejected');
      return;
    }

    final skillRequired =
        (data['skill_required'] as String? ?? '').toLowerCase().replaceAll(' ', '_');
    final matchesSkill = _workerSkills.contains(skillRequired);
    if (!matchesSkill) {
      print('[WORKER_HOME] Skip job $jobId: skill mismatch. Required: $skillRequired, Worker skills: $_workerSkills');
      return;
    }

    double distance = 0.0;
    final workerPos = LocationService().currentPosition;

    final jobLocation = data['location'];
    double? jobLat;
    double? jobLng;
    if (jobLocation is String) {
      if (jobLocation.contains('POINT')) {
        final match =
            RegExp(r'POINT\s*\(\s*([-\d.]+)\s+([-\d.]+)\s*\)').firstMatch(jobLocation);
        if (match != null && match.groupCount == 2) {
          jobLng = double.tryParse(match.group(1)!);
          jobLat = double.tryParse(match.group(2)!);
        }
      }
    } else if (jobLocation is Map) {
      final coords = jobLocation['coordinates'];
      if (coords is List && coords.length >= 2) {
        jobLng = double.tryParse(coords[0].toString());
        jobLat = double.tryParse(coords[1].toString());
      }
    }

    if (workerPos != null && jobLat != null && jobLng != null) {
      distance = _calculateDistance(
          workerPos.latitude, workerPos.longitude, jobLat, jobLng);
    }

    print('[WORKER_HOME] MATCH FOUND! Redirecting to IncomingRequestScreen for job $jobId');
    final skillEncoded = Uri.encodeComponent(data['skill_required'] ?? 'Service');
    final descEncoded = Uri.encodeComponent(data['description'] ?? '');
    final budget = data['amount'] ?? 150.0;
    final jobType = data['job_type'] ?? 'normal';
    final surcharge = data['surcharge_amount'] ?? 0.0;

    context.go(
      '/worker/incoming'
      '?job_id=$jobId'
      '&skill=$skillEncoded'
      '&budget=$budget'
      '&distance=${distance.toStringAsFixed(1)}'
      '&description=$descEncoded'
      '&timeout=300'
      '&job_type=$jobType'
      '&surcharge=$surcharge',
    );
  }
}

class _ConfettiParticle {
  double x, y;
  double vx, vy;
  double size;
  Color color;
  double rotation;
  double rotationSpeed;

  _ConfettiParticle({
    required this.x,
    required this.y,
    required this.vy,
    required this.vx,
    required this.size,
    required this.color,
    required this.rotation,
    required this.rotationSpeed,
  });
}

class _ConfettiPainter extends CustomPainter {
  final List<_ConfettiParticle> particles;
  final double progress;
  _ConfettiPainter(this.particles, [this.progress = 0.0]);

  @override
  void paint(Canvas canvas, Size size) {
    if (particles.isEmpty) return;
    final paint = Paint()..style = PaintingStyle.fill;
    final frames = progress * 240.0;
    for (var p in particles) {
      final currentX = p.x + p.vx * frames;
      final currentY = p.y + (p.vy * frames) + (0.5 * 0.15 * frames * frames);
      final currentRotation = p.rotation + p.rotationSpeed * frames;

      paint.color =
          p.color.withValues(alpha: (1.0 - progress * 0.5).clamp(0.0, 1.0));
      canvas.save();
      canvas.translate(currentX, currentY);
      canvas.rotate(currentRotation);
      canvas.drawRect(
        Rect.fromCenter(
            center: Offset.zero, width: p.size, height: p.size * 0.6),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
