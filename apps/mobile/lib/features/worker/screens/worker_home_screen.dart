import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'dart:async';
import 'dart:math';
import 'package:jugaad_mvp/core/services/auth_service.dart';
import 'package:jugaad_mvp/core/services/supabase_service.dart';
import 'package:jugaad_mvp/core/services/fcm_token_manager.dart';
import 'package:jugaad_mvp/core/theme/worker_app_theme.dart';
import 'package:jugaad_mvp/shared/widgets/empty_state.dart';
import 'package:jugaad_mvp/shared/widgets/shimmer_card.dart';
import 'package:jugaad_mvp/core/services/job_dispatch_service.dart';
import 'package:jugaad_mvp/core/config/supabase_config.dart';
import 'package:jugaad_mvp/core/services/location_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class WorkerHomeScreen extends StatefulWidget {
  const WorkerHomeScreen({super.key});

  @override
  State<WorkerHomeScreen> createState() => _WorkerHomeScreenState();
}

class _WorkerHomeScreenState extends State<WorkerHomeScreen>
    with TickerProviderStateMixin {
  String _workerName = '';
  bool _isOnline = false;
  bool _emergencyAvailable = false;
  bool _workerDocExists = false;

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

      setState(() {
        _workerDocExists = true;
        _workerName = data['name'] as String? ?? '';
        _isOnline = data['is_available'] as bool? ?? false;
        _emergencyAvailable = data['emergency_available'] as bool? ?? false;
        
        final skillsData = data['skills'];
        if (skillsData is List) {
          _workerSkills = List<String>.from(skillsData.map((e) => e.toString().toLowerCase().replaceAll(' ', '_')));
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

      final recent = rows.take(3).toList();

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
      await _fs.setWorkerAvailabilityState(uid, isAvailable: isAvailable, emergencyAvailable: emergencyAvailable);
      if (isAvailable) {
        FCMTokenManager.refreshAndUploadToken();
      }
      if (mounted) {
        String msg = '';
        Color bgColor = Colors.grey;
        if (!isAvailable) {
          msg = "You are now Offline ⚫";
          bgColor = Colors.grey.shade700;
        } else if (emergencyAvailable) {
          msg = "Emergency Mode Active! Ready for urgent jobs 🚨";
          bgColor = WorkerAppTheme.urgentRed;
        } else {
          msg = "You're Live! Start receiving jobs 🟢";
          bgColor = WorkerAppTheme.primaryGreen;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.circle, color: Colors.white, size: 8),
                const SizedBox(width: 8),
                Text(
                  msg,
                  style: WorkerAppTheme.body(
                    color: Colors.white,
                    weight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            backgroundColor: bgColor,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('[WORKER_HOME] setWorkerAvailabilityState error: $e');
    }
  }

  void _cycleState() {
    if (!_isOnline) {
      _setAvailabilityState(true, false); // Go Online
    } else if (!_emergencyAvailable) {
      _setAvailabilityState(true, true); // Go Emergency Available
    } else {
      _setAvailabilityState(false, false); // Go Offline
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
      setState(() {
        _showMilestoneBanner = true;
      });
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
    super.dispose();
  }

  String getGreeting() {
    final hour = DateTime.now().hour;
    final nameStr = _workerName.isNotEmpty ? _workerName : 'Partner';
    if (hour < 12) {
      return 'Good morning, $nameStr 👋';
    } else if (hour < 17) {
      return 'Good afternoon, $nameStr 👋';
    } else {
      return 'Good evening, $nameStr 👋';
    }
  }

  Widget _buildQuickChip(IconData icon, Color iconColor, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: WorkerAppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: WorkerAppTheme.cardShadow,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: iconColor, size: 18),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value,
                style: WorkerAppTheme.heading(size: 13, color: WorkerAppTheme.textPrimary),
              ),
              Text(
                label,
                style: WorkerAppTheme.label(size: 10, color: WorkerAppTheme.textSecondary),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSegmentButton({
    required String title,
    required bool isActive,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        margin: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: isActive ? color : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.3),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  )
                ]
              : [],
        ),
        alignment: Alignment.center,
        child: Text(
          title,
          style: WorkerAppTheme.heading(
            size: 13,
            color: isActive ? Colors.white : WorkerAppTheme.textSecondary,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: WorkerAppTheme.background,
      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── HEADER STRIP ─────────────────────────────────
                  Container(
                    width: double.infinity,
                    decoration: const BoxDecoration(
                      gradient: WorkerAppTheme.deepGreenGradient,
                      borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
                    ),
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'WORKER PORTAL',
                                    style: WorkerAppTheme.label(
                                      size: 10,
                                      color: Colors.white70,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    getGreeting(),
                                    style: WorkerAppTheme.heading(
                                      size: 20,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Online Toggle Switch
                            GestureDetector(
                              onTap: _cycleState,
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                decoration: BoxDecoration(
                                  color: !_isOnline
                                      ? Colors.grey.shade300
                                      : (_emergencyAvailable
                                          ? const Color(0xFFFEE2E2)
                                          : WorkerAppTheme.mintAccent),
                                  borderRadius: BorderRadius.circular(25),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.08),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                    if (_isOnline && _emergencyAvailable)
                                      BoxShadow(
                                        color: WorkerAppTheme.urgentRed.withValues(alpha: 0.3),
                                        blurRadius: 8,
                                        spreadRadius: 1,
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
                                        color: !_isOnline
                                            ? Colors.grey.shade600
                                            : (_emergencyAvailable
                                                ? WorkerAppTheme.urgentRed
                                                : WorkerAppTheme.primaryGreen),
                                        shape: BoxShape.circle,
                                      ),
                                    )
                                        .animate(
                                          target: (_isOnline && _emergencyAvailable) ? 1 : 0,
                                          onPlay: (c) => c.repeat(reverse: true),
                                        )
                                        .scale(
                                          begin: const Offset(0.8, 0.8),
                                          end: const Offset(1.2, 1.2),
                                          duration: 600.ms,
                                        ),
                                    const SizedBox(width: 6),
                                    Text(
                                      !_isOnline
                                          ? '⚫ Offline'
                                          : (_emergencyAvailable
                                              ? '🚨 Emergency'
                                              : '🟢 Online'),
                                      style: WorkerAppTheme.label(
                                        size: 12,
                                        color: !_isOnline
                                            ? Colors.grey.shade800
                                            : (_emergencyAvailable
                                                ? WorkerAppTheme.urgentRed
                                                : WorkerAppTheme.deepGreen),
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
                  ),

                  // ── Registration Pending Banner ──────────────────
                  if (!_workerDocExists)
                    Container(
                      margin: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEE2E2),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: WorkerAppTheme.urgentRed.withValues(alpha: 0.3),
                            width: 1.5),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.access_time_filled,
                              color: WorkerAppTheme.urgentRed, size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Registration pending approval — you\'ll go live within 24 hours.',
                              style: WorkerAppTheme.body(
                                color: WorkerAppTheme.urgentRed,
                                size: 13,
                                weight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ).animate().fadeIn(duration: 400.ms, delay: 100.ms),

                  // ── Active Booking Banner ────────────────────────
                  if (_activeBookingId != null) ...[
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: () => context
                          .go('/worker/active?job_id=$_activeBookingId'),
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 20),
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: WorkerAppTheme.primaryGradient,
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [
                            BoxShadow(
                              color: WorkerAppTheme.primaryGreen.withValues(alpha: 0.3),
                              blurRadius: 14,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.play_circle_fill,
                                color: Colors.white, size: 22),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Active job in progress → Tap to view',
                                style: WorkerAppTheme.heading(
                                  color: Colors.white,
                                  size: 14,
                                ),
                              ),
                            ),
                            const Icon(Icons.arrow_forward_ios_rounded,
                                color: Colors.white70, size: 14),
                          ],
                        ),
                      ),
                    ).animate().fadeIn(duration: 400.ms, delay: 150.ms),
                  ],

                  // ── ONLINE STATUS CARD ───────────────────────────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: WorkerAppTheme.surface,
                        borderRadius: WorkerAppTheme.cardBorderRadius,
                        boxShadow: WorkerAppTheme.cardShadow,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              if (_isOnline && _emergencyAvailable) ...[
                                Container(
                                  width: 10,
                                  height: 10,
                                  decoration: const BoxDecoration(
                                    color: WorkerAppTheme.urgentRed,
                                    shape: BoxShape.circle,
                                  ),
                                )
                                    .animate(onPlay: (c) => c.repeat(reverse: true))
                                    .scale(begin: const Offset(0.7, 0.7), end: const Offset(1.3, 1.3), duration: 800.ms)
                                    .fade(begin: 0.4, end: 1.0, duration: 800.ms),
                                const SizedBox(width: 8),
                                Text(
                                  'Ready for Emergency Jobs',
                                  style: WorkerAppTheme.heading(
                                    size: 15,
                                    color: WorkerAppTheme.urgentRed,
                                  ),
                                ),
                              ] else if (_isOnline) ...[
                                Container(
                                  width: 10,
                                  height: 10,
                                  decoration: const BoxDecoration(
                                    color: WorkerAppTheme.primaryGreen,
                                    shape: BoxShape.circle,
                                  ),
                                )
                                    .animate(onPlay: (c) => c.repeat(reverse: true))
                                    .scale(begin: const Offset(0.7, 0.7), end: const Offset(1.3, 1.3), duration: 800.ms)
                                    .fade(begin: 0.4, end: 1.0, duration: 800.ms),
                                const SizedBox(width: 8),
                                Text(
                                  'Waiting for jobs...',
                                  style: WorkerAppTheme.heading(
                                    size: 15,
                                    color: WorkerAppTheme.primaryGreen,
                                  ),
                                ),
                              ] else ...[
                                const Icon(Icons.offline_bolt_rounded, color: Colors.grey, size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  "You're offline",
                                  style: WorkerAppTheme.heading(
                                    size: 15,
                                    color: WorkerAppTheme.textSecondary,
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            !_isOnline
                                ? 'Go online to start receiving job requests.'
                                : (_emergencyAvailable
                                    ? 'Priority matching active. You will receive emergency jobs within 20km.'
                                    : 'Keep the app open to receive local requests near you.'),
                            style: WorkerAppTheme.body(
                              size: 13,
                              color: WorkerAppTheme.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 16),
                          // Premium Segmented Picker
                          Container(
                            height: 50,
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: Colors.grey.shade200, width: 1),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: _buildSegmentButton(
                                    title: 'Offline',
                                    isActive: !_isOnline,
                                    color: Colors.grey.shade600,
                                    onTap: () => _setAvailabilityState(false, false),
                                  ),
                                ),
                                Expanded(
                                  child: _buildSegmentButton(
                                    title: 'Online',
                                    isActive: _isOnline && !_emergencyAvailable,
                                    color: WorkerAppTheme.primaryGreen,
                                    onTap: () => _setAvailabilityState(true, false),
                                  ),
                                ),
                                Expanded(
                                  child: _buildSegmentButton(
                                    title: 'Emergency',
                                    isActive: _isOnline && _emergencyAvailable,
                                    color: WorkerAppTheme.urgentRed,
                                    onTap: () => _setAvailabilityState(true, true),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: Divider(height: 1, thickness: 1, color: WorkerAppTheme.divider),
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "TODAY'S JOBS",
                                    style: WorkerAppTheme.label(size: 11, color: WorkerAppTheme.textSecondary),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '$_todayJobCount',
                                    style: WorkerAppTheme.heading(size: 20, color: WorkerAppTheme.textPrimary),
                                  ),
                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    "TODAY'S EARNINGS",
                                    style: WorkerAppTheme.label(size: 11, color: WorkerAppTheme.textSecondary),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '₹${_todayEarnings.toInt()}',
                                    style: WorkerAppTheme.heading(size: 20, color: WorkerAppTheme.primaryGreen),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ).animate().fadeIn(duration: 400.ms, delay: 200.ms),

                  // ── QUICK STATS BAR ──────────────────────────────
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        children: [
                          _buildQuickChip(Icons.star_rounded, Colors.orange, 'Rating', '4.9'),
                          const SizedBox(width: 12),
                          _buildQuickChip(Icons.check_circle_rounded, WorkerAppTheme.primaryGreen, 'Week Jobs', '$_weekJobCount'),
                          const SizedBox(width: 12),
                          _buildQuickChip(Icons.emoji_events_rounded, WorkerAppTheme.earningGold, 'Trust Score', '91'),
                          const SizedBox(width: 12),
                          _buildQuickChip(Icons.local_fire_department_rounded, WorkerAppTheme.urgentRed, 'Streak', '3 days'),
                        ],
                      ),
                    ),
                  ),

                  // ── Recent Jobs Header ───────────────────────────
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'TODAY\'S JOBS',
                          style: WorkerAppTheme.label(
                              color: WorkerAppTheme.textPrimary, size: 12),
                        ),
                        GestureDetector(
                          onTap: () => context.go('/worker/earnings'),
                          child: Text(
                            'See all →',
                            style: WorkerAppTheme.body(
                              color: WorkerAppTheme.primaryGreen,
                              weight: FontWeight.w700,
                              size: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ).animate().fadeIn(duration: 400.ms, delay: 300.ms),

                  const SizedBox(height: 12),

                  // ── Recent Booking Cards ─────────────────────────
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _buildRecentJobs(),
                  ).animate().fadeIn(duration: 400.ms, delay: 350.ms),

                  const SizedBox(height: 36),
                ],
              ),
            ),

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
                          painter: _ConfettiPainter(_particles, _confettiController.value),
                        );
                      },
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 16,
                left: 20,
                right: 20,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 18, vertical: 14),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFFD4AF37),
                        Color(0xFFFFDF00),
                        Color(0xFFD4AF37),
                      ],
                      stops: [0.0, 0.5, 1.0],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFD4AF37).withValues(alpha: 0.4),
                        blurRadius: 18,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Row(
                    children: const [
                      Icon(Icons.emoji_events_rounded,
                          color: Colors.white, size: 24),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          '🏆 ₹1,000 Milestone Reached! 🎉',
                          style: TextStyle(
                            fontFamily: 'Plus Jakarta Sans',
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 14,
                          ),
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
                    .shimmer(duration: 1200.ms, color: Colors.white38)
                    .fadeOut(delay: 3200.ms, duration: 400.ms),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRecentJobs() {
    if (_recentLoading) {
      return const ShimmerList(itemCount: 3);
    }

    if (_recentBookings.isEmpty) {
      return EmptyState(
        icon: Icons.work_outline_rounded,
        heading: 'No jobs today',
        subtitle: 'Stay online to receive job requests.',
        iconColor: WorkerAppTheme.primaryGreen,
        iconBackground: WorkerAppTheme.primaryGreen.withValues(alpha: 0.1),
      );
    }

    return Column(
      children: _recentBookings.asMap().entries.map((entry) {
        final data = entry.value;
        final service = data['service'] as String? ?? 'Service';
        final userName = data['userName'] as String? ?? 'Customer';
        final amount = (data['amount'] as num? ?? 0).toStringAsFixed(0);
        final status = data['status'] as String? ?? 'completed';

        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _buildRecentJobCard(
            service: service,
            customerName: userName,
            amount: '₹$amount',
            status: status,
          ),
        );
      }).toList(),
    );
  }

  Widget _buildRecentJobCard({
    required String service,
    required String customerName,
    required String amount,
    required String status,
  }) {
    final isCompleted = status == 'completed';
    final statusColor = isCompleted ? WorkerAppTheme.primaryGreen : WorkerAppTheme.earningGold;

    return Container(
      decoration: BoxDecoration(
        color: WorkerAppTheme.surface,
        borderRadius: WorkerAppTheme.cardBorderRadius,
        boxShadow: WorkerAppTheme.cardShadow,
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isCompleted
                  ? Icons.check_circle_rounded
                  : Icons.schedule_rounded,
              color: statusColor,
              size: 18,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  service,
                  style: WorkerAppTheme.heading(size: 14, color: WorkerAppTheme.textPrimary),
                ),
                const SizedBox(height: 2),
                Text(
                  customerName,
                  style: WorkerAppTheme.body(size: 12, color: WorkerAppTheme.textSecondary),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: WorkerAppTheme.primaryGreen.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              amount,
              style: WorkerAppTheme.heading(
                size: 13,
                color: WorkerAppTheme.primaryGreen,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _startJobsListener() {
    if (_jobsChannel != null) return; // Already listening

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
        
    // Also check for any existing jobs currently searching
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
    final a = 0.5 - c((lat2 - lat1) * p)/2 + 
          c(lat1 * p) * c(lat2 * p) * 
          (1 - c((lon2 - lon1) * p))/2;
    return 12742 * asin(sqrt(a)); // 2 * R; R = 6371 km
  }

  void _checkAndShowJobOffer(Map<String, dynamic> data) {
    final jobId = data['id'] as String? ?? '';
    if (jobId.isEmpty) return;

    // 1. Is worker busy?
    if (_activeBookingId != null) {
      print('[WORKER_HOME] Skip job $jobId: worker is busy with booking $_activeBookingId');
      return;
    }

    // 2. Has worker already rejected/passed this job?
    if (JobDispatchService().ignoredJobIds.contains(jobId)) {
      print('[WORKER_HOME] Skip job $jobId: already ignored/rejected');
      return;
    }

    // 3. Does skill match?
    final skillRequired = (data['skill_required'] as String? ?? '').toLowerCase().replaceAll(' ', '_');
    final matchesSkill = _workerSkills.contains(skillRequired);
    if (!matchesSkill) {
      print('[WORKER_HOME] Skip job $jobId: skill mismatch. Required: $skillRequired, Worker skills: $_workerSkills');
      return;
    }

    // 4. Calculate distance
    double distance = 0.0;
    final workerPos = LocationService().currentPosition;
    
    // Parse job location
    final jobLocation = data['location'];
    double? jobLat;
    double? jobLng;
    if (jobLocation is String) {
      if (jobLocation.contains('POINT')) {
        final match = RegExp(r'POINT\s*\(\s*([-\d.]+)\s+([-\d.]+)\s*\)').firstMatch(jobLocation);
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
      distance = _calculateDistance(workerPos.latitude, workerPos.longitude, jobLat, jobLng);
    }

    // Redirect to incoming request screen
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
    required this.vx,
    required this.vy,
    required this.size,
    required this.color,
    required this.rotation,
    required this.rotationSpeed,
  });
}

class _ConfettiPainter extends CustomPainter {
  final List<_ConfettiParticle> particles;
  final double progress;
  _ConfettiPainter(this.particles, this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    if (particles.isEmpty) return;
    final paint = Paint()..style = PaintingStyle.fill;
    final frames = progress * 240.0; // 4 seconds at 60fps equivalent
    for (var p in particles) {
      final currentX = p.x + p.vx * frames;
      final currentY = p.y + (p.vy * frames) + (0.5 * 0.15 * frames * frames);
      final currentRotation = p.rotation + p.rotationSpeed * frames;

      paint.color = p.color.withValues(alpha: (1.0 - progress * 0.5).clamp(0.0, 1.0));
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
