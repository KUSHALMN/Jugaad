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

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jugaad_mvp/features/user/screens/user_home_screen.dart';
import 'package:jugaad_mvp/core/theme/user_app_theme.dart';
import 'package:google_fonts/google_fonts.dart';

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
  bool _showAdvisory = true;
  String _selectedSort = 'Highest Rated';
  final Set<String> _favoriteWorkerIds = {};

  void _sortTopRatedWorkers(String sortType) {
    setState(() {
      _selectedSort = sortType;
      if (sortType == 'Highest Rated') {
        _topRatedWorkers.sort((a, b) {
          final double rA = double.tryParse(a['rating']?.toString() ?? '0') ?? 0;
          final double rB = double.tryParse(b['rating']?.toString() ?? '0') ?? 0;
          return rB.compareTo(rA);
        });
      } else if (sortType == 'Most Jobs') {
        _topRatedWorkers.sort((a, b) {
          final int jA = int.tryParse((a['total_jobs'] ?? a['totalJobsCompleted'])?.toString() ?? '0') ?? 0;
          final int jB = int.tryParse((b['total_jobs'] ?? b['totalJobsCompleted'])?.toString() ?? '0') ?? 0;
          return jB.compareTo(jA);
        });
      } else if (sortType == 'Nearest') {
        _topRatedWorkers.sort((a, b) {
          final double dA = double.tryParse(a['distance_km']?.toString() ?? '2.0') ?? 2.0;
          final double dB = double.tryParse(b['distance_km']?.toString() ?? '2.0') ?? 2.0;
          return dA.compareTo(dB);
        });
      }
    });
  }

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
          _topRatedWorkers = workers.isNotEmpty
              ? workers
              : SupabaseService.getMysoreFallbackWorkers(category: skill, limit: 8);
          _isLoadingTopRated = false;
        });
      }
    } catch (e) {
      print('[MATCHING] Error fetching top rated fallback workers: $e');
      if (mounted) {
        setState(() {
          _topRatedWorkers = SupabaseService.getMysoreFallbackWorkers(category: skill, limit: 8);
          _isLoadingTopRated = false;
        });
      }
    }
  }

  Future<void> _directAssignWorker(Map<String, dynamic> worker) async {
    final workerId = worker['id']?.toString() ?? '';
    final workerName = worker['name']?.toString() ?? 'Worker';

    HapticFeedback.mediumImpact();
    setState(() => _isActioning = true);

    try {
      if (widget.jobId.isNotEmpty) {
        try {
          // Update job with worker_id in Supabase
          await SupabaseConfig.client.from('jobs').update({
            'worker_id': workerId,
            'status': 'assigned',
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          }).eq('id', widget.jobId);
        } catch (dbErr) {
          debugPrint('[MATCHING] Direct assign worker_id notice (retrying status only): $dbErr');
          try {
            await SupabaseConfig.client.from('jobs').update({
              'status': 'assigned',
              'updated_at': DateTime.now().toUtc().toIso8601String(),
            }).eq('id', widget.jobId);
          } catch (_) {}
        }
      }

      if (mounted) {
        if (context.mounted) {
          try {
            ScaffoldMessenger.maybeOf(context)?.showSnackBar(
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
          } catch (_) {}
        }
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
        if (context.mounted) {
          try {
            ScaffoldMessenger.maybeOf(context)?.showSnackBar(
              SnackBar(content: Text('Could not request worker: $e')),
            );
          } catch (_) {}
        }
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
    if (context.mounted) {
      try {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
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
      } catch (_) {}
    }
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
        if (context.mounted) {
          try {
            if (e.toString().contains('409')) {
              ScaffoldMessenger.maybeOf(context)?.showSnackBar(
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
            } else {
              ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                SnackBar(content: Text('Error: $e')),
              );
            }
          } catch (_) {}
        }
        if (e.toString().contains('409')) {
          setState(() => _matchingState = MatchingState.searching);
          _startFallbackTimer();
        }
      }
    }
  }

  Future<void> _declineWorker() async {
    HapticFeedback.mediumImpact();
    setState(() => _isActioning = true);
    try {
      await ApiService().declineJob(widget.jobId).timeout(const Duration(seconds: 4));
    } catch (e) {
      print('[MATCHING] Error declining job: $e');
    }
    if (mounted) {
      setState(() {
        _isActioning = false;
        _matchingState = MatchingState.searching;
      });
      _acceptCountdown.reset();
      _startFallbackTimer();
      if (context.mounted) {
        try {
          ScaffoldMessenger.maybeOf(context)?.showSnackBar(
            SnackBar(
              content: Text(
                'Worker declined. Resuming radar search...',
                style: UserAppTheme.body(color: Colors.white),
              ),
              backgroundColor: const Color(0xFF0F172A),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              duration: const Duration(seconds: 2),
            ),
          );
        } catch (_) {}
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
      if (context.mounted) {
        try {
          ScaffoldMessenger.maybeOf(context)?.showSnackBar(
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
        } catch (_) {}
      }
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
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (_matchingState == MatchingState.assigned) {
          _declineWorker();
        } else {
          _cancelJob();
        }
      },
      child: AnimatedBuilder(
        animation: _assignedBgController,
        builder: (context, child) {
          final isNoWorkers = _matchingState == MatchingState.noWorkersFound;
          final isAssigned = _matchingState == MatchingState.assigned;
          return Container(
            decoration: BoxDecoration(
              color: (isNoWorkers || isAssigned)
                  ? const Color(0xFFF8FAFC)
                  : ColorTween(
                      begin: UserAppTheme.background,
                      end: const Color(0xFFF8FAFC),
                    ).evaluate(_assignedBgController),
            ),
            child: Scaffold(
              backgroundColor: Colors.transparent,
              body: Stack(
                children: [
                  // Radial Gradient Base Layer (only for radar search states)
                  if (!isNoWorkers && !isAssigned)
                    Positioned.fill(
                      child: Opacity(
                        opacity: 1.0,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: RadialGradient(
                              center: const Alignment(0, 0.15),
                              colors: (_jobData['job_type'] == 'emergency'
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
      ),
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

  // ─── STATE C: NO WORKERS FOUND (REDESIGNED) ───────────────
  Widget _buildNoWorkersFound() {
    final skill = _jobData['skill_required'] as String? ??
        _jobData['skill'] as String? ??
        _jobData['title'] as String? ??
        'Service';

    final jobCity = _jobData['city'] as String? ?? 'Mysuru';

    return Container(
      color: const Color(0xFFF8FAFC), // Crisp light page background matching mockup
      width: double.infinity,
      height: double.infinity,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1040),
          child: Column(
            children: [
              // 1. Top App Bar (Back Button + Title + Location Dropdown)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
                child: Row(
                  children: [
                    // Circular Back Button
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: IconButton(
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          context.go('/user/home');
                        },
                        icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF0F172A), size: 20),
                        padding: EdgeInsets.zero,
                      ),
                    ),
                    const SizedBox(width: 14),

                    // Title & Subtitle
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Available Service Specialists',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 19,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF0F172A),
                              letterSpacing: -0.3,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Top-rated specialists across $jobCity',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFF64748B),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),

                    // Location Pill (Mysuru ∨)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.03),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.location_on_rounded, color: Color(0xFF059669), size: 16),
                          const SizedBox(width: 5),
                          Text(
                            jobCity,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(width: 3),
                          const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF64748B), size: 18),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // 2. Scrollable Body
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // High demand in your area Advisory Banner (Dismissable)
                      if (_showAdvisory) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFFBEB), // Soft Amber Cream
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFFDE68A), width: 1.2),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 38,
                                height: 38,
                                decoration: const BoxDecoration(
                                  color: Color(0xFFFEF3C7),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.bolt_rounded, color: Color(0xFFD97706), size: 22),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'High demand in your area',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w800,
                                        color: const Color(0xFFB45309),
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Nearby specialists are busy. These top-rated pros are available across $jobCity for quick service.',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 12,
                                        color: const Color(0xFF475569),
                                        fontWeight: FontWeight.w500,
                                        height: 1.25,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              GestureDetector(
                                onTap: () => setState(() => _showAdvisory = false),
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.6),
                                    shape: BoxShape.circle,
                                    border: Border.all(color: const Color(0xFFFDE68A)),
                                  ),
                                  child: const Icon(Icons.close_rounded, color: Color(0xFF94A3B8), size: 16),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Top-Rated Section Header & Sort Menu
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Top-Rated Service Pros',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF0F172A),
                                  letterSpacing: -0.3,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                width: 36,
                                height: 3,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF059669),
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            ],
                          ),

                          // Sort Button
                          PopupMenuButton<String>(
                            onSelected: _sortTopRatedWorkers,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            itemBuilder: (context) => [
                              const PopupMenuItem(value: 'Highest Rated', child: Text('Highest Rated')),
                              const PopupMenuItem(value: 'Most Jobs', child: Text('Most Experienced')),
                              const PopupMenuItem(value: 'Nearest', child: Text('Nearest to Me')),
                            ],
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.03),
                                    blurRadius: 4,
                                    offset: const Offset(0, 1),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.tune_rounded, color: Color(0xFF0F172A), size: 14),
                                  const SizedBox(width: 6),
                                  Text(
                                    _selectedSort,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFF0F172A),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF64748B), size: 16),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 14),

                      // Workers List
                      if (_isLoadingTopRated) ...[
                        const SizedBox(height: 60),
                        const Center(
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF059669)),
                          ),
                        ),
                        const SizedBox(height: 60),
                      ] else if (_topRatedWorkers.isEmpty) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(28),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          alignment: Alignment.center,
                          child: Column(
                            children: [
                              const Icon(Icons.person_search_rounded, size: 44, color: Color(0xFF94A3B8)),
                              const SizedBox(height: 12),
                              Text(
                                'No available specialists in this category right now',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF0F172A),
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Try expanding search or scheduling a booking slot for later.',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12,
                                  color: const Color(0xFF64748B),
                                ),
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
                          separatorBuilder: (context, index) => const SizedBox(height: 14),
                          itemBuilder: (context, index) {
                            final worker = _topRatedWorkers[index];
                            return _buildSpecialistCard(worker, index, skill);
                          },
                        ),
                      ],

                      const SizedBox(height: 20),

                      // Retry Live Radar Search Button (Clean light styled)
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            HapticFeedback.lightImpact();
                            setState(() => _matchingState = MatchingState.searching);
                            _startFallbackTimer();
                          },
                          icon: const Icon(Icons.refresh_rounded, color: Color(0xFF0F172A), size: 18),
                          label: Text(
                            'Retry Live Radar Search',
                            style: GoogleFonts.plusJakartaSans(
                              color: const Color(0xFF0F172A),
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            backgroundColor: Colors.white,
                            side: const BorderSide(color: Color(0xFFE2E8F0), width: 1.2),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                          ),
                        ),
                      ),

                      const SizedBox(height: 14),
                      _buildScheduleCard(),
                      const SizedBox(height: 12),
                      _buildCallbackCard(),
                      const SizedBox(height: 18),

                      Center(
                        child: TextButton(
                          onPressed: _cancelJob,
                          child: Text(
                            'Cancel & Go Home',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13,
                              color: const Color(0xFFEF4444),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── SPECIALIST CARD COMPONENT (MOCKUP DESIGN) ───────────────
  Widget _buildSpecialistCard(Map<String, dynamic> worker, int index, String fallbackSkill) {
    final workerId = worker['id']?.toString() ?? '$index';
    final name = worker['name']?.toString() ?? 'Specialist';
    final rating = double.tryParse(worker['rating']?.toString() ?? '4.9') ?? 4.9;
    final totalJobs = worker['total_jobs'] ?? worker['totalJobsCompleted'] ?? 50;
    final hourlyRate = worker['hourly_rate'] ?? worker['rate_per_hour'] ?? 200;
    final rawCategory = worker['category'] as String? ?? 
                        worker['work_category'] as String? ?? 
                        worker['specialty'] as String? ?? 
                        fallbackSkill;
    final customImage = worker['image_url'] as String? ?? worker['service_image'] as String?;

    final categoryMeta = CategoryMetadata.resolve(
      rawCategory: rawCategory,
      customImageUrl: customImage,
    );

    final distanceKm = worker['distance_km']?.toString() ?? 
        (index == 0 ? '2.3' : (index == 1 ? '3.1' : (index == 2 ? '1.8' : '2.5')));
    final responseTime = (index == 0 ? 2 : (index == 1 ? 3 : 4));
    final initial = name.isNotEmpty ? name.substring(0, 1).toUpperCase() : 'S';
    final isFav = _favoriteWorkerIds.contains(workerId);

    // Dynamic avatar color based on index
    final avatarColors = [
      const Color(0xFF0F172A), // Dark Slate
      const Color(0xFF064E3B), // Dark Forest
      const Color(0xFFC2410C), // Dark Orange
      const Color(0xFF1D4ED8), // Deep Blue
    ];
    final avatarBg = avatarColors[index % avatarColors.length];

    final iconData = _getCategoryIcon(rawCategory);
    final iconBg = _getCategoryIconBg(rawCategory);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 680;

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFF1F5F9), width: 1.2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: isWide
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // 1. Left Category Showcase Photo with floating badge
                    _buildCardShowcasePhoto(
                      meta: categoryMeta,
                      iconData: iconData,
                      iconBg: iconBg,
                      width: 150,
                      height: 100,
                    ),
                    const SizedBox(width: 16),

                    // 2. Middle Pro Details
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (index == 0) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEF3C7),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.emoji_events_rounded, color: Color(0xFFD97706), size: 12),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Best Match',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w800,
                                      color: const Color(0xFFB45309),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 4),
                          ],

                          // Avatar + Name + Subtitle
                          Row(
                            children: [
                              Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  Container(
                                    width: 42,
                                    height: 42,
                                    decoration: BoxDecoration(
                                      color: avatarBg,
                                      shape: BoxShape.circle,
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      initial,
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    bottom: 0,
                                    right: 0,
                                    child: Container(
                                      width: 10,
                                      height: 10,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF10B981),
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
                                      name,
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                        color: const Color(0xFF0F172A),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      categoryMeta.title,
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
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
                          const SizedBox(height: 8),

                          // Badges Row
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              _buildPillBadge(
                                icon: Icons.star_rounded,
                                iconColor: const Color(0xFFF59E0B),
                                label: rating.toStringAsFixed(1),
                                bgColor: const Color(0xFFFEF9C3),
                                textColor: const Color(0xFF854D0E),
                              ),
                              _buildPillBadge(
                                icon: Icons.business_center_rounded,
                                iconColor: const Color(0xFF64748B),
                                label: '$totalJobs jobs',
                                bgColor: const Color(0xFFF1F5F9),
                                textColor: const Color(0xFF334155),
                              ),
                              _buildPillBadge(
                                icon: Icons.location_on_rounded,
                                iconColor: const Color(0xFF64748B),
                                label: '$distanceKm km away',
                                bgColor: const Color(0xFFF1F5F9),
                                textColor: const Color(0xFF334155),
                              ),
                              if (index == 0)
                                _buildPillBadge(
                                  icon: Icons.bolt_rounded,
                                  iconColor: const Color(0xFF16A34A),
                                  label: 'Available now',
                                  bgColor: const Color(0xFFDCFCE7),
                                  textColor: const Color(0xFF15803D),
                                )
                              else
                                _buildPillBadge(
                                  icon: Icons.access_time_rounded,
                                  iconColor: const Color(0xFF16A34A),
                                  label: 'Usually responds in ~$responseTime min',
                                  bgColor: const Color(0xFFDCFCE7),
                                  textColor: const Color(0xFF15803D),
                                ),
                            ],
                          ),

                          if (index == 0) ...[
                            const SizedBox(height: 5),
                            Row(
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF16A34A),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  'Usually responds in ~$responseTime min',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF16A34A),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),

                    // 3. Right Column: Verified Badge + Price + Book This Pro & Heart
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Verified Badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDCFCE7),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFFBBF7D0)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 12),
                              const SizedBox(width: 4),
                              Text(
                                'Verified',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF15803D),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Price
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              '₹$hourlyRate',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 19,
                                fontWeight: FontWeight.w900,
                                color: const Color(0xFF047857),
                              ),
                            ),
                            Text(
                              '/hr',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                        Text(
                          'Fair & transparent pricing',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF94A3B8),
                          ),
                        ),
                        const SizedBox(height: 10),

                        // Actions: Book This Pro + Heart
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            GestureDetector(
                              onTap: _isActioning ? null : () => _directAssignWorker(worker),
                              child: Container(
                                height: 40,
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                decoration: BoxDecoration(
                                  color: _isActioning ? const Color(0xFF94A3B8) : const Color(0xFF059669),
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF059669).withValues(alpha: 0.25),
                                      blurRadius: 8,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                alignment: Alignment.center,
                                child: _isActioning
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                      )
                                    : Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            'Book This Pro',
                                            style: GoogleFonts.plusJakartaSans(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w700,
                                              fontSize: 13,
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 15),
                                        ],
                                      ),
                              ),
                            ),
                            const SizedBox(width: 8),

                            // Heart button
                            GestureDetector(
                              onTap: () {
                                HapticFeedback.lightImpact();
                                setState(() {
                                  if (isFav) {
                                    _favoriteWorkerIds.remove(workerId);
                                  } else {
                                    _favoriteWorkerIds.add(workerId);
                                  }
                                });
                              },
                              child: Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                ),
                                alignment: Alignment.center,
                                child: Icon(
                                  isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                                  color: isFav ? const Color(0xFFEF4444) : const Color(0xFF64748B),
                                  size: 18,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                )
              : Column(
                  // Mobile stacked layout
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildCardShowcasePhoto(
                          meta: categoryMeta,
                          iconData: iconData,
                          iconBg: iconBg,
                          width: 100,
                          height: 80,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  if (index == 0) ...[
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFEF3C7),
                                        borderRadius: BorderRadius.circular(5),
                                      ),
                                      child: Text(
                                        '🏆 Best Match',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.w800,
                                          color: const Color(0xFFB45309),
                                        ),
                                      ),
                                    ),
                                    const Spacer(),
                                  ] else
                                    const Spacer(),

                                  // Verified
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFDCFCE7),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 10),
                                        const SizedBox(width: 3),
                                        Text(
                                          'Verified',
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 9.5,
                                            fontWeight: FontWeight.w700,
                                            color: const Color(0xFF15803D),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                name,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF0F172A),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                categoryMeta.title,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
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

                    const SizedBox(height: 10),
                    // Metrics Wrap
                    Wrap(
                      spacing: 5,
                      runSpacing: 4,
                      children: [
                        _buildPillBadge(
                          icon: Icons.star_rounded,
                          iconColor: const Color(0xFFF59E0B),
                          label: rating.toStringAsFixed(1),
                          bgColor: const Color(0xFFFEF9C3),
                          textColor: const Color(0xFF854D0E),
                        ),
                        _buildPillBadge(
                          icon: Icons.business_center_rounded,
                          iconColor: const Color(0xFF64748B),
                          label: '$totalJobs jobs',
                          bgColor: const Color(0xFFF1F5F9),
                          textColor: const Color(0xFF334155),
                        ),
                        _buildPillBadge(
                          icon: Icons.location_on_rounded,
                          iconColor: const Color(0xFF64748B),
                          label: '$distanceKm km',
                          bgColor: const Color(0xFFF1F5F9),
                          textColor: const Color(0xFF334155),
                        ),
                        _buildPillBadge(
                          icon: Icons.access_time_rounded,
                          iconColor: const Color(0xFF16A34A),
                          label: '~$responseTime min',
                          bgColor: const Color(0xFFDCFCE7),
                          textColor: const Color(0xFF15803D),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),
                    const Divider(height: 1, color: Color(0xFFF1F5F9)),
                    const SizedBox(height: 10),

                    // Bottom Row: Price + Book button + Heart
                    Row(
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  '₹$hourlyRate',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w900,
                                    color: const Color(0xFF047857),
                                  ),
                                ),
                                Text(
                                  '/hr',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              'Fair & transparent',
                              style: GoogleFonts.plusJakartaSans(fontSize: 9.5, color: const Color(0xFF94A3B8)),
                            ),
                          ],
                        ),
                        const Spacer(),
                        GestureDetector(
                          onTap: _isActioning ? null : () => _directAssignWorker(worker),
                          child: Container(
                            height: 38,
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            decoration: BoxDecoration(
                              color: _isActioning ? const Color(0xFF94A3B8) : const Color(0xFF059669),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            alignment: Alignment.center,
                            child: _isActioning
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 1.8),
                                  )
                                : Row(
                                    children: [
                                      Text(
                                        'Book This Pro',
                                        style: GoogleFonts.plusJakartaSans(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 12,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 14),
                                    ],
                                  ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            setState(() {
                              if (isFav) {
                                _favoriteWorkerIds.remove(workerId);
                              } else {
                                _favoriteWorkerIds.add(workerId);
                              }
                            });
                          },
                          child: Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            alignment: Alignment.center,
                            child: Icon(
                              isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                              color: isFav ? const Color(0xFFEF4444) : const Color(0xFF64748B),
                              size: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
        );
      },
    );
  }

  Widget _buildCardShowcasePhoto({
    required CategoryMetadata meta,
    required IconData iconData,
    required Color iconBg,
    required double width,
    required double height,
  }) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(13),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              meta.imageUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Container(
                color: const Color(0xFFF1F5F9),
                alignment: Alignment.center,
                child: const Icon(Icons.build_circle_rounded, color: Color(0xFF94A3B8), size: 32),
              ),
            ),
            // Bottom-left circular floating category badge
            Positioned(
              bottom: 6,
              left: 6,
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: iconBg,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(iconData, color: Colors.white, size: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPillBadge({
    required IconData icon,
    required Color iconColor,
    required String label,
    required Color bgColor,
    required Color textColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: iconColor, size: 11),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }

  IconData _getCategoryIcon(String raw) {
    final lower = raw.toLowerCase();
    if (lower.contains('ro') || lower.contains('water') || lower.contains('purifier')) {
      return Icons.water_drop_rounded;
    } else if (lower.contains('ac') || lower.contains('cool')) {
      return Icons.ac_unit_rounded;
    } else if (lower.contains('electric')) {
      return Icons.bolt_rounded;
    } else if (lower.contains('plumb')) {
      return Icons.plumbing_rounded;
    } else if (lower.contains('carpent')) {
      return Icons.carpenter_rounded;
    } else if (lower.contains('laptop') || lower.contains('phone')) {
      return Icons.devices_rounded;
    }
    return Icons.build_rounded;
  }

  Color _getCategoryIconBg(String raw) {
    final lower = raw.toLowerCase();
    if (lower.contains('ro') || lower.contains('water')) {
      return const Color(0xFF2563EB); // Royal Blue
    } else if (lower.contains('ac') || lower.contains('cool')) {
      return const Color(0xFF0284C7); // Sky Blue
    } else if (lower.contains('electric')) {
      return const Color(0xFFF59E0B); // Amber / Yellow
    } else if (lower.contains('plumb')) {
      return const Color(0xFF0891B2); // Cyan
    } else if (lower.contains('carpent')) {
      return const Color(0xFFD97706); // Warm Amber
    } else if (lower.contains('laptop') || lower.contains('phone')) {
      return const Color(0xFF7C3AED); // Violet
    }
    return const Color(0xFF10B981); // Emerald
  }


  // ─── STATE B: WORKER ASSIGNED (REDESIGNED) ───────────────────
  Widget _buildAssigned() {
    final worker = _workerData ?? {};
    final name = (worker['name'] as String? ?? 'SAN TECHNOLOGIES').trim();
    final rawCategory = worker['specialty'] as String? ?? 
                        _jobData['skill_required'] as String? ?? 
                        _jobData['skill'] as String? ?? 
                        _jobData['title'] as String? ?? 
                        'ro_service';
    final customImage = _jobData['image_url'] as String? ?? 
                        _jobData['category_image'] as String? ?? 
                        worker['image_url'] as String? ?? 
                        worker['service_image'] as String?;

    final categoryMeta = CategoryMetadata.resolve(
      rawCategory: rawCategory,
      customImageUrl: customImage,
    );

    final rating = worker['rating']?.toString() ?? '5.0';
    final jobsDone = worker['jobs_done']?.toString() ?? worker['total_jobs']?.toString() ?? '440';
    final distance = worker['distance_km']?.toString() ?? '2.5';
    final eta = worker['eta_mins']?.toString() ?? '15';
    final initials = worker['initials'] as String? ?? (name.isNotEmpty ? name.substring(0, 1).toUpperCase() : 'S');
    final amount = int.tryParse(_jobData['payment_amount']?.toString() ?? _jobData['amount']?.toString() ?? '350') ?? 350;

    return Container(
      color: const Color(0xFFF8FAFC), // Clean white/light theme page background
      width: double.infinity,
      height: double.infinity,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1040),
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Top "Back to Search" Row
                Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: Row(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: IconButton(
                          onPressed: _isActioning ? null : _declineWorker,
                          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF0F172A), size: 20),
                          tooltip: 'Back to Search',
                          padding: const EdgeInsets.all(8),
                          constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Back to Search',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF475569),
                        ),
                      ),
                    ],
                  ),
                ),
                // 1. Top Mint-Green Header Card
                _buildTopMatchHeaderCard(),
                const SizedBox(height: 14),

                // 2. Main White Presentation Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 20,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final isWide = constraints.maxWidth >= 720;

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ── TOP PROFILE / SHOWCASE / MAP ROW ──
                          if (isWide)
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                // Left: Worker Profile Info
                                Expanded(
                                  flex: 5,
                                  child: _buildWorkerProfileInfo(
                                    name: name,
                                    initials: initials,
                                    categoryTitle: categoryMeta.title,
                                    serviceKey: categoryMeta.serviceKey,
                                  ),
                                ),
                                const SizedBox(width: 14),

                                // Center: Category Showcase Photo
                                Expanded(
                                  flex: 3,
                                  child: _buildCategoryShowcaseImage(categoryMeta),
                                ),
                                const SizedBox(width: 14),

                                // Right: Mini Live Map Card
                                Expanded(
                                  flex: 4,
                                  child: _buildMiniMapCard(distance: distance),
                                ),
                              ],
                            )
                          else ...[
                            // Mobile stacked layout
                            _buildWorkerProfileInfo(
                              name: name,
                              initials: initials,
                              categoryTitle: categoryMeta.title,
                              serviceKey: categoryMeta.serviceKey,
                            ),
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildCategoryShowcaseImage(categoryMeta),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _buildMiniMapCard(distance: distance),
                                ),
                              ],
                            ),
                          ],

                          const SizedBox(height: 18),

                          // ── 4 METRIC CARDS ROW ──
                          if (isWide)
                            Row(
                              children: [
                                Expanded(
                                  child: _buildMetricCard(
                                    icon: Icons.star_rounded,
                                    iconBg: const Color(0xFFFEF3C7),
                                    iconColor: const Color(0xFFF59E0B),
                                    title: rating,
                                    subtitle: 'Rating (128+ reviews)',
                                    showStars: true,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _buildMetricCard(
                                    icon: Icons.work_rounded,
                                    iconBg: const Color(0xFFEFF6FF),
                                    iconColor: const Color(0xFF3B82F6),
                                    title: '$jobsDone+',
                                    subtitle: 'Jobs Done',
                                    chipLabel: 'Experienced',
                                    chipBg: const Color(0xFFEFF6FF),
                                    chipColor: const Color(0xFF2563EB),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _buildMetricCard(
                                    icon: Icons.location_on_rounded,
                                    iconBg: const Color(0xFFFEE2E2),
                                    iconColor: const Color(0xFFEF4444),
                                    title: '$distance km',
                                    subtitle: 'Distance from you',
                                    chipLabel: 'Nearby',
                                    chipBg: const Color(0xFFFEE2E2),
                                    chipColor: const Color(0xFFDC2626),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _buildMetricCard(
                                    icon: Icons.currency_rupee_rounded,
                                    iconBg: const Color(0xFFDCFCE7),
                                    iconColor: const Color(0xFF16A34A),
                                    title: '₹$amount',
                                    subtitle: 'Service Price',
                                    chipLabel: 'Transparent pricing',
                                    chipBg: const Color(0xFFDCFCE7),
                                    chipColor: const Color(0xFF15803D),
                                    isPrice: true,
                                    numericPrice: amount,
                                  ),
                                ),
                              ],
                            )
                          else ...[
                            // 2x2 Grid on Mobile
                            Row(
                              children: [
                                Expanded(
                                  child: _buildMetricCard(
                                    icon: Icons.star_rounded,
                                    iconBg: const Color(0xFFFEF3C7),
                                    iconColor: const Color(0xFFF59E0B),
                                    title: rating,
                                    subtitle: 'Rating (128+ reviews)',
                                    showStars: true,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _buildMetricCard(
                                    icon: Icons.work_rounded,
                                    iconBg: const Color(0xFFEFF6FF),
                                    iconColor: const Color(0xFF3B82F6),
                                    title: '$jobsDone+',
                                    subtitle: 'Jobs Done',
                                    chipLabel: 'Experienced',
                                    chipBg: const Color(0xFFEFF6FF),
                                    chipColor: const Color(0xFF2563EB),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildMetricCard(
                                    icon: Icons.location_on_rounded,
                                    iconBg: const Color(0xFFFEE2E2),
                                    iconColor: const Color(0xFFEF4444),
                                    title: '$distance km',
                                    subtitle: 'Distance from you',
                                    chipLabel: 'Nearby',
                                    chipBg: const Color(0xFFFEE2E2),
                                    chipColor: const Color(0xFFDC2626),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _buildMetricCard(
                                    icon: Icons.currency_rupee_rounded,
                                    iconBg: const Color(0xFFDCFCE7),
                                    iconColor: const Color(0xFF16A34A),
                                    title: '₹$amount',
                                    subtitle: 'Service Price',
                                    chipLabel: 'Transparent pricing',
                                    chipBg: const Color(0xFFDCFCE7),
                                    chipColor: const Color(0xFF15803D),
                                    isPrice: true,
                                    numericPrice: amount,
                                  ),
                                ),
                              ],
                            ),
                          ],

                          const SizedBox(height: 16),

                          // ── ESTIMATED ARRIVAL BAR ──
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 38,
                                  height: 38,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEFF6FF),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(
                                    Icons.local_shipping_rounded,
                                    color: Color(0xFF2563EB),
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Estimated Arrival',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: const Color(0xFF0F172A),
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      Text(
                                        'Worker will reach your location in',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 11,
                                          color: const Color(0xFF64748B),
                                          fontWeight: FontWeight.w500,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.access_time_rounded,
                                      size: 19,
                                      color: Color(0xFF0F172A),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      '~ $eta mins',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                        color: const Color(0xFF0F172A),
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    const Icon(
                                      Icons.chevron_right_rounded,
                                      size: 20,
                                      color: Color(0xFF94A3B8),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 18),

                          // ── ACTION BUTTONS ROW ──
                          Row(
                            children: [
                              // Accept & Call Worker (Dark Slate/Black Button)
                              Expanded(
                                flex: isWide ? 4 : 2,
                                child: GestureDetector(
                                  onTap: _isActioning ? null : _acceptWorker,
                                  child: Container(
                                    height: 52,
                                    decoration: BoxDecoration(
                                      color: _isActioning ? const Color(0xFF94A3B8) : const Color(0xFF0F172A),
                                      borderRadius: BorderRadius.circular(14),
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(0xFF0F172A).withValues(alpha: 0.25),
                                          blurRadius: 12,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    padding: const EdgeInsets.symmetric(horizontal: 14),
                                    child: _isActioning
                                        ? const Center(
                                            child: SizedBox(
                                              height: 20,
                                              width: 20,
                                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.2),
                                            ),
                                          )
                                        : Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              const Icon(Icons.call_rounded, color: Colors.white, size: 18),
                                              const SizedBox(width: 8),
                                              Flexible(
                                                child: Text(
                                                  'Accept & Call Worker',
                                                  style: GoogleFonts.plusJakartaSans(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.w700,
                                                    fontSize: 14,
                                                    letterSpacing: 0.2,
                                                  ),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                              const SizedBox(width: 4),
                                              const Icon(Icons.chevron_right_rounded, color: Colors.white70, size: 20),
                                            ],
                                          ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),

                              // Decline (Clean White Button with Grey Border)
                              Expanded(
                                flex: 1,
                                child: GestureDetector(
                                  onTap: _isActioning ? null : _declineWorker,
                                  behavior: HitTestBehavior.opaque,
                                  child: Container(
                                    height: 52,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
                                    ),
                                    alignment: Alignment.center,
                                    child: _isActioning
                                        ? const SizedBox(
                                            height: 20,
                                            width: 20,
                                            child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF64748B)),
                                          )
                                        : Text(
                                            'Decline',
                                            style: GoogleFonts.plusJakartaSans(
                                              color: const Color(0xFF0F172A),
                                              fontWeight: FontWeight.w700,
                                              fontSize: 14,
                                            ),
                                          ),
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 12),
                          Center(
                            child: Text(
                              'Declining will put you back in search automatically.',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                color: const Color(0xFF64748B),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── TOP MINT GREEN STATUS CARD ───────────────────────────────
  Widget _buildTopMatchHeaderCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFDCFCE7), width: 1.5),
      ),
      child: AnimatedBuilder(
        animation: _acceptCountdown,
        builder: (context, _) {
          final secs = ((1.0 - _acceptCountdown.value) * 60).round();
          final progress = (1.0 - _acceptCountdown.value).clamp(0.0, 1.0);

          return LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 600;

              final leftSection = Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: const BoxDecoration(
                      color: Color(0xFF16A34A),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.check_rounded, color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Expert matched & ready!',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF0F172A),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Review the details below and accept to connect.',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            color: const Color(0xFF64748B),
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              );

              final rightSection = Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.access_time_rounded,
                    color: Color(0xFF0F172A),
                    size: 24,
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Accept within',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                      Text(
                        '$secs seconds',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 4),
                      SizedBox(
                        width: 120,
                        height: 5,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: progress,
                            backgroundColor: const Color(0xFFE2E8F0),
                            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF0F172A)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              );

              if (isWide) {
                return Row(
                  children: [
                    Expanded(child: leftSection),
                    Container(height: 38, width: 1, color: const Color(0xFFE2E8F0)),
                    const SizedBox(width: 16),
                    rightSection,
                  ],
                );
              } else {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    leftSection,
                    const SizedBox(height: 12),
                    const Divider(color: Color(0xFFE2E8F0), height: 1),
                    const SizedBox(height: 10),
                    rightSection,
                  ],
                );
              }
            },
          );
        },
      ),
    );
  }

  // ── WORKER PROFILE INFO WIDGET ──────────────────────────────
  Widget _buildWorkerProfileInfo({
    required String name,
    required String initials,
    required String categoryTitle,
    required String serviceKey,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Avatar with verified badge
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                color: const Color(0xFFDBEAFE),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFBFDBFE), width: 1.5),
              ),
              alignment: Alignment.center,
              child: Text(
                initials,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF2563EB),
                ),
              ),
            ),
            Positioned(
              right: -1,
              bottom: 0,
              child: Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: const Color(0xFF16A34A),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: const Icon(Icons.check_rounded, color: Colors.white, size: 13),
              ),
            ),
          ],
        ),
        const SizedBox(width: 14),

        // Text details & badges
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0F172A),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                categoryTitle,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF475569),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                serviceKey,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  color: const Color(0xFF94A3B8),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),

              // Badges row
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  // Top 10% Partner
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF9C3),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFFEF08A), width: 1),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.workspace_premium_rounded, color: Color(0xFFCA8A04), size: 12),
                        const SizedBox(width: 4),
                        Text(
                          'Top 10% Partner',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF854D0E),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Verified Partner
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDCFCE7),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFBBF7D0), width: 1),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 12),
                        const SizedBox(width: 4),
                        Text(
                          'Verified Partner',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
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
        ),
      ],
    );
  }

  // ── CATEGORY SHOWCASE IMAGE ─────────────────────────────────
  Widget _buildCategoryShowcaseImage(CategoryMetadata meta) {
    return Container(
      height: 108,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(13),
        child: Image.network(
          meta.imageUrl,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => Container(
            color: const Color(0xFFF1F5F9),
            alignment: Alignment.center,
            child: const Icon(Icons.build_circle_rounded, color: Color(0xFF94A3B8), size: 36),
          ),
        ),
      ),
    );
  }

  // ── MINI LIVE MAP CARD ──────────────────────────────────────
  Widget _buildMiniMapCard({required String distance}) {
    return Container(
      height: 108,
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(13),
        child: Stack(
          children: [
            // Custom vector street lines painter
            Positioned.fill(
              child: CustomPaint(
                painter: _MiniMapPainter(),
              ),
            ),

            // Top-left Distance chip
            Positioned(
              top: 8,
              left: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$distance km away',
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),

            // Bottom-right "View on map >" pill button
            Positioned(
              bottom: 8,
              right: 8,
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  context.push('/user/tracking?job_id=${widget.jobId}');
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.location_on_rounded, size: 11, color: Color(0xFF0F172A)),
                      const SizedBox(width: 3),
                      Text(
                        'View on map',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(width: 2),
                      const Icon(Icons.chevron_right_rounded, size: 13, color: Color(0xFF0F172A)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── METRIC CARD WIDGET ──────────────────────────────────────
  Widget _buildMetricCard({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String title,
    required String subtitle,
    String? chipLabel,
    Color? chipBg,
    Color? chipColor,
    bool showStars = false,
    bool isPrice = false,
    int? numericPrice,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAFA),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFF1F5F9)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon Box
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(height: 10),

          // Main Value
          if (isPrice && numericPrice != null)
            AnimatedCounter(
              value: numericPrice,
              prefix: '₹',
              fontSize: 17,
              color: const Color(0xFF0F172A),
              duration: const Duration(milliseconds: 700),
              curve: Curves.easeOutCubic,
            )
          else
            Text(
              title,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF0F172A),
              ),
            ),

          const SizedBox(height: 4),

          // Optional Star Rating Row
          if (showStars) ...[
            Row(
              children: List.generate(
                5,
                (index) => const Padding(
                  padding: EdgeInsets.only(right: 2),
                  child: Icon(Icons.star_rounded, color: Color(0xFFF59E0B), size: 13),
                ),
              ),
            ),
            const SizedBox(height: 4),
          ],

          // Subtitle
          Text(
            subtitle,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              color: const Color(0xFF64748B),
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),

          // Optional Badge Chip
          if (chipLabel != null && chipBg != null && chipColor != null) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
              decoration: BoxDecoration(
                color: chipBg,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                chipLabel,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: chipColor,
                ),
              ),
            ),
          ],
        ],
      ),
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

class _PulsingRadarState extends State<PulsingRadar> with TickerProviderStateMixin {
  late AnimationController _sweepController;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _sweepController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    )..repeat();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();
  }

  @override
  void dispose() {
    _sweepController.dispose();
    _pulseController.dispose();
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
      width: 290,
      height: 290,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 1. Radar sweep, distance rings & glowing worker blips
          AnimatedBuilder(
            animation: Listenable.merge([_sweepController, _pulseController]),
            builder: (context, child) {
              return CustomPaint(
                size: const Size(290, 290),
                painter: _MatchingRadarPainter(
                  sweepAngle: _sweepController.value * 2 * pi,
                  pulseProgress: _pulseController.value,
                  radarColor: widget.color,
                ),
              );
            },
          ),

          // 2. Multi-tier concentric sonar pulse rings
          ...List.generate(3, (i) {
            return AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                final double delay = i * 0.33;
                final double t = (_pulseController.value - delay) % 1.0;
                final double scale = 0.85 + (t * 1.6);
                final double opacity = (1.0 - t).clamp(0.0, 0.5);

                return Opacity(
                  opacity: opacity,
                  child: Transform.scale(
                    scale: scale,
                    child: Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: widget.color.withValues(alpha: 0.7),
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                );
              },
            );
          }),

          // 3. Central pulsing dish
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              final scale = 0.96 + 0.08 * sin(_pulseController.value * 2 * pi);
              return Transform.scale(
                scale: scale,
                child: Container(
                  width: 66,
                  height: 66,
                  decoration: BoxDecoration(
                    color: widget.color,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: widget.color.withValues(alpha: 0.5),
                        blurRadius: 20,
                        spreadRadius: 6,
                      ),
                    ],
                  ),
                  child: Icon(
                    _getServiceIcon(widget.serviceType),
                    color: Colors.white,
                    size: 30,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _MatchingRadarPainter extends CustomPainter {
  final double sweepAngle;
  final double pulseProgress;
  final Color radarColor;

  _MatchingRadarPainter({
    required this.sweepAngle,
    required this.pulseProgress,
    required this.radarColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2 - 12;

    // 1. Range rings (1.5km, 3.0km, 5.0km simulation)
    final ringPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    for (final fraction in [0.32, 0.62, 0.95]) {
      canvas.drawCircle(center, maxRadius * fraction, ringPaint);
    }

    // 2. Axis lines
    final axisPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.12)
      ..strokeWidth = 1.0;
    canvas.drawLine(Offset(center.dx - maxRadius, center.dy), Offset(center.dx + maxRadius, center.dy), axisPaint);
    canvas.drawLine(Offset(center.dx, center.dy - maxRadius), Offset(center.dx, center.dy + maxRadius), axisPaint);

    // 3. Sweep cone
    final sweepPaint = Paint()
      ..shader = SweepGradient(
        center: Alignment.center,
        startAngle: 0.0,
        endAngle: pi / 2,
        colors: [
          radarColor.withValues(alpha: 0.0),
          radarColor.withValues(alpha: 0.38),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: maxRadius));

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(sweepAngle - (pi / 2));
    canvas.drawArc(
      Rect.fromCircle(center: Offset.zero, radius: maxRadius),
      0.0,
      pi / 2,
      true,
      sweepPaint,
    );

    // Sweep leading edge
    final leadPaint = Paint()
      ..color = radarColor.withValues(alpha: 0.85)
      ..strokeWidth = 2.0;
    canvas.drawLine(Offset.zero, Offset(maxRadius * cos(pi / 2), maxRadius * sin(pi / 2)), leadPaint);
    canvas.restore();

    // 4. Detected target blips
    final blipPositions = [
      Offset(center.dx + maxRadius * 0.55 * cos(1.1), center.dy + maxRadius * 0.55 * sin(1.1)),
      Offset(center.dx + maxRadius * 0.75 * cos(2.8), center.dy + maxRadius * 0.75 * sin(2.8)),
      Offset(center.dx + maxRadius * 0.40 * cos(4.4), center.dy + maxRadius * 0.40 * sin(4.4)),
      Offset(center.dx + maxRadius * 0.85 * cos(5.6), center.dy + maxRadius * 0.85 * sin(5.6)),
    ];

    for (int i = 0; i < blipPositions.length; i++) {
      final pos = blipPositions[i];
      final angleToBlip = atan2(pos.dy - center.dy, pos.dx - center.dx);
      double normalizedAngle = angleToBlip < 0 ? angleToBlip + 2 * pi : angleToBlip;
      double normalizedSweep = sweepAngle % (2 * pi);
      double diff = (normalizedSweep - normalizedAngle).abs();
      if (diff > pi) diff = 2 * pi - diff;

      final double intensity = (1.0 - (diff / (pi / 2))).clamp(0.25, 1.0);

      final glowPaint = Paint()
        ..color = (i % 2 == 0 ? Colors.cyanAccent : Colors.amberAccent).withValues(alpha: 0.45 * intensity)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(pos, 9 * intensity, glowPaint);

      final dotPaint = Paint()
        ..color = (i % 2 == 0 ? Colors.cyanAccent : Colors.amberAccent).withValues(alpha: intensity)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(pos, 4.5, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _MatchingRadarPainter oldDelegate) {
    return oldDelegate.sweepAngle != sweepAngle || oldDelegate.pulseProgress != pulseProgress;
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

// ─────────────────────────────────────────────────────────────
// DYNAMIC CATEGORY METADATA RESOLVER
// Supports all present services and automatically formats/resolves
// any new categories added in the future!
// ─────────────────────────────────────────────────────────────
class CategoryMetadata {
  final String title;
  final String serviceKey;
  final String imageUrl;

  const CategoryMetadata({
    required this.title,
    required this.serviceKey,
    required this.imageUrl,
  });

  /// Dynamically resolves category title, specialty display name, and preview image.
  /// Works for both existing categories and ANY future categories added to Supabase.
  factory CategoryMetadata.resolve({
    required String? rawCategory,
    String? customImageUrl,
    String? customTitle,
  }) {
    final raw = (rawCategory ?? '').trim().toLowerCase();

    // 1. Dynamic Title formatting:
    // If custom title provided, use it; otherwise convert snake_case/kebab-case into Title Case.
    String resolvedTitle = customTitle?.trim() ?? '';
    if (resolvedTitle.isEmpty) {
      if (raw.contains('ro') || raw.contains('water') || raw.contains('purifier')) {
        resolvedTitle = 'Water Purifier Services';
      } else if (raw.contains('electric')) {
        resolvedTitle = 'Electrician & Power';
      } else if (raw.contains('plumb')) {
        resolvedTitle = 'Plumbing & Pipe Repair';
      } else if (raw.contains('ac') || raw.contains('air_cond') || raw.contains('cool')) {
        resolvedTitle = 'AC Service & Repair';
      } else if (raw.contains('carpent')) {
        resolvedTitle = 'Carpentry & Woodwork';
      } else if (raw.contains('clean')) {
        resolvedTitle = 'Deep Cleaning & Sanitization';
      } else if (raw.contains('paint')) {
        resolvedTitle = 'Painting & Waterproofing';
      } else if (raw.contains('pest')) {
        resolvedTitle = 'Pest Control Services';
      } else if (raw.contains('salon') || raw.contains('beauty') || raw.contains('hair')) {
        resolvedTitle = 'Salon & Grooming';
      } else if (raw.contains('appliance') || raw.contains('fridge') || raw.contains('washing')) {
        resolvedTitle = 'Appliance Repair';
      } else if (raw.contains('cctv') || raw.contains('security')) {
        resolvedTitle = 'CCTV & Security Systems';
      } else if (raw.contains('solar')) {
        resolvedTitle = 'Solar Installation & Service';
      } else if (raw.contains('mechanic') || raw.contains('vehicle') || raw.contains('bike') || raw.contains('car')) {
        resolvedTitle = 'Automobile Mechanic';
      } else if (raw.isNotEmpty) {
        // Automatically convert any new/future category slug to Title Case
        resolvedTitle = raw
            .replaceAll(RegExp(r'[_\-]+'), ' ')
            .split(' ')
            .where((w) => w.isNotEmpty)
            .map((w) => w[0].toUpperCase() + w.substring(1))
            .join(' ');
      } else {
        resolvedTitle = 'Home & Technical Services';
      }
    }

    final resolvedServiceKey = '• $resolvedTitle Specialist';

    // 2. Dynamic Image Resolution:
    // A) If the backend has a custom image (from Supabase category/job table), use it directly!
    if (customImageUrl != null && customImageUrl.trim().isNotEmpty && customImageUrl.startsWith('http')) {
      return CategoryMetadata(
        title: resolvedTitle,
        serviceKey: resolvedServiceKey,
        imageUrl: customImageUrl.trim(),
      );
    }

    // B) Curated high-res imagery for known services
    String resolvedImage = 'https://images.unsplash.com/photo-1581578731548-c64695cc6952?w=600&auto=format&fit=crop&q=80'; // Clean fallback tools/technician

    if (raw.contains('ro') || raw.contains('water') || raw.contains('purifier')) {
      resolvedImage = 'https://images.unsplash.com/photo-1621905251189-08b45d6a269e?w=600&auto=format&fit=crop&q=80'; // Water purifier / filter service
    } else if (raw.contains('electric')) {
      resolvedImage = 'https://images.unsplash.com/photo-1621905251918-48416bd8575a?w=600&auto=format&fit=crop&q=80'; // Electrician tools & board
    } else if (raw.contains('plumb')) {
      resolvedImage = 'https://images.unsplash.com/photo-1585704032915-c3400ca199e7?w=600&auto=format&fit=crop&q=80'; // Plumbing faucet & wrench
    } else if (raw.contains('ac') || raw.contains('air_cond') || raw.contains('cool')) {
      resolvedImage = 'https://images.unsplash.com/photo-1621905252507-b35492cc74b4?w=600&auto=format&fit=crop&q=80'; // AC servicing
    } else if (raw.contains('carpent')) {
      resolvedImage = 'https://images.unsplash.com/photo-1530124566582-a618bc2615dc?w=600&auto=format&fit=crop&q=80'; // Carpentry wood workshop
    } else if (raw.contains('clean')) {
      resolvedImage = 'https://images.unsplash.com/photo-1581578731548-c64695cc6952?w=600&auto=format&fit=crop&q=80'; // Cleaning
    } else if (raw.contains('paint')) {
      resolvedImage = 'https://images.unsplash.com/photo-1589939705384-5185137a7f0f?w=600&auto=format&fit=crop&q=80'; // Painting roller & wall
    } else if (raw.contains('pest')) {
      resolvedImage = 'https://images.unsplash.com/photo-1584820927498-cfe5211fd8bf?w=600&auto=format&fit=crop&q=80'; // Disinfection / pest control
    } else if (raw.contains('salon') || raw.contains('beauty') || raw.contains('hair')) {
      resolvedImage = 'https://images.unsplash.com/photo-1560066984-138dadb4c035?w=600&auto=format&fit=crop&q=80'; // Salon grooming
    } else if (raw.contains('appliance') || raw.contains('fridge') || raw.contains('washing')) {
      resolvedImage = 'https://images.unsplash.com/photo-1581092160607-ee22621dd758?w=600&auto=format&fit=crop&q=80'; // Appliance repair
    } else if (raw.contains('cctv') || raw.contains('security')) {
      resolvedImage = 'https://images.unsplash.com/photo-1557597774-9d273605dfa9?w=600&auto=format&fit=crop&q=80'; // CCTV camera
    } else if (raw.contains('solar')) {
      resolvedImage = 'https://images.unsplash.com/photo-1509391365360-2e959784a276?w=600&auto=format&fit=crop&q=80'; // Solar panels
    } else if (raw.contains('mechanic') || raw.contains('vehicle') || raw.contains('bike') || raw.contains('car')) {
      resolvedImage = 'https://images.unsplash.com/photo-1486006920555-c77dce18193b?w=600&auto=format&fit=crop&q=80'; // Car & bike mechanic
    }

    return CategoryMetadata(
      title: resolvedTitle,
      serviceKey: resolvedServiceKey,
      imageUrl: resolvedImage,
    );
  }
}

// ─────────────────────────────────────────────────────────────
// MINI LIVE MAP PREVIEW PAINTER
// ─────────────────────────────────────────────────────────────
class _MiniMapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // 1. Soft map background
    final bgPaint = Paint()..color = const Color(0xFFF1F5F9);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    // 2. Road grid lines
    final roadPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 6.0
      ..style = PaintingStyle.stroke;

    final subRoadPaint = Paint()
      ..color = const Color(0xFFE2E8F0)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    // Subtle background sub-grid
    canvas.drawLine(Offset(0, size.height * 0.15), Offset(size.width, size.height * 0.15), subRoadPaint);
    canvas.drawLine(Offset(0, size.height * 0.52), Offset(size.width, size.height * 0.52), subRoadPaint);
    canvas.drawLine(Offset(0, size.height * 0.88), Offset(size.width, size.height * 0.88), subRoadPaint);

    // Main horizontal roads
    canvas.drawLine(Offset(0, size.height * 0.35), Offset(size.width, size.height * 0.35), roadPaint);
    canvas.drawLine(Offset(0, size.height * 0.70), Offset(size.width, size.height * 0.70), roadPaint);

    // Main vertical roads
    canvas.drawLine(Offset(size.width * 0.25, 0), Offset(size.width * 0.25, size.height), roadPaint);
    canvas.drawLine(Offset(size.width * 0.65, 0), Offset(size.width * 0.65, size.height), roadPaint);

    // Diagonal route line
    final routePaint = Paint()
      ..color = const Color(0xFF3B82F6)
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();
    path.moveTo(size.width * 0.25, size.height * 0.35);
    path.quadraticBezierTo(
      size.width * 0.45,
      size.height * 0.50,
      size.width * 0.65,
      size.height * 0.70,
    );
    canvas.drawPath(path, routePaint);

    // Start point: Worker pulse circle
    final workerDot = Offset(size.width * 0.25, size.height * 0.35);
    canvas.drawCircle(
      workerDot,
      7,
      Paint()..color = const Color(0xFF3B82F6).withValues(alpha: 0.25),
    );
    canvas.drawCircle(
      workerDot,
      4.5,
      Paint()..color = const Color(0xFF2563EB),
    );
    canvas.drawCircle(
      workerDot,
      2,
      Paint()..color = Colors.white,
    );

    // Destination point: Destination pin
    final destDot = Offset(size.width * 0.65, size.height * 0.70);
    canvas.drawCircle(
      destDot,
      6,
      Paint()..color = const Color(0xFF0F172A),
    );
    canvas.drawCircle(
      destDot,
      2.5,
      Paint()..color = Colors.white,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

