import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:jugaad_mvp/core/config/supabase_config.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lottie/lottie.dart';
import 'dart:math';
import 'dart:async';
import 'package:jugaad_mvp/core/services/api_service.dart';
import 'package:jugaad_mvp/core/services/supabase_service.dart';
import 'package:jugaad_mvp/shared/widgets/animated_counter.dart';
import 'package:jugaad_mvp/core/utils/jugaad_haptics.dart';
import 'package:shimmer/shimmer.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jugaad_mvp/features/user/screens/user_home_screen.dart';
import 'package:jugaad_mvp/core/theme/user_app_theme.dart';

// ─── MATCHING STATES ────────────────────────────────────────
enum MatchingState { searching, expanding, assigned, noWorkersFound }

// ─── MATCHING SCREEN ─────────────────────────────────────────

class MatchingScreen extends ConsumerStatefulWidget {
  final String jobId;
  const MatchingScreen({super.key, required this.jobId});

  @override
  ConsumerState<MatchingScreen> createState() => _MatchingScreenState();
}

class _MatchingScreenState extends ConsumerState<MatchingScreen> with TickerProviderStateMixin, WidgetsBindingObserver {
  // ── Supabase ────────────────────────────────────────────
  RealtimeChannel? _realtimeChannel;
  Map<String, dynamic> _jobData = {};
  Map<String, dynamic>? _workerData;
  List<Map<String, dynamic>> _topRatedWorkers = [];
  bool _isLoadingTopRated = false;

  // ── UI State ─────────────────────────────────────────────
  MatchingState _matchingState = MatchingState.searching;

  // ── 90s Fallback Timer ───────────────────────────────────
  Timer? _fallbackTimer;
  int _fallbackSecondsLeft = 90;
  Timer? _fallbackCountTimer;

  // ── 60s Accept Countdown ─────────────────────────────────
  late AnimationController _acceptCountdown;   // drains 1→0 in 60s
  late AnimationController _acceptPulse;       // scale pulse at <10s

  // ── Pulse ring animation ─────────────────────────────────
  late AnimationController _pulseController;

  // ── Avatar ripple animation ──────────────────────────────
  late AnimationController _avatarRippleController;

  // ── NEW PHASE 1 CONTROLLERS ──────────────────────────────
  late AnimationController _lottieBgController;
  late AnimationController _orbitController;   // 3000ms, repeat
  late AnimationController _dotController;     // 600ms, repeat reverse
  late AnimationController _cardController;    // 700ms, forward on initState
  late AnimationController _counterController; // 1000ms, forward on initState
  late AnimationController _shimmerController; // 2000ms, repeat

  // ── NEW PHASE 1 CONTROLLERS (ASSIGNED STATE) ─────────────
  late AnimationController _celebrationController; // 1400ms, forward on init
  late AnimationController _assignedShimmerController; // 1500ms, forward once
  late AnimationController _assignedBgController;  // 600ms, forward on init

  bool _isActioning = false;
  DateTime? _lastBackgroundTime;

  @override
  void initState() {
    super.initState();
    
    _lottieBgController = AnimationController(vsync: this);
    _orbitController   = AnimationController(vsync: this, duration: const Duration(milliseconds: 3000))..repeat();
    _dotController     = AnimationController(vsync: this, duration: const Duration(milliseconds: 600))..repeat(reverse: true);
    _cardController    = AnimationController(vsync: this, duration: const Duration(milliseconds: 700))
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) JugaadHaptics.light();
      })
      ..forward();
    _counterController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000))..forward();
    _shimmerController = AnimationController(vsync: this, duration: const Duration(milliseconds: 2000))..repeat();

    _celebrationController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));
    _assignedShimmerController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500));
    _assignedBgController = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));

    WidgetsBinding.instance.addPostFrameCallback((_) {
      JugaadHaptics.medium();
    });

    WidgetsBinding.instance.addObserver(this);
    _initAnimations();
    _startRealtimeListener();
    _startFallbackTimer();
  }

  void _initAnimations() {
    _pulseController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800))
      ..repeat();

    _acceptCountdown = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 60),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) _onCountdownExpired();
      });

    _acceptPulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    )..repeat(reverse: true);

    _avatarRippleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
  }

  void _startRealtimeListener() {
    if (widget.jobId.isEmpty) return;

    _realtimeChannel = SupabaseConfig.client
        .channel('public:jobs')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'jobs',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: widget.jobId,
          ),
          callback: (payload) {
            if (!mounted) return;
            print('[MATCHING] Supabase realtime event: ${payload.eventType}');
            final data = payload.newRecord;
            if (data.isEmpty) return;
            
            final status = data['status'] as String? ?? 'open';
            final fallback = data['fallback_triggered'] as bool? ?? false;

            _updateState(status, fallback, data);
          },
        )
        .subscribe();

    _fetchInitialJobState();
  }

  Future<void> _fetchInitialJobState() async {
    try {
      final doc = await SupabaseConfig.client
          .from('jobs')
          .select()
          .eq('id', widget.jobId)
          .maybeSingle();
      if (doc != null && mounted) {
        final status = doc['status'] as String? ?? 'open';
        final fallback = doc['fallback_triggered'] as bool? ?? false;
        _updateState(status, fallback, doc);
      }
    } catch (e) {
      print('[MATCHING] Error fetching initial job state: $e');
    }
  }

  void _updateState(String status, bool fallback, Map<String, dynamic> data) {
    setState(() => _jobData = data);

    if (status == 'in_progress' || status == 'accepted') {
      ref.invalidate(recentJobsProvider);
      ref.invalidate(nearbyWorkersProvider);
      if (mounted) context.go('/user/tracking?job_id=${widget.jobId}');
      return;
    } else if (status == 'completed') {
      ref.invalidate(recentJobsProvider);
      ref.invalidate(nearbyWorkersProvider);
      final amount = data['payment_amount'] ?? data['amount'] ?? 0;
      if (mounted) context.go('/user/payment?job_id=${widget.jobId}&amount=$amount');
      return;
    } else if (status == 'cancelled' || status == 'scheduled') {
      ref.invalidate(recentJobsProvider);
      ref.invalidate(nearbyWorkersProvider);
      if (mounted) context.go('/user/home');
      return;
    }

    MatchingState newState;
    if (status == 'matched') {
      newState = MatchingState.assigned;
      if (_matchingState != MatchingState.assigned) {
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          await JugaadHaptics.success();
          await Future.delayed(200.ms);
          await JugaadHaptics.success();
        });
        _celebrationController.forward(from: 0);
        _assignedShimmerController.forward(from: 0);
        _assignedBgController.forward(from: 0);
      }
    } else if (status == 'no_workers_found') {
      newState = MatchingState.noWorkersFound;
      _fetchTopRatedFallbackWorkers();
    } else if (fallback) {
      newState = MatchingState.expanding;
    } else {
      newState = MatchingState.searching;
    }

    if (newState != _matchingState) {
      print('[MATCHING] Transitioning to state: $newState');
      setState(() {
        _matchingState = newState;
        _isActioning = false;
      });

      if (newState == MatchingState.noWorkersFound) {
        _fetchTopRatedFallbackWorkers();
      }

      if (newState == MatchingState.expanding) {
        _pulseController.duration = const Duration(milliseconds: 2500);
        _pulseController.repeat();
      }

      if (newState == MatchingState.assigned) {
        _fallbackTimer?.cancel();
        _fallbackCountTimer?.cancel();
        _acceptCountdown.reset();
        _acceptCountdown.forward();
        _avatarRippleController.repeat();

        HapticFeedback.heavyImpact();
        Future.delayed(const Duration(milliseconds: 150), () => HapticFeedback.mediumImpact());

        final workerId = data['worker_id'];
        if (workerId != null) {
          _fetchWorkerDetails(workerId);
        }
      }
    }
  }

  Future<void> _fetchTopRatedFallbackWorkers() async {
    final skill = _jobData['skill_required'] as String? ??
        _jobData['skill'] as String? ??
        _jobData['title'] as String? ??
        '';

    setState(() => _isLoadingTopRated = true);
    try {
      final workers = await SupabaseService().fetchTopRatedWorkersByCategory(
        category: skill,
        limit: 8,
      );
      if (mounted) {
        setState(() {
          _topRatedWorkers = workers;
          _isLoadingTopRated = false;
        });
      }
    } catch (e) {
      print('[MATCHING] Error fetching top rated fallback workers: $e');
      if (mounted) {
        setState(() => _isLoadingTopRated = false);
      }
    }
  }

  Future<void> _directAssignWorker(Map<String, dynamic> worker) async {
    final workerId = worker['id']?.toString() ?? '';
    final workerName = worker['name']?.toString() ?? 'Worker';

    HapticFeedback.mediumImpact();
    setState(() => _isActioning = true);

    try {
      // Update job with worker_id in Supabase
      await SupabaseConfig.client.from('jobs').update({
        'worker_id': workerId,
        'status': 'assigned',
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', widget.jobId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Successfully requested $workerName! Connecting...',
              style: UserAppTheme.body(color: Colors.white, weight: FontWeight.bold),
            ),
            backgroundColor: UserAppTheme.successGreen,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
        setState(() {
          _workerData = Map<String, dynamic>.from(worker);
          _workerData!['name'] = workerName;
          _workerData!['phone'] = worker['phone'] ?? '';
          _workerData!['specialty'] = _jobData['skill_required'] ?? _jobData['skill'] ?? worker['category'] ?? 'Helper';
          _workerData!['rating'] = double.tryParse(worker['rating']?.toString() ?? '4.9') ?? 4.9;
          _workerData!['jobs_done'] = worker['total_jobs'] ?? worker['totalJobsCompleted'] ?? 50;
          _workerData!['distance_km'] = 2.5;
          _workerData!['eta_mins'] = 15;
          _workerData!['initials'] = workerName.isNotEmpty ? workerName.substring(0, 1).toUpperCase() : 'W';
          _matchingState = MatchingState.assigned;
          _isActioning = false;
        });
        _celebrationController.forward(from: 0);
        _assignedShimmerController.forward(from: 0);
        _assignedBgController.forward(from: 0);
        _acceptCountdown.reset();
        _acceptCountdown.forward();
      }
    } catch (e) {
      print('[MATCHING] Error directly assigning worker: $e');
      if (mounted) {
        setState(() => _isActioning = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not request worker: $e')),
        );
      }
    }
  }

  Future<void> _fetchWorkerDetails(String workerId) async {
    try {
      final response = await SupabaseConfig.client
          .from('workers')
          .select('*, users(*)')
          .eq('id', workerId)
          .maybeSingle();
      if (response != null && mounted) {
        final worker = response;
        final user = worker['users'] as Map? ?? {};
        setState(() {
          _workerData = Map<String, dynamic>.from(worker);
          _workerData!['name'] = user['name'] ?? 'Worker';
          _workerData!['phone'] = user['phone'] ?? '';
          _workerData!['specialty'] = _jobData['skill_required'] ?? 'Helper';
          _workerData!['rating'] = double.tryParse(worker['rating']?.toString() ?? '4.8') ?? 4.8;
          _workerData!['jobs_done'] = worker['total_jobs'] ?? 14;
          _workerData!['distance_km'] = 1.8;
          _workerData!['eta_mins'] = 10;
          _workerData!['initials'] = (_workerData!['name'] as String).substring(0, 1).toUpperCase();
        });
      }
    } catch (e) {
      print('[MATCHING] Error fetching worker $workerId: $e');
    }
  }

  void _startFallbackTimer() {
    _fallbackSecondsLeft = 90;
    _fallbackTimer?.cancel();
    _fallbackCountTimer?.cancel();

    _fallbackTimer = Timer(const Duration(seconds: 90), () {
      if (!mounted) return;
      setState(() {
        _matchingState = MatchingState.noWorkersFound;
      });
      _fetchTopRatedFallbackWorkers();
    });

    _fallbackCountTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() {
        if (_fallbackSecondsLeft > 0) {
          _fallbackSecondsLeft--;
        } else {
          t.cancel();
          if (_matchingState != MatchingState.assigned && _matchingState != MatchingState.noWorkersFound) {
            _matchingState = MatchingState.noWorkersFound;
            _fetchTopRatedFallbackWorkers();
          }
        }
      });
    });
  }

  void _onCountdownExpired() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Booking session expired — restarting search',
          style: UserAppTheme.body(color: Colors.white, weight: FontWeight.bold),
        ),
        backgroundColor: UserAppTheme.primaryBlue,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
    _acceptCountdown.reset();
    setState(() => _matchingState = MatchingState.searching);
    _startFallbackTimer();
  }

  Future<void> _cancelJob() async {
    print('[MATCHING] Cancelling job: ${widget.jobId}');
    try {
      await ApiService().deleteJob(widget.jobId);
    } catch (e) {
      print('[MATCHING] Error cancelling job: $e');
    }
    ref.invalidate(recentJobsProvider);
    ref.invalidate(nearbyWorkersProvider);
    if (mounted) context.go('/user/home');
  }

  Future<void> _acceptWorker() async {
    HapticFeedback.heavyImpact();
    setState(() => _isActioning = true);
    print('[MATCHING] Accepting worker for job: ${widget.jobId}');
    
    try {
      final expectedVersion = _jobData['version'] as int? ?? 1;
      await ApiService().acceptJob(widget.jobId, expectedVersion);
      if (mounted) {
        context.go('/user/tracking?job_id=${widget.jobId}');
      }
    } catch (e) {
      print('[MATCHING] Error accepting worker: $e');
      if (mounted) {
        setState(() => _isActioning = false);
        if (e.toString().contains('409')) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Version mismatch or job already modified.',
                style: UserAppTheme.body(color: Colors.white),
              ),
              backgroundColor: UserAppTheme.urgentRed,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
          setState(() => _matchingState = MatchingState.searching);
          _startFallbackTimer();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
      }
    }
  }

  Future<void> _declineWorker() async {
    HapticFeedback.mediumImpact();
    setState(() => _isActioning = true);
    try {
      await ApiService().declineJob(widget.jobId);
    } catch (e) {
      print('[MATCHING] Error declining job: $e');
      if (mounted) {
        setState(() => _isActioning = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _requestCallback() async {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Callback Requested',
          style: UserAppTheme.heading(weight: FontWeight.bold),
        ),
        content: Text(
          'Our support team will call you shortly on your registered number to manually allocate a premium helper.',
          style: UserAppTheme.body().copyWith(height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Great',
              style: UserAppTheme.body(
                color: UserAppTheme.primaryBlue,
                weight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _convertToScheduled() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(hours: 2)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: UserAppTheme.primaryBlue,
              onPrimary: Colors.white,
              onSurface: UserAppTheme.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 10, minute: 0),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: UserAppTheme.primaryBlue,
              onPrimary: Colors.white,
              onSurface: UserAppTheme.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (time == null || !mounted) return;

    final scheduledAt = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    print('[MATCHING] Job converted to scheduled at: $scheduledAt');

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Job scheduled for ${scheduledAt.day}/${scheduledAt.month} at ${time.format(context)}',
            style: UserAppTheme.body(color: Colors.white, weight: FontWeight.bold),
          ),
          backgroundColor: UserAppTheme.successGreen,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ),
      );
      context.go('/user/home');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (_realtimeChannel != null) {
      SupabaseConfig.client.removeChannel(_realtimeChannel!);
    }
    _fallbackTimer?.cancel();
    _fallbackCountTimer?.cancel();
    _pulseController.dispose();
    _acceptCountdown.dispose();
    _acceptPulse.dispose();
    _avatarRippleController.dispose();
    _lottieBgController.dispose();
    _orbitController.dispose();
    _dotController.dispose();
    _cardController.dispose();
    _counterController.dispose();
    _shimmerController.dispose();
    _celebrationController.dispose();
    _assignedShimmerController.dispose();
    _assignedBgController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      _lastBackgroundTime = DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      if (_lastBackgroundTime != null) {
        if (DateTime.now().difference(_lastBackgroundTime!).inMinutes >= 10) {
          print('[MATCHING] App resumed after > 10 min. Force refreshing Supabase listener.');
          if (_realtimeChannel != null) {
            SupabaseConfig.client.removeChannel(_realtimeChannel!);
          }
          _startRealtimeListener();
        }
      }
    }
  }

  // ─── BUILD ───────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _assignedBgController,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            color: ColorTween(
              begin: UserAppTheme.background,
              end: const Color(0xFF0F172A), // Premium Dark Slate
            ).evaluate(_assignedBgController),
          ),
          child: Scaffold(
            backgroundColor: Colors.transparent,
            body: Stack(
              children: [
                // Radial Gradient Base Layer
                Positioned.fill(
                  child: Opacity(
                    opacity: 1.0,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          center: const Alignment(0, 0.15),
                          colors: _matchingState == MatchingState.assigned
                              ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
                              : (_jobData['job_type'] == 'emergency'
                                  ? [const Color(0xFF7F1D1D), const Color(0xFF450A0A)]
                                  : [const Color(0xFF1E3A8A), const Color(0xFF0F172A)]),
                          radius: 1.5,
                        ),
                      ),
                    ),
                  ),
                ),
                
                // Content
                SafeArea(
                  child: switch (_matchingState) {
                    MatchingState.searching      => _buildSearching(false),
                    MatchingState.expanding      => _buildSearching(true),
                    MatchingState.assigned       => _buildAssigned(),
                    MatchingState.noWorkersFound => _buildNoWorkersFound(),
                  },
                ),
                
                // Celebration Burst
                if (_matchingState == MatchingState.assigned)
                  Positioned(
                    top: 100,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: RepaintBoundary(
                        child: SizedBox(
                          width: 200,
                          height: 200,
                          child: Lottie.asset(
                            'assets/lottie/celebration_burst.json',
                            repeat: false,
                            frameRate: const FrameRate(60),
                            errorBuilder: (context, error, stackTrace) => const SizedBox(),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ─── STATE A / A2: SEARCHING ─────────────────────────────
  Widget _buildSearching(bool isExpanding) {
    final skill = _jobData['skill_required'] as String? ??
        _jobData['title'] as String? ??
        _jobData['skill'] as String? ??
        'Service';
    final urgency = _jobData['urgency'] as String? ?? 'now';
    final isEmergency = _jobData['job_type'] == 'emergency';
    final radarColor = isEmergency ? Colors.redAccent : UserAppTheme.primaryBlue;

    final radiusText = isEmergency
        ? (isExpanding ? 'Within 20 km (Progressive)' : 'Within 10 km')
        : (isExpanding ? 'Within 5 km' : 'Within 2.5 km');
        
    final etaText = isEmergency ? '18 mins' : '10 mins';

    return Stack(
      children: [
        Column(
          children: [
            // Beautiful Transparent Top Status Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Colors.transparent,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isEmergency
                              ? (isExpanding ? '🚨 EXPANDING EMERGENCY RADIS...' : '🚨 FINDING EMERGENCY RESPONDERS...')
                              : (isExpanding ? 'Expanding Search...' : 'Finding Helpers...'),
                          style: UserAppTheme.heading(
                            size: 16,
                            weight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isEmergency
                              ? 'Locating verified responder within 30 mins'
                              : 'Connecting to nearby experts in Mysuru',
                          style: UserAppTheme.body(
                            size: 12,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                  OutlinedButton(
                    onPressed: _cancelJob,
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.white30, width: 1.0),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      'Cancel',
                      style: UserAppTheme.label(
                        size: 12,
                        color: Colors.white,
                        weight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 280),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 32),
                    // Custom Pulsing Radar Animation instead of Lottie
                    PulsingRadar(
                      color: radarColor,
                      serviceType: skill,
                    ),
                    const SizedBox(height: 24),
                    // Typewriter cycling status text
                    TypewriterStatusText(
                      serviceType: skill,
                    ),
                    const SizedBox(height: 10),
                    // Worker count
                    AnimatedBuilder(
                      animation: _counterController,
                      builder: (context, child) {
                        final workerCount = _jobData['nearby_workers'] as int? ?? 42;
                        final displayCount = (workerCount * _counterController.value).round();
                        return RichText(
                           text: TextSpan(
                            children: [
                              TextSpan(
                                text: '$displayCount',
                                style: UserAppTheme.heading(
                                  size: 42,
                                  weight: FontWeight.w800,
                                  color: isEmergency ? Colors.redAccent : UserAppTheme.skyAccent,
                                ),
                              ),
                              TextSpan(
                                text: ' workers online',
                                style: UserAppTheme.body(
                                  size: 15,
                                  color: Colors.white70,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 24),

                    // Fallback cards (STATE A2/Expanding only)
                    if (isExpanding) ...[
                      const SizedBox(height: 24),
                      _buildScheduleCard().animate().fadeIn(delay: 100.ms).slideY(begin: 0.05),
                      const SizedBox(height: 12),
                      _buildCallbackCard().animate().fadeIn(delay: 200.ms).slideY(begin: 0.05),
                      const SizedBox(height: 20),
                      TextButton(
                        onPressed: () {
                          setState(() => _matchingState = MatchingState.expanding);
                          _startFallbackTimer();
                        },
                        child: Text(
                          'Keep scanning in Mysuru',
                          style: UserAppTheme.body(
                            size: 13,
                            weight: FontWeight.bold,
                            color: Colors.white70,
                          ).copyWith(decoration: TextDecoration.underline),
                        ),
                      ),
                    ],

                    const SizedBox(height: 24),

                    if (!isExpanding)
                      Text(
                        isEmergency 
                            ? 'Broadening emergency search radius in ${_fallbackSecondsLeft}s...'
                            : 'Broadening search radius in ${_fallbackSecondsLeft}s...',
                        style: UserAppTheme.body(
                          size: 12,
                          weight: FontWeight.w600,
                          color: Colors.white70,
                        ),
                      ).animate().fadeIn(delay: 300.ms),
                  ],
                ),
              ),
            ),
          ],
        ),
        // Bottom Slide-Up Job Card
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: AnimatedBuilder(
            animation: CurvedAnimation(parent: _cardController, curve: Curves.easeOutCubic),
            builder: (context, child) {
              final slideVal = CurvedAnimation(parent: _cardController, curve: Curves.easeOutCubic).value;
              return Transform.translate(
                offset: Offset(0, (1 - slideVal) * 200),
                child: Opacity(
                  opacity: slideVal,
                  child: child,
                ),
              );
            },
            child: Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: UserAppTheme.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isEmergency ? Colors.redAccent.withValues(alpha: 0.5) : UserAppTheme.divider,
                  width: isEmergency ? 2 : 1,
                ),
                boxShadow: UserAppTheme.cardShadow,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        isEmergency ? '🚨 Emergency Request' : 'Booking Overview',
                        style: UserAppTheme.heading(
                          size: 15,
                          weight: FontWeight.bold,
                          color: isEmergency ? const Color(0xFFDC2626) : UserAppTheme.textPrimary,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: isEmergency 
                              ? Colors.red.withValues(alpha: 0.1)
                              : (urgency == 'now' 
                                  ? UserAppTheme.urgentRed.withValues(alpha: 0.1) 
                                  : UserAppTheme.primaryBlue.withValues(alpha: 0.1)),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          isEmergency ? 'EMERGENCY' : (urgency == 'now' ? 'Urgent (Now)' : 'Scheduled'),
                          style: UserAppTheme.label(
                            size: 11,
                            color: isEmergency ? Colors.red : (urgency == 'now' ? UserAppTheme.urgentRed : UserAppTheme.primaryBlue),
                            weight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _jobSummaryRow(Icons.build_circle_outlined, 'Service Required', skill),
                  const SizedBox(height: 12),
                  _jobSummaryRow(Icons.radar_rounded, 'Search Radius', radiusText),
                  const SizedBox(height: 12),
                  _jobSummaryRow(Icons.hourglass_bottom_rounded, 'Expiry Timer', 'Expires in ${_fallbackSecondsLeft}s', isUrgent: true),
                  const SizedBox(height: 12),
                  _jobSummaryRow(Icons.speed_rounded, 'Estimated Arrival', etaText),
                  const SizedBox(height: 12),
                  const Divider(height: 1, color: UserAppTheme.divider),
                  const SizedBox(height: 12),
                  if (isEmergency) ...[
                    _jobSummaryRow(Icons.currency_rupee_rounded, 'Base Job Price', '₹${_jobData['amount'] ?? '350'}'),
                    const SizedBox(height: 8),
                    _jobSummaryRow(Icons.bolt_rounded, 'Emergency Surcharge', '₹${_jobData['surcharge_amount'] ?? '150'}', isUrgent: true),
                    const SizedBox(height: 8),
                    const Divider(height: 1, color: UserAppTheme.divider),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.add_shopping_cart_rounded, color: UserAppTheme.successGreen, size: 18),
                        const SizedBox(width: 10),
                        Text(
                          'Total Amount',
                          style: UserAppTheme.body(
                            size: 13,
                            color: UserAppTheme.successGreen,
                            weight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '₹${(double.tryParse(_jobData['amount']?.toString() ?? '350') ?? 350) + (double.tryParse(_jobData['surcharge_amount']?.toString() ?? '150') ?? 150)}',
                          style: UserAppTheme.body(
                            size: 15,
                            weight: FontWeight.bold,
                            color: UserAppTheme.successGreen,
                          ),
                        ),
                      ],
                    ),
                  ] else ...[
                    _jobSummaryRow(Icons.currency_rupee_rounded, 'Est. Cost', '₹${_jobData['amount'] ?? '350'}'),
                  ],
                  const SizedBox(height: 16),
                  Center(
                    child: TextButton(
                      onPressed: _cancelJob,
                      child: Text(
                        'Cancel Request',
                        style: UserAppTheme.body(
                          size: 13,
                          color: UserAppTheme.urgentRed,
                          weight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildScheduleCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF3C7), // Light yellow
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFACC15).withValues(alpha: 0.2), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.calendar_month, size: 20, color: Color(0xFFD97706)),
              SizedBox(width: 10),
              Text(
                'Schedule for later instead?',
                style: TextStyle(
                  fontFamily: 'Plus Jakarta Sans',
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFD97706),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Cannot wait? Book a slot for later today or tomorrow, and we will guarantee a high-rated worker.',
            style: UserAppTheme.body(
              size: 12,
              color: UserAppTheme.textSecondary,
            ).copyWith(height: 1.4),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton(
              onPressed: _convertToScheduled,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD97706),
                minimumSize: const Size(0, 36),
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: Text(
                'Pick a Time',
                style: UserAppTheme.label(
                  color: Colors.white,
                  size: 12,
                  weight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCallbackCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF), // Light blue
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: UserAppTheme.primaryBlue.withValues(alpha: 0.2), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.phone_in_talk, size: 20, color: UserAppTheme.primaryBlue),
              SizedBox(width: 10),
              Text(
                'Request manual matchmaking',
                style: TextStyle(
                  fontFamily: 'Plus Jakarta Sans',
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: UserAppTheme.primaryBlue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Let our Mysuru local office find and assign a certified expert for you offline.',
            style: UserAppTheme.body(
              size: 12,
              color: UserAppTheme.textSecondary,
            ).copyWith(height: 1.4),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton(
              onPressed: _requestCallback,
              style: ElevatedButton.styleFrom(
                backgroundColor: UserAppTheme.primaryBlue,
                minimumSize: const Size(0, 36),
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: Text(
                'Call Me',
                style: UserAppTheme.label(
                  color: Colors.white,
                  size: 12,
                  weight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── STATE C: NO WORKERS FOUND ───────────────────────────
  Widget _buildNoWorkersFound() {
    final skill = _jobData['skill_required'] as String? ??
        _jobData['skill'] as String? ??
        _jobData['title'] as String? ??
        'Service';

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          width: double.infinity,
          decoration: const BoxDecoration(
            color: Colors.transparent,
          ),
          child: Row(
            children: [
              IconButton(
                onPressed: () => context.go('/user/home'),
                icon: const Icon(Icons.arrow_back, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Available $skill Specialists',
                      style: UserAppTheme.heading(
                        size: 16,
                        weight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Ranked by highest customer ratings in Mysuru',
                      style: UserAppTheme.body(
                        size: 11,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Alert / Status Info Banner
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: const Color(0xFFFACC15).withValues(alpha: 0.35),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.stars_rounded, color: Color(0xFFFBBF24), size: 22),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'No direct instant responder within 3km radar. Showing top-rated $skill professionals available for direct booking below:',
                          style: UserAppTheme.body(
                            size: 12,
                            color: Colors.white,
                            weight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.05),

                const SizedBox(height: 18),

                // Top Rated Section Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Top-Rated $skill Pros',
                      style: UserAppTheme.heading(
                        size: 15,
                        weight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: UserAppTheme.primaryBlue.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: UserAppTheme.primaryBlue.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.sort_rounded, color: Colors.white, size: 12),
                          const SizedBox(width: 4),
                          Text(
                            'Highest Rated',
                            style: UserAppTheme.label(
                              size: 10,
                              color: Colors.white,
                              weight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // List of Top Rated Available Workers
                if (_isLoadingTopRated) ...[
                  const SizedBox(height: 40),
                  const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
                  const SizedBox(height: 40),
                ] else if (_topRatedWorkers.isEmpty) ...[
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white12),
                    ),
                    alignment: Alignment.center,
                    child: Column(
                      children: [
                        const Icon(Icons.person_search_rounded, size: 36, color: Colors.white70),
                        const SizedBox(height: 10),
                        Text(
                          'No available workers in this category right now',
                          style: UserAppTheme.body(color: Colors.white, weight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _topRatedWorkers.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final worker = _topRatedWorkers[index];
                      final name = worker['name']?.toString() ?? 'Verified Worker';
                      final rating = double.tryParse(worker['rating']?.toString() ?? '4.9') ?? 4.9;
                      final totalJobs = worker['total_jobs'] ?? worker['totalJobsCompleted'] ?? 50;
                      final hourlyRate = worker['hourly_rate'] ?? worker['rate_per_hour'] ?? 200;
                      final area = worker['area']?.toString() ?? 'Mysuru';
                      final initial = name.isNotEmpty ? name[0].toUpperCase() : 'W';

                      return Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: const Color(0xFF334155),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.25),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                // Avatar with rating badge
                                Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    Container(
                                      width: 46,
                                      height: 46,
                                      decoration: BoxDecoration(
                                        color: UserAppTheme.primaryBlue.withValues(alpha: 0.2),
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: UserAppTheme.primaryBlue.withValues(alpha: 0.5),
                                          width: 1.5,
                                        ),
                                      ),
                                      alignment: Alignment.center,
                                      child: Text(
                                        initial,
                                        style: UserAppTheme.heading(
                                          size: 18,
                                          weight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                    Positioned(
                                      bottom: 0,
                                      right: 0,
                                      child: Container(
                                        width: 12,
                                        height: 12,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF10B981),
                                          shape: BoxShape.circle,
                                          border: Border.all(color: const Color(0xFF1E293B), width: 2),
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
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              name,
                                              style: UserAppTheme.heading(
                                                size: 14.5,
                                                weight: FontWeight.bold,
                                                color: Colors.white,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          const Icon(Icons.verified_rounded, color: Color(0xFF10B981), size: 16),
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        area.isNotEmpty ? '$skill • $area' : skill,
                                        style: UserAppTheme.body(
                                          size: 11.5,
                                          color: const Color(0xFF94A3B8),
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 12),
                            const Divider(height: 1, color: Color(0xFF334155)),
                            const SizedBox(height: 10),

                            // Metrics: Rating, Completed Jobs, Rate
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFEF3C7).withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.star_rounded, size: 14, color: Color(0xFFFBBF24)),
                                      const SizedBox(width: 3),
                                      Text(
                                        rating.toStringAsFixed(1),
                                        style: UserAppTheme.label(
                                          size: 11.5,
                                          color: const Color(0xFFFBBF24),
                                          weight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  '$totalJobs jobs completed',
                                  style: UserAppTheme.body(
                                    size: 11.5,
                                    color: const Color(0xFFCBD5E1),
                                    weight: FontWeight.w500,
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  '₹$hourlyRate/hr',
                                  style: UserAppTheme.body(
                                    size: 12.5,
                                    weight: FontWeight.bold,
                                    color: const Color(0xFF34D399),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 12),

                            // Request / Direct Book Button
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _isActioning
                                    ? null
                                    : () => _directAssignWorker(worker),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: UserAppTheme.primaryBlue,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  elevation: 0,
                                ),
                                child: Text(
                                  'Request This Pro',
                                  style: UserAppTheme.body(
                                    color: Colors.white,
                                    weight: FontWeight.bold,
                                    size: 13,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ).animate().fadeIn(delay: (index * 80).ms).slideY(begin: 0.05);
                    },
                  ),
                ],

                const SizedBox(height: 24),

                // Retry Search Button
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      setState(() => _matchingState = MatchingState.searching);
                      _startFallbackTimer();
                    },
                    icon: const Icon(Icons.refresh, color: Colors.white, size: 18),
                    label: Text(
                      'Retry Live Radar Search',
                      style: UserAppTheme.body(
                        color: Colors.white,
                        weight: FontWeight.bold,
                        size: 14,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.white30),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),

                const SizedBox(height: 14),
                _buildScheduleCard(),
                const SizedBox(height: 12),
                _buildCallbackCard(),
                const SizedBox(height: 20),

                Center(
                  child: TextButton(
                    onPressed: _cancelJob,
                    child: Text(
                      'Cancel & Go Home',
                      style: UserAppTheme.body(
                        size: 13,
                        color: UserAppTheme.urgentRed,
                        weight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ─── STATE B: WORKER ASSIGNED ────────────────────────────
  Widget _buildAssigned() {
    final worker = _workerData ?? {};
    final name = worker['name'] as String? ?? 'Worker';
    final specialty = worker['specialty'] as String? ?? _jobData['skill'] ?? 'Helper';
    final rating = worker['rating']?.toString() ?? '4.8';
    final jobsDone = worker['jobs_done']?.toString() ?? '14';
    final distance = worker['distance_km']?.toString() ?? '1.8';
    final eta = worker['eta_mins']?.toString() ?? '10';
    final initials = worker['initials'] as String? ?? (name.isNotEmpty ? name.substring(0, 1).toUpperCase() : 'W');

    return Stack(
      alignment: Alignment.topCenter,
      children: [
        Column(
          children: [
            // Success Header Banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: const BoxDecoration(
                gradient: UserAppTheme.successGradient,
              ),
              alignment: Alignment.center,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 72,
                    height: 72,
                    child: Stack(
                      alignment: Alignment.center,
                      clipBehavior: Clip.none,
                      children: [
                        Positioned(
                          width: 300,
                          height: 300,
                          child: AnimatedBuilder(
                            animation: CurvedAnimation(
                              parent: _celebrationController,
                              curve: const Interval(0.0, 0.6),
                            ),
                            builder: (context, _) {
                              return RepaintBoundary(
                                child: CustomPaint(
                                  size: const Size(300, 300),
                                  painter: ParticlePainter(
                                    progress: CurvedAnimation(
                                      parent: _celebrationController,
                                      curve: const Interval(0.0, 0.6),
                                    ).value,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        AnimatedBuilder(
                          animation: CurvedAnimation(
                            parent: _celebrationController,
                            curve: const Interval(0.0, 0.5, curve: Curves.elasticOut),
                          ),
                          builder: (context, child) {
                            return Transform.scale(
                              scale: CurvedAnimation(
                                parent: _celebrationController,
                                curve: const Interval(0.0, 0.5, curve: Curves.elasticOut),
                              ).value,
                              child: child,
                            );
                          },
                          child: RepaintBoundary(
                            child: SizedBox(
                              width: 64,
                              height: 64,
                              child: Lottie.asset(
                                'assets/lottie/checkmark_success.json',
                                repeat: false,
                                frameRate: const FrameRate(60),
                                errorBuilder: (context, error, stackTrace) => const Icon(Icons.check_circle, color: Colors.white, size: 48),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Shimmer.fromColors(
                        baseColor: Colors.white,
                        highlightColor: UserAppTheme.skyAccent,
                        period: const Duration(milliseconds: 1500),
                        child: Text(
                          'Expert matched & ready!',
                          style: UserAppTheme.heading(
                            size: 16,
                            weight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Review and accept below',
                        style: UserAppTheme.body(
                          size: 12,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Elegant Countdown Progress Bar
            AnimatedBuilder(
              animation: _acceptCountdown,
              builder: (context, _) {
                final secs = ((1.0 - _acceptCountdown.value) * 60).round();
                Color barColor = UserAppTheme.successGreen;
                if (secs <= 30) barColor = Colors.orange;
                if (secs <= 10) barColor = UserAppTheme.urgentRed;
                return Column(
                  children: [
                    LinearProgressIndicator(
                      value: 1.0 - _acceptCountdown.value,
                      minHeight: 6,
                      backgroundColor: UserAppTheme.divider,
                      valueColor: AlwaysStoppedAnimation<Color>(barColor),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      color: barColor.withValues(alpha: 0.08),
                      width: double.infinity,
                      alignment: Alignment.center,
                      child: Text(
                        'Accept within $secs seconds',
                        style: UserAppTheme.label(
                          size: 12,
                          weight: FontWeight.bold,
                          color: barColor,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 12),
                    // Worker card
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: UserAppTheme.surface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: UserAppTheme.divider, width: 1),
                        boxShadow: UserAppTheme.cardShadow,
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              // Avatar
                              Stack(
                                alignment: Alignment.center,
                                children: [
                                  AnimatedBuilder(
                                    animation: _avatarRippleController,
                                    builder: (context, child) {
                                      final progress = _avatarRippleController.value;
                                      final scale = 1.0 + (progress * 1.2);
                                      final opacity = (1.0 - progress).clamp(0.0, 1.0);
                                      return Opacity(
                                        opacity: opacity,
                                        child: Transform.scale(
                                          scale: scale,
                                          child: Container(
                                            width: 72,
                                            height: 72,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                color: const Color(0xFFFFD700).withValues(alpha: 0.5),
                                                width: 1.5,
                                              ),
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                  AnimatedBuilder(
                                    animation: _avatarRippleController,
                                    builder: (context, child) {
                                      final progress = (_avatarRippleController.value + 0.33) % 1.0;
                                      final scale = 1.0 + (progress * 1.2);
                                      final opacity = (1.0 - progress).clamp(0.0, 1.0);
                                      return Opacity(
                                        opacity: opacity,
                                        child: Transform.scale(
                                          scale: scale,
                                          child: Container(
                                            width: 72,
                                            height: 72,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                color: UserAppTheme.successGreen.withValues(alpha: 0.4),
                                                width: 1.5,
                                              ),
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                  Container(
                                    width: 72,
                                    height: 72,
                                    decoration: BoxDecoration(
                                      color: UserAppTheme.primaryBlue.withValues(alpha: 0.08),
                                      shape: BoxShape.circle,
                                      border: Border.all(color: UserAppTheme.primaryBlue.withValues(alpha: 0.2), width: 2),
                                      boxShadow: [
                                        BoxShadow(
                                          color: UserAppTheme.primaryBlue.withValues(alpha: 0.15),
                                          blurRadius: 10,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      initials,
                                      style: UserAppTheme.heading(
                                        size: 24,
                                        weight: FontWeight.bold,
                                        color: UserAppTheme.primaryBlue,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      name,
                                      style: UserAppTheme.heading(
                                        size: 18,
                                        weight: FontWeight.bold,
                                        color: UserAppTheme.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      specialty,
                                      style: UserAppTheme.body(
                                        size: 12,
                                        color: UserAppTheme.textSecondary,
                                        weight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    // Shimmer gold badge
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFEF08A),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: const Color(0xFFFACC15), width: 1.0),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.workspace_premium_rounded, color: Color(0xFFCA8A04), size: 12),
                                          const SizedBox(width: 4),
                                          Text(
                                            'Top 10% Partner',
                                            style: UserAppTheme.label(
                                              size: 10,
                                              color: const Color(0xFF854D0E),
                                              weight: FontWeight.bold,
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
                          const SizedBox(height: 20),
                          const Divider(color: UserAppTheme.divider, height: 1),
                          const SizedBox(height: 20),

                          // Stats Row (Modern Metric Cards)
                          Row(
                            children: [
                              Expanded(
                                child: _statCard(
                                  icon: Icons.star_rounded,
                                  value: rating,
                                  label: 'Rating',
                                  color: const Color(0xFFF59E0B),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _statCard(
                                  icon: Icons.check_circle_outline_rounded,
                                  value: jobsDone,
                                  label: 'Jobs Done',
                                  color: UserAppTheme.successGreen,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _statCard(
                                  icon: Icons.radar_rounded,
                                  value: '$distance km',
                                  label: 'Distance',
                                  color: UserAppTheme.primaryBlue,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),

                          // ETA Row Card
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            decoration: BoxDecoration(
                              color: UserAppTheme.background,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.directions_run_outlined, color: UserAppTheme.textSecondary, size: 18),
                                const SizedBox(width: 10),
                                Text(
                                  'Estimated Arrival',
                                  style: UserAppTheme.body(
                                    size: 13,
                                    color: UserAppTheme.textSecondary,
                                    weight: FontWeight.w600,
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  '~$eta mins',
                                  style: UserAppTheme.body(
                                    size: 14,
                                    weight: FontWeight.bold,
                                    color: UserAppTheme.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          // Price counter
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            decoration: BoxDecoration(
                              color: UserAppTheme.background,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.currency_rupee_rounded, color: UserAppTheme.successGreen, size: 18),
                                const SizedBox(width: 10),
                                Text(
                                  'Service Price',
                                  style: UserAppTheme.body(
                                    size: 13,
                                    color: UserAppTheme.textSecondary,
                                    weight: FontWeight.w600,
                                  ),
                                ),
                                const Spacer(),
                                AnimatedCounter(
                                  value: int.tryParse(_jobData['payment_amount']?.toString() ?? _jobData['amount']?.toString() ?? '350') ?? 350,
                                  prefix: '₹',
                                  fontSize: 15,
                                  color: UserAppTheme.successGreen,
                                  duration: const Duration(milliseconds: 700),
                                  curve: Curves.easeOutCubic,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    )
                    .animate(controller: _celebrationController)
                    .fadeIn(delay: 560.ms, duration: 400.ms)
                    .slideY(begin: 0.15, end: 0, delay: 560.ms, duration: 500.ms, curve: Curves.easeOutCubic),
                    const SizedBox(height: 32),

                    // Button CTA row (Accept Green Gradient, Decline Red Outline)
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: GestureDetector(
                            onTap: _isActioning ? null : _acceptWorker,
                            child: Container(
                              height: UserAppTheme.buttonHeight,
                              decoration: BoxDecoration(
                                gradient: _isActioning ? null : UserAppTheme.successGradient,
                                color: _isActioning ? const Color(0xFFE2E8F0) : null,
                                borderRadius: UserAppTheme.buttonBorderRadius,
                                boxShadow: _isActioning
                                    ? []
                                    : [
                                        BoxShadow(
                                          color: UserAppTheme.successGreen.withValues(alpha: 0.25),
                                          blurRadius: 15,
                                          offset: const Offset(0, 4),
                                        )
                                      ],
                              ),
                              alignment: Alignment.center,
                              child: _isActioning
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                                    )
                                  : Text(
                                      'Accept & Call Worker',
                                      style: UserAppTheme.body(
                                        color: Colors.white,
                                        weight: FontWeight.bold,
                                        size: 15,
                                      ),
                                    ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 1,
                          child: GestureDetector(
                            onTap: _isActioning ? null : _declineWorker,
                            child: Container(
                              height: UserAppTheme.buttonHeight,
                              decoration: BoxDecoration(
                                color: Colors.transparent,
                                borderRadius: UserAppTheme.buttonBorderRadius,
                                border: Border.all(color: UserAppTheme.urgentRed, width: 1.5),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                'Decline',
                                style: UserAppTheme.body(
                                  color: UserAppTheme.urgentRed,
                                  weight: FontWeight.bold,
                                  size: 15,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ).animate().fadeIn(delay: 150.ms),
                    const SizedBox(height: 16),
                    Center(
                      child: Text(
                        'Declining will put you back in search automatically.',
                        style: UserAppTheme.label(
                          size: 12,
                          color: Colors.white70,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ─── HELPERS ─────────────────────────────────────────────
  Widget _jobSummaryRow(IconData icon, String label, String value, {bool isUrgent = false}) {
    return Row(
      children: [
        Icon(icon, size: 18, color: UserAppTheme.textSecondary),
        const SizedBox(width: 10),
        Text(
          label,
          style: UserAppTheme.body(
            size: 13,
            color: UserAppTheme.textSecondary,
            weight: FontWeight.w600,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: UserAppTheme.body(
            size: 13,
            weight: FontWeight.bold,
            color: isUrgent ? UserAppTheme.urgentRed : UserAppTheme.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _statCard({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.12), width: 1),
      ),
      child: Column(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(height: 6),
          Text(
            value,
            style: UserAppTheme.heading(
              size: 15,
              weight: FontWeight.bold,
              color: UserAppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: UserAppTheme.label(
              size: 10,
              color: UserAppTheme.textSecondary,
              weight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _realtimeChannel?.unsubscribe();
    _fallbackTimer?.cancel();
    _fallbackCountTimer?.cancel();
    _acceptCountdown.dispose();
    _acceptPulse.dispose();
    _pulseController.dispose();
    _avatarRippleController.dispose();
    _lottieBgController.dispose();
    _orbitController.dispose();
    _dotController.dispose();
    _cardController.dispose();
    _counterController.dispose();
    _shimmerController.dispose();
    _celebrationController.dispose();
    _assignedShimmerController.dispose();
    _assignedBgController.dispose();
    super.dispose();
  }
}

class PulsingRadar extends StatefulWidget {
  final Color color;
  final String serviceType;
  const PulsingRadar({
    super.key,
    required this.color,
    required this.serviceType,
  });

  @override
  State<PulsingRadar> createState() => _PulsingRadarState();
}

class _PulsingRadarState extends State<PulsingRadar> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  IconData _getServiceIcon(String service) {
    final s = service.toLowerCase().replaceAll('_', ' ');
    if (s.contains('electrician') || s.contains('power outage') || s.contains('short circuit')) {
      return Icons.bolt_rounded;
    } else if (s.contains('plumber') || s.contains('plumbing') || s.contains('water') || s.contains('leakage') || s.contains('drain') || s.contains('toilet') || s.contains('pump')) {
      return Icons.plumbing_rounded;
    } else if (s.contains('laptop')) {
      return Icons.laptop_chromebook_rounded;
    } else if (s.contains('phone')) {
      return Icons.phone_android_rounded;
    } else if (s.contains('carpenter')) {
      return Icons.handyman_rounded;
    } else if (s.contains('painter')) {
      return Icons.format_paint_rounded;
    } else if (s.contains('ac ') || s.contains('air conditioning') || s.contains('ac_') || s.contains('ac breakdown')) {
      return Icons.ac_unit_rounded;
    } else if (s.contains('cleaning')) {
      return Icons.cleaning_services_rounded;
    } else if (s.contains('locked') || s.contains('key')) {
      return Icons.vpn_key_rounded;
    } else {
      return Icons.person_search_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 280,
      height: 280,
      child: Stack(
        alignment: Alignment.center,
        children: [
          _buildRing(0),
          _buildRing(0.33),
          _buildRing(0.66),
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: widget.color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: widget.color.withValues(alpha: 0.3),
                  blurRadius: 12,
                  spreadRadius: 4,
                )
              ],
            ),
            child: Icon(
              _getServiceIcon(widget.serviceType),
              color: Colors.white,
              size: 28,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRing(double delayFraction) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        double t = (_controller.value - delayFraction) % 1.0;
        double scale = 1.0 + (t * 1.5);
        double opacity = (1.0 - t) * 0.6;

        return Opacity(
          opacity: opacity.clamp(0.0, 1.0),
          child: Transform.scale(
            scale: scale,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: widget.color,
                  width: 2.0,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class TypewriterStatusText extends StatefulWidget {
  final String serviceType;
  const TypewriterStatusText({super.key, required this.serviceType});

  @override
  State<TypewriterStatusText> createState() => _TypewriterStatusTextState();
}

class _TypewriterStatusTextState extends State<TypewriterStatusText> {
  late List<String> _statuses;
  int _currentIndex = 0;
  String _displayText = '';
  Timer? _cycleTimer;
  Timer? _typewriterTimer;

  @override
  void initState() {
    super.initState();
    _initStatuses();
    _startCycle();
  }

  @override
  void didUpdateWidget(covariant TypewriterStatusText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.serviceType != widget.serviceType) {
      _initStatuses();
    }
  }

  void _initStatuses() {
    final displayService = widget.serviceType
        .replaceAll('_', ' ')
        .split(' ')
        .map((word) => word.isNotEmpty ? '${word[0].toUpperCase()}${word.substring(1)}' : '')
        .join(' ');
        
    _statuses = [
      'Scanning Mysuru coordinates...',
      'Locating active ${displayService}s...',
      'Checking live availability near you...',
      'Optimizing nearest routes...',
    ];
  }

  @override
  void dispose() {
    _cycleTimer?.cancel();
    _typewriterTimer?.cancel();
    super.dispose();
  }

  void _startCycle() {
    _typewriterEffect();
    _cycleTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (mounted) {
        setState(() {
          _currentIndex = (_currentIndex + 1) % _statuses.length;
        });
        _typewriterEffect();
      }
    });
  }

  void _typewriterEffect() {
    _typewriterTimer?.cancel();
    final fullText = _statuses[_currentIndex];
    int charIndex = 0;
    _displayText = '';
    _typewriterTimer = Timer.periodic(const Duration(milliseconds: 30), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (charIndex < fullText.length) {
        setState(() {
          _displayText += fullText[charIndex];
        });
        charIndex++;
      } else {
        timer.cancel();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 24,
      alignment: Alignment.center,
      child: Text(
        _displayText,
        style: UserAppTheme.body(
          size: 15,
          color: Colors.white,
          weight: FontWeight.w600,
        ),
      ),
    );
  }
}

class ParticlePainter extends CustomPainter {
  final double progress; // 0.0 to 1.0, use Interval(0.0, 0.6)
  final List<Color> colors = [
    UserAppTheme.skyAccent, UserAppTheme.primaryBlue,
    UserAppTheme.successGreen, UserAppTheme.skyAccent,
    UserAppTheme.primaryBlue, UserAppTheme.successGreen,
    UserAppTheme.skyAccent, UserAppTheme.primaryBlue,
  ];

  ParticlePainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    for (int i = 0; i < 8; i++) {
      final angle = (i * 45.0) * (pi / 180.0);
      final distance = progress * 100.0;
      final opacity = (1.0 - progress).clamp(0.0, 1.0);
      final x = center.dx + cos(angle) * distance;
      final y = center.dy + sin(angle) * distance;
      final paint = Paint()
        ..color = colors[i].withValues(alpha: opacity)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(x, y), 5.0 * (1 - progress * 0.5), paint);
    }
  }

  @override
  bool shouldRepaint(ParticlePainter old) => old.progress != progress;
}
