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
import 'package:jugaad_mvp/core/services/job_dispatch_service.dart';
import 'package:jugaad_mvp/core/config/supabase_config.dart';
import 'package:jugaad_mvp/core/services/location_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../widgets/worker_dashboard_sheets.dart';

class WorkerHomeScreen extends StatefulWidget {
  const WorkerHomeScreen({super.key});

  @override
  State<WorkerHomeScreen> createState() => _WorkerHomeScreenState();
}

class _WorkerHomeScreenState extends State<WorkerHomeScreen>
    with TickerProviderStateMixin {
  String _workerName = 'kush';
  String? _workerAvatarUrl;
  bool _isOnline = true;
  bool _emergencyAvailable = true;
  bool _workerDocExists = false;
  String _approvalStatus = 'rejected'; // Shows rejection banner as in mockup
  String? _rejectionReason = 'Document criteria not met. Please re-submit selfie and Aadhaar.';
  bool _isBanned = false;
  int _strikesCount = 0;
  int _serviceRadius = 15;
  String _operatingCity = 'Mysuru';

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

  List<String> _workerSkills = ['electrician'];
  RealtimeChannel? _jobsChannel;

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
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

      final appr = (data['approval_status'] ?? data['status'] ?? 'rejected')
          .toString()
          .toLowerCase();
      final banned = (data['is_banned'] as bool? ?? false) || appr == 'suspended';
      final strikes = (data['strike_count'] as num? ?? data['strikes'] as num? ?? 0).toInt();
      final reason = data['rejection_reason'] as String?;
      final avatar = data['avatar_url'] as String? ?? data['photo_url'] as String?;
      final fetchedName = data['name'] as String? ?? data['full_name'] as String?;

      setState(() {
        _workerDocExists = true;
        if (fetchedName != null && fetchedName.isNotEmpty) {
          _workerName = fetchedName;
        }
        _workerAvatarUrl = avatar;
        _approvalStatus = appr;
        _isBanned = banned;
        _strikesCount = strikes;
        if (reason != null && reason.isNotEmpty) {
          _rejectionReason = reason;
        }
        _isOnline = (banned) ? false : (data['is_available'] as bool? ?? true);
        _emergencyAvailable = (banned) ? false : (data['emergency_available'] as bool? ?? true);

        final skillsData = data['skills'];
        if (skillsData is List && skillsData.isNotEmpty) {
          _workerSkills = List<String>.from(
              skillsData.map((e) => e.toString().toLowerCase().replaceAll(' ', '_')));
        }
      });

      if (_isOnline) {
        _startJobsListener();
      } else {
        _stopJobsListener();
      }
    }, onError: (e) {
      print('[WORKER_HOME] workerStream error: $e');
    });

    _activeBookingSub = _fs
        .workerBookingsStream(uid, statuses: ['accepted', 'in_progress'])
        .listen((rows) {
      if (!mounted) return;
      setState(() {
        _activeBookingId =
            rows.isNotEmpty ? rows.first['job_id']?.toString() : null;
      });
    }, onError: (e) {
      print('[WORKER_HOME] activeBookingStream error: $e');
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
    }, onError: (e) {
      print('[WORKER_HOME] recentBookingsStream error: $e');
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
    if (isAvailable && (_isBanned || _strikesCount >= 3)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Account Suspended by Operations ($_strikesCount/3 strikes). Please contact partner support.",
            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
          ),
          backgroundColor: const Color(0xFFDC2626),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    if (!_workerDocExists) {
      print('[WORKER_HOME] Setting availability before doc exists');
    }

    final uid = AuthService().currentUser?.uid;
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

    if (uid != null) {
      try {
        await _fs.setWorkerAvailabilityState(uid,
            isAvailable: isAvailable, emergencyAvailable: emergencyAvailable);
        if (isAvailable) {
          FCMTokenManager.refreshAndUploadToken();
        }
      } catch (e) {
        print('[WORKER_HOME] setWorkerAvailabilityState error: $e');
      }
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
        msg = "You are Live 🟢 Receiving standard job requests in Mysuru";
        bgColor = const Color(0xFF059669);
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            msg,
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
          backgroundColor: bgColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _showDutyStatusPicker() {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
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
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Select Dispatch Duty Status',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Change your availability on the JUGAAD PRO dispatch network',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 20),
            _buildDutyOption(
              icon: Icons.check_circle_rounded,
              color: const Color(0xFF059669),
              title: '🟢 Online (Standard Dispatch)',
              subtitle: 'Receive all regular verified customer requests in your area.',
              isSelected: _isOnline && !_emergencyAvailable,
              onTap: () {
                Navigator.pop(ctx);
                _setAvailabilityState(true, false);
              },
            ),
            const SizedBox(height: 10),
            _buildDutyOption(
              icon: Icons.bolt_rounded,
              color: const Color(0xFFEA580C),
              title: '⚡ Online + Emergency Priority Fleet',
              subtitle: 'Receive high-hazard urgent bookings with priority surge rates.',
              isSelected: _isOnline && _emergencyAvailable,
              onTap: () {
                Navigator.pop(ctx);
                _setAvailabilityState(true, true);
              },
            ),
            const SizedBox(height: 10),
            _buildDutyOption(
              icon: Icons.pause_circle_filled_rounded,
              color: const Color(0xFF64748B),
              title: '⚫ Pause Duty (Go Offline)',
              subtitle: 'Stop receiving requests temporarily while resting or busy.',
              isSelected: !_isOnline,
              onTap: () {
                Navigator.pop(ctx);
                _setAvailabilityState(false, false);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDutyOption({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.08) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? color : const Color(0xFFE2E8F0),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11.5,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.done_rounded, color: color, size: 20),
          ],
        ),
      ),
    );
  }

  void _triggerMilestoneBurst() {
    HapticFeedback.heavyImpact();
    Future.delayed(const Duration(milliseconds: 150),
        () => HapticFeedback.heavyImpact());

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
      return 'Good morning,';
    } else if (hour < 17) {
      return 'Good afternoon,';
    } else {
      return 'Good evening,';
    }
  }

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isDesktop = screenWidth >= 1024;
    final bool isTablet = screenWidth >= 768 && screenWidth < 1024;
    final bool isMobile = screenWidth < 768;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: isDesktop ? 28 : (isTablet ? 20 : 14),
                vertical: isMobile ? 14 : 20,
              ),
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Mobile Header when on phones (shell top bar handles desktop)
                  if (isMobile) ...[
                    _buildMobileHeader(),
                    const SizedBox(height: 14),
                  ],

                  // Active In-Progress Mission Banner (if worker is busy)
                  if (_activeBookingId != null) ...[
                    _buildActiveMissionBanner(),
                    const SizedBox(height: 14),
                  ],

                  // ═══════════════════════════════════════════════════════════
                  // ROW 1: PROFILE & ONLINE STATUS CARD + EMERGENCY JOBS TOGGLE
                  // ═══════════════════════════════════════════════════════════
                  if (screenWidth >= 900)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 66,
                          child: _buildProfileStatusCard(isMobile: false),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          flex: 34,
                          child: _buildEmergencyJobsCard(),
                        ),
                      ],
                    )
                  else ...[
                    _buildProfileStatusCard(isMobile: isMobile),
                    const SizedBox(height: 12),
                    _buildEmergencyJobsCard(),
                  ],

                  const SizedBox(height: 14),

                  // ═══════════════════════════════════════════════════════════
                  // ROW 2: 4 PERFORMANCE METRIC CARDS
                  // ═══════════════════════════════════════════════════════════
                  _buildFourMetricCards(screenWidth),

                  // ═══════════════════════════════════════════════════════════
                  // ROW 2.5: MOBILE FEATURES LAUNCHPAD (Relocated Feature Icons)
                  // ═══════════════════════════════════════════════════════════
                  if (isMobile) ...[
                    const SizedBox(height: 14),
                    _buildMobileFeatureLaunchpad(),
                  ],

                  const SizedBox(height: 14),

                  // ═══════════════════════════════════════════════════════════
                  // ROW 3: VERIFICATION APPLICATION REJECTED BANNER
                  // ═══════════════════════════════════════════════════════════
                  _buildVerificationBanner(),

                  const SizedBox(height: 14),

                  // ═══════════════════════════════════════════════════════════
                  // ROW 4: TODAY'S EARNINGS + YOUR SERVICE AREA RADAR
                  // ═══════════════════════════════════════════════════════════
                  if (screenWidth >= 900)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 58,
                          child: _buildTodayEarningsCard(isMobile: false),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          flex: 42,
                          child: _buildServiceAreaCard(),
                        ),
                      ],
                    )
                  else ...[
                    _buildTodayEarningsCard(isMobile: isMobile),
                    const SizedBox(height: 12),
                    _buildServiceAreaCard(),
                  ],

                  const SizedBox(height: 18),

                  // ═══════════════════════════════════════════════════════════
                  // ROW 5: 3 COLUMNS (Recent Job Activity | Quick Actions | Tips)
                  // ═══════════════════════════════════════════════════════════
                  if (screenWidth >= 1060)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 38,
                          child: _buildRecentJobActivityCard(),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          flex: 31,
                          child: _buildQuickActionsCard(),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          flex: 31,
                          child: _buildTipsCard(),
                        ),
                      ],
                    )
                  else if (isTablet) ...[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 55,
                          child: _buildRecentJobActivityCard(),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          flex: 45,
                          child: _buildQuickActionsCard(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildTipsCard(),
                  ] else ...[
                    _buildRecentJobActivityCard(),
                    const SizedBox(height: 14),
                    _buildTipsCard(),
                  ],

                  const SizedBox(height: 36),
                ],
              ),
            ),

            // Confetti Overlay
            if (_particles.isNotEmpty)
              IgnorePointer(
                child: CustomPaint(
                  painter: _ConfettiPainter(_particles),
                  size: Size.infinite,
                ),
              ),

            // ₹1000 Milestone Banner
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
  // COMPONENT BUILDERS (Matching Mockup Pixels & Functions)
  // ═══════════════════════════════════════════════════════════════════════════

  /// Mobile Header
  Widget _buildMobileHeader() {
    final initialLetter = _workerName.isNotEmpty ? _workerName[0].toUpperCase() : 'K';

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF059669), Color(0xFF10B981)],
                ),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Icon(Icons.lightbulb_rounded, color: Colors.white, size: 18),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'JUGAAD PRO',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w900,
                fontSize: 16,
                color: const Color(0xFF0F172A),
              ),
            ),
          ],
        ),
        Row(
          children: [
            // City Pill
            InkWell(
              onTap: () => WorkerDashboardSheets.showCitySelector(
                context,
                currentCity: _operatingCity,
                onCitySelected: (city) => setState(() => _operatingCity = city),
              ),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.location_on_rounded, color: Color(0xFF0F172A), size: 14),
                    const SizedBox(width: 4),
                    Text(
                      _operatingCity,
                      style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                    const Icon(Icons.keyboard_arrow_down_rounded, size: 14, color: Color(0xFF64748B)),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: () => WorkerDashboardSheets.showNotifications(context),
              icon: Stack(
                children: [
                  const Icon(Icons.notifications_none_rounded, color: Color(0xFF0F172A), size: 22),
                  Positioned(
                    top: 2,
                    right: 2,
                    child: Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(color: Color(0xFFEF4444), shape: BoxShape.circle),
                    ),
                  ),
                ],
              ),
            ),
            InkWell(
              onTap: () => context.go('/worker/profile'),
              child: Container(
                width: 32,
                height: 32,
                decoration: const BoxDecoration(
                  color: Color(0xFF86EFAC),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    initialLetter,
                    style: GoogleFonts.plusJakartaSans(
                      color: const Color(0xFF14532D),
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Active Booking in progress alert
  Widget _buildActiveMissionBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF3C7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: Color(0xFFF59E0B),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.navigation_rounded, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Active Job in Progress',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF92400E),
                  ),
                ),
                Text(
                  'Customer is waiting. View dispatch directions & job details.',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    color: const Color(0xFFB45309),
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () => context.go('/worker/active?job_id=$_activeBookingId'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD97706),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            child: Text(
              'Resume Job',
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 12.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 1. Profile Status Card (Mint Green, matching mockup)
  Widget _buildProfileStatusCard({required bool isMobile}) {
    final initialLetter = _workerName.isNotEmpty ? _workerName[0].toUpperCase() : 'K';
    final primarySkill = _workerSkills.isNotEmpty
        ? (_workerSkills.first[0].toUpperCase() + _workerSkills.first.substring(1).replaceAll('_', ' '))
        : 'Electrician';

    if (isMobile) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFF0FDF4),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFDCFCE7), width: 1.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Avatar + Name + PRO VERIFIED + Shield
            Row(
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    ClipOval(
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: const BoxDecoration(
                          color: Color(0xFF86EFAC),
                          shape: BoxShape.circle,
                        ),
                        child: (_workerAvatarUrl != null && _workerAvatarUrl!.isNotEmpty)
                            ? Image.network(
                                _workerAvatarUrl!,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) => Center(
                                  child: Text(
                                    initialLetter,
                                    style: GoogleFonts.plusJakartaSans(
                                      color: const Color(0xFF14532D),
                                      fontWeight: FontWeight.w900,
                                      fontSize: 20,
                                    ),
                                  ),
                                ),
                              )
                            : Center(
                                child: Text(
                                  initialLetter,
                                  style: GoogleFonts.plusJakartaSans(
                                    color: const Color(0xFF14532D),
                                    fontWeight: FontWeight.w900,
                                    fontSize: 20,
                                  ),
                                ),
                              ),
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        width: 13,
                        height: 13,
                        decoration: BoxDecoration(
                          color: _isOnline ? const Color(0xFF10B981) : const Color(0xFF94A3B8),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
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
                        getGreeting(),
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          color: const Color(0xFF475569),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              _workerName,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 19,
                                fontWeight: FontWeight.w900,
                                color: const Color(0xFF0F172A),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFDCFCE7),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: const Color(0xFF86EFAC)),
                            ),
                            child: Text(
                              'PRO VERIFIED',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF15803D),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCFCE7),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.shield_outlined, color: Color(0xFF059669), size: 18),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Chips Row
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                _buildInfoChip(Icons.handyman_rounded, primarySkill),
                _buildInfoChip(Icons.location_on_rounded, '$_operatingCity ($_serviceRadius km)'),
                _buildInfoChip(Icons.gps_fixed_rounded, 'GPS Live'),
              ],
            ),

            const SizedBox(height: 14),

            // Full-Width Mobile Duty Action Bar (ergonomic thumb touch-target)
            InkWell(
              onTap: _showDutyStatusPicker,
              borderRadius: BorderRadius.circular(14),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                decoration: BoxDecoration(
                  color: _isOnline ? const Color(0xFF059669) : const Color(0xFF334155),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: (_isOnline ? const Color(0xFF059669) : const Color(0xFF334155))
                          .withValues(alpha: 0.22),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: _isOnline ? const Color(0xFF86EFAC) : const Color(0xFF94A3B8),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _isOnline ? 'Online · Receiving Requests' : 'Duty Paused · Offline',
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Text(
                          'Change',
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white70,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 2),
                        const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white, size: 16),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFDCFCE7), width: 1.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Avatar with Online Pulse Dot
          Stack(
            clipBehavior: Clip.none,
            children: [
              ClipOval(
                child: Container(
                  width: 54,
                  height: 54,
                  decoration: const BoxDecoration(
                    color: Color(0xFF86EFAC),
                    shape: BoxShape.circle,
                  ),
                  child: (_workerAvatarUrl != null && _workerAvatarUrl!.isNotEmpty)
                      ? Image.network(
                          _workerAvatarUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Center(
                            child: Text(
                              initialLetter,
                              style: GoogleFonts.plusJakartaSans(
                                color: const Color(0xFF14532D),
                                fontWeight: FontWeight.w900,
                                fontSize: 22,
                              ),
                            ),
                          ),
                        )
                      : Center(
                          child: Text(
                            initialLetter,
                            style: GoogleFonts.plusJakartaSans(
                              color: const Color(0xFF14532D),
                              fontWeight: FontWeight.w900,
                              fontSize: 22,
                            ),
                          ),
                        ),
                ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: _isOnline ? const Color(0xFF10B981) : const Color(0xFF94A3B8),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2.2),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(width: 16),

          // Name, Greeting, Verified Badge & Metadata
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  getGreeting(),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    color: const Color(0xFF475569),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        _workerName,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFF0F172A),
                          letterSpacing: -0.3,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDCFCE7),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFF86EFAC)),
                      ),
                      child: Text(
                        'PRO VERIFIED',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF15803D),
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                // Metadata chips row
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.handyman_rounded, size: 14, color: Color(0xFF059669)),
                        const SizedBox(width: 4),
                        Text(
                          primarySkill,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF334155),
                          ),
                        ),
                      ],
                    ),
                    const Text('•', style: TextStyle(color: Color(0xFF94A3B8))),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.star_rounded, size: 14, color: Color(0xFFF59E0B)),
                        const SizedBox(width: 4),
                        Text(
                          '${_workerSkills.length} Verified Skill',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF334155),
                          ),
                        ),
                      ],
                    ),
                    const Text('•', style: TextStyle(color: Color(0xFF94A3B8))),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.location_on_rounded, size: 14, color: Color(0xFF059669)),
                        const SizedBox(width: 4),
                        Text(
                          'Active in $_operatingCity ($_serviceRadius km)',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF334155),
                          ),
                        ),
                      ],
                    ),
                    const Text('•', style: TextStyle(color: Color(0xFF94A3B8))),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.gps_fixed_rounded, size: 14, color: Color(0xFF059669)),
                        const SizedBox(width: 4),
                        Text(
                          'GPS Accurate',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF334155),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(width: 14),

          // Right: Online / Status Dropdown Pill
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDCFCE7),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.shield_outlined, color: Color(0xFF059669), size: 18),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: _showDutyStatusPicker,
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(
                        color: _isOnline ? const Color(0xFF059669) : const Color(0xFF334155),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: (_isOnline ? const Color(0xFF059669) : const Color(0xFF334155))
                                .withValues(alpha: 0.25),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: _isOnline ? const Color(0xFF86EFAC) : const Color(0xFF94A3B8),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 7),
                          Text(
                            _isOnline ? 'Online' : 'Offline',
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white, size: 16),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                _isOnline ? '● You are receiving job requests' : '○ Duty paused. Tap to go online',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: _isOnline ? const Color(0xFF059669) : const Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFDCFCE7)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: const Color(0xFF059669)),
          const SizedBox(width: 4),
          Text(
            text,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF334155),
            ),
          ),
        ],
      ),
    );
  }

  /// 2. Emergency Jobs Card (matching mockup)
  Widget _buildEmergencyJobsCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBF5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFFED7AA), width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF7ED),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFFFEDD5)),
            ),
            child: const Icon(Icons.bolt_rounded, color: Color(0xFFEA580C), size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Emergency Jobs',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Receive urgent requests within your area',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11.5,
                    color: const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: _emergencyAvailable,
            activeThumbColor: const Color(0xFF059669),
            activeTrackColor: const Color(0xFFBBF7D0),
            inactiveThumbColor: Colors.white,
            inactiveTrackColor: const Color(0xFFCBD5E1),
            onChanged: (val) {
              _setAvailabilityState(_isOnline, val);
            },
          ),
        ],
      ),
    );
  }

  /// 3. Four Metric Cards Row
  Widget _buildFourMetricCards(double screenWidth) {
    final isMobile = screenWidth < 768;

    final cards = [
      _buildSingleMetricCard(
        icon: Icons.work_outline_rounded,
        iconBg: const Color(0xFFF0FDF4),
        iconColor: const Color(0xFF059669),
        value: '$_todayJobCount',
        title: "Today's Jobs",
        subtitle: _todayJobCount == 0 ? 'No jobs yet' : '$_todayJobCount done',
        isMobile: isMobile,
      ),
      _buildSingleMetricCard(
        icon: Icons.calendar_today_rounded,
        iconBg: const Color(0xFFEFF6FF),
        iconColor: const Color(0xFF2563EB),
        value: '$_weekJobCount',
        title: 'This Week',
        subtitle: 'Job volume',
        isMobile: isMobile,
      ),
      _buildSingleMetricCard(
        icon: Icons.star_rounded,
        iconBg: const Color(0xFFFFFBEB),
        iconColor: const Color(0xFFF59E0B),
        value: '4.9 ★',
        title: 'Rating',
        subtitle: 'Top rated',
        isMobile: isMobile,
      ),
      _buildSingleMetricCard(
        icon: Icons.bolt_rounded,
        iconBg: const Color(0xFFFAF5FF),
        iconColor: const Color(0xFF9333EA),
        value: '98% ⓘ',
        title: 'Accept Rate',
        subtitle: 'High speed',
        isMobile: isMobile,
      ),
    ];

    if (isMobile) {
      return Column(
        children: [
          Row(
            children: [
              Expanded(child: cards[0]),
              const SizedBox(width: 10),
              Expanded(child: cards[1]),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: cards[2]),
              const SizedBox(width: 10),
              Expanded(child: cards[3]),
            ],
          ),
        ],
      );
    }

    return Row(
      children: [
        Expanded(child: cards[0]),
        const SizedBox(width: 14),
        Expanded(child: cards[1]),
        const SizedBox(width: 14),
        Expanded(child: cards[2]),
        const SizedBox(width: 14),
        Expanded(child: cards[3]),
      ],
    );
  }

  Widget _buildSingleMetricCard({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String value,
    required String title,
    required String subtitle,
    bool isMobile = false,
  }) {
    if (isMobile) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x040F172A),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 18),
            ),
            const SizedBox(height: 10),
            Text(
              value,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 19,
                fontWeight: FontWeight.w900,
                color: const Color(0xFF0F172A),
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              title,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1E293B),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 1),
            Text(
              subtitle,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 10.5,
                color: const Color(0xFF64748B),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x040F172A),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF0F172A),
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  title,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  subtitle,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    color: const Color(0xFF64748B),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 4. Verification Alert Banner (Red, matching mockup)
  Widget _buildVerificationBanner() {
    if (_approvalStatus == 'approved') {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFECACA), width: 1.2),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: Color(0xFFDC2626),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.priority_high_rounded, color: Colors.white, size: 16),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Verification Application Rejected',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFFDC2626),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _rejectionReason ?? 'Document criteria not met. Please re-submit selfie and Aadhaar.',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    color: const Color(0xFFEF4444),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            onPressed: () {
              HapticFeedback.lightImpact();
              context.push('/worker/register/step2');
            },
            icon: const Icon(Icons.description_outlined, color: Colors.white, size: 16),
            label: Text(
              'Re-apply',
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
          ),
        ],
      ),
    );
  }

  /// 5. Today's Earnings Card (Mint green, milestone target, progress)
  Widget _buildTodayEarningsCard({bool isMobile = false}) {
    const double target = 2500.0;
    final double pct = (_todayEarnings / target).clamp(0.0, 1.0);
    final int pctInt = (pct * 100).toInt();

    return Container(
      padding: EdgeInsets.all(isMobile ? 16 : 22),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFDCFCE7), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDCFCE7),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.account_balance_wallet_rounded,
                        color: Color(0xFF059669), size: 22),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Today's Earnings",
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: isMobile ? 12 : 13,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF475569),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(
                            '₹${_todayEarnings.toInt()}',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: isMobile ? 24 : 30,
                              fontWeight: FontWeight.w900,
                              color: const Color(0xFF0F172A),
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFDCFCE7),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.trending_up_rounded, color: Color(0xFF15803D), size: 14),
                                const SizedBox(width: 3),
                                Text(
                                  '+14%',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFF15803D),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
              ElevatedButton(
                onPressed: () => context.go('/worker/earnings'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF064E3B),
                  padding: EdgeInsets.symmetric(horizontal: isMobile ? 10 : 14, vertical: isMobile ? 8 : 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      isMobile ? 'Wallet' : 'Wallet & UPI',
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 10),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Milestone target bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Daily Milestone Target: ₹2500',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF64748B),
                ),
              ),
              Text(
                '$pctInt% Achieved',
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
              value: pct,
              minHeight: 8,
              backgroundColor: const Color(0xFFE2E8F0),
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF059669)),
            ),
          ),
        ],
      ),
    );
  }

  /// 6. Your Service Area Card (with Radar circles)
  Widget _buildServiceAreaCard() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x040F172A),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF7ED),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.location_on_rounded, color: Color(0xFFEA580C), size: 18),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Your Service Area',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '📍 $_serviceRadius km radius',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF475569),
                  ),
                ),
                const SizedBox(height: 14),
                OutlinedButton(
                  onPressed: () => WorkerDashboardSheets.showServiceArea(
                    context,
                    currentRadius: _serviceRadius,
                    onRadiusSelected: (r) => setState(() => _serviceRadius = r),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Manage Area',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF334155),
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.arrow_forward_rounded, color: Color(0xFF334155), size: 14),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Radar Concentric Graphic
          AnimatedBuilder(
            animation: _radarPulseController,
            builder: (context, _) {
              return Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDF4),
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFFBBF7D0).withValues(alpha: 0.6)),
                    ),
                  ),
                  Container(
                    width: 66 + (_radarPulseController.value * 12),
                    height: 66 + (_radarPulseController.value * 12),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFF86EFAC).withValues(
                          alpha: (1.0 - _radarPulseController.value).clamp(0.1, 0.8),
                        ),
                        width: 1.5,
                      ),
                    ),
                  ),
                  Container(
                    width: 46,
                    height: 46,
                    decoration: const BoxDecoration(
                      color: Color(0xFFDCFCE7),
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: Icon(Icons.location_on_rounded, color: Color(0xFF059669), size: 22),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  /// 7. Recent Job Activity Card (Empty state or recent receipts)
  Widget _buildRecentJobActivityCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x040F172A),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.access_time_rounded, color: Color(0xFF0F172A), size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'Recent Job Activity',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              InkWell(
                onTap: () => context.go('/worker/earnings'),
                child: Row(
                  children: [
                    Text(
                      'View All',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF059669),
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.arrow_forward_rounded, color: Color(0xFF059669), size: 14),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 28),

          if (_recentLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: CircularProgressIndicator(color: Color(0xFF059669)),
              ),
            )
          else if (_recentBookings.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Suitcase Icon with Spark lines
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: 58,
                          height: 58,
                          decoration: const BoxDecoration(
                            color: Color(0xFFF0FDF4),
                            shape: BoxShape.circle,
                          ),
                          child: const Center(
                            child: Icon(Icons.business_center_outlined,
                                color: Color(0xFF059669), size: 28),
                          ),
                        ),
                      ],
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
                    const SizedBox(height: 4),
                    Text(
                      'Stay online to receive high-paying customer requests in your area.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color: const Color(0xFF64748B),
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _recentBookings.length,
              separatorBuilder: (context, index) => const Divider(height: 20),
              itemBuilder: (ctx, i) {
                final b = _recentBookings[i];
                final skill = b['skill_required'] ?? 'Service';
                final amount = b['amount'] ?? 150;
                final custName = b['customer_name'] ?? 'Customer';

                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0FDF4),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.check_circle_rounded,
                              color: Color(0xFF059669), size: 18),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              skill,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF0F172A),
                              ),
                            ),
                            Text(
                              custName,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11.5,
                                color: const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Text(
                      '₹$amount',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF059669),
                      ),
                    ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  /// 7.5 Mobile Feature Launchpad (Senior UX Relocation: Key utilities in direct thumb reach)
  Widget _buildMobileFeatureLaunchpad() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x040F172A),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.bolt_rounded, color: Color(0xFFEA580C), size: 18),
                  const SizedBox(width: 6),
                  Text(
                    'Quick Feature Hub',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '4 Tools',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF64748B),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _buildMobileFeatureTile(
                  icon: Icons.handyman_rounded,
                  label: 'Services',
                  sublabel: '${_workerSkills.length} active',
                  iconColor: const Color(0xFF059669),
                  iconBg: const Color(0xFFF0FDF4),
                  onTap: () => WorkerDashboardSheets.showMyServices(
                    context,
                    currentSkills: _workerSkills,
                    onSkillsUpdated: (s) => setState(() => _workerSkills = s),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMobileFeatureTile(
                  icon: Icons.account_balance_wallet_rounded,
                  label: 'UPI Ledger',
                  sublabel: 'Payouts',
                  iconColor: const Color(0xFF2563EB),
                  iconBg: const Color(0xFFEFF6FF),
                  onTap: () => WorkerDashboardSheets.showBankAndUpi(context),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMobileFeatureTile(
                  icon: Icons.description_rounded,
                  label: 'KYC Docs',
                  sublabel: 'Badges',
                  iconColor: const Color(0xFFEA580C),
                  iconBg: const Color(0xFFFFF7ED),
                  onTap: () => WorkerDashboardSheets.showDocuments(context),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMobileFeatureTile(
                  icon: Icons.radar_rounded,
                  label: 'Radius',
                  sublabel: '${_serviceRadius}km range',
                  iconColor: const Color(0xFF7C3AED),
                  iconBg: const Color(0xFFF5F3FF),
                  onTap: () => WorkerDashboardSheets.showServiceArea(
                    context,
                    currentRadius: _serviceRadius,
                    onRadiusSelected: (r) => setState(() => _serviceRadius = r),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMobileFeatureTile({
    required IconData icon,
    required String label,
    required String sublabel,
    required Color iconColor,
    required Color iconBg,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF0F172A),
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              sublabel,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 9.5,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF64748B),
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  /// 8. Quick Actions Card
  Widget _buildQuickActionsCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x040F172A),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bolt_rounded, color: Color(0xFFEA580C), size: 20),
              const SizedBox(width: 8),
              Text(
                'Quick Actions',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildQuickActionTile(
            icon: Icons.handyman_rounded,
            iconBg: const Color(0xFFF0FDF4),
            iconColor: const Color(0xFF059669),
            title: 'My Services & Rates',
            subtitle: '${_workerSkills.length} Verified Skill',
            onTap: () => WorkerDashboardSheets.showMyServices(
              context,
              currentSkills: _workerSkills,
              onSkillsUpdated: (s) => setState(() => _workerSkills = s),
            ),
          ),
          const SizedBox(height: 10),
          _buildQuickActionTile(
            icon: Icons.account_balance_rounded,
            iconBg: const Color(0xFFEFF6FF),
            iconColor: const Color(0xFF2563EB),
            title: 'Bank & UPI Ledger',
            subtitle: 'Direct Payouts',
            onTap: () => WorkerDashboardSheets.showBankAndUpi(context),
          ),
          const SizedBox(height: 10),
          _buildQuickActionTile(
            icon: Icons.description_rounded,
            iconBg: const Color(0xFFFFF7ED),
            iconColor: const Color(0xFFEA580C),
            title: 'My Documents',
            subtitle: 'Complete verification',
            onTap: () => WorkerDashboardSheets.showDocuments(context),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionTile({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 18),
            ),
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
                      color: const Color(0xFF0F172A),
                    ),
                  ),
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
            Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.arrow_forward_rounded, color: Color(0xFF64748B), size: 14),
            ),
          ],
        ),
      ),
    );
  }

  /// 9. Tips to Get More Jobs Card
  Widget _buildTipsCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x040F172A),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.lightbulb_outline_rounded, color: Color(0xFFEA580C), size: 20),
              const SizedBox(width: 8),
              Text(
                'Tips to Get More Jobs',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildTipItem(
            title: 'Keep your location always on',
            desc: 'Helps you get nearby job requests faster.',
          ),
          const SizedBox(height: 12),
          _buildTipItem(
            title: 'Maintain high accept rate',
            desc: 'Partners with high accept rate get more jobs.',
          ),
          const SizedBox(height: 12),
          _buildTipItem(
            title: 'Keep your profile updated',
            desc: 'Add skills, rates and photos to attract more customers.',
          ),
        ],
      ),
    );
  }

  Widget _buildTipItem({required String title, required String desc}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(3),
          decoration: const BoxDecoration(
            color: Color(0xFFDCFCE7),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.check_rounded, color: Color(0xFF059669), size: 14),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                desc,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  color: const Color(0xFF64748B),
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SUPABASE REAL-TIME JOBS DISPATCH LISTENER
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
        .subscribe((status, [error]) {
          if (error != null) {
            print('[WORKER_HOME] Real-time jobs subscription error: $error');
          }
        });

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
        if (!mounted || !_isOnline) return;
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
