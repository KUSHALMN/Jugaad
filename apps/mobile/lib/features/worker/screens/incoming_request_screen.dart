import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:percent_indicator/percent_indicator.dart';
import 'package:jugaad_mvp/core/theme/worker_app_theme.dart';
import 'package:jugaad_mvp/core/services/job_dispatch_service.dart';
import 'package:jugaad_mvp/core/services/notification_service.dart';
import 'package:jugaad_mvp/core/utils/jugaad_haptics.dart';

class IncomingRequestScreen extends StatefulWidget {
  final String jobId;
  final String skill;
  final double budget;
  final String description;
  final double distanceKm;
  final int timeoutSeconds;
  final String jobType;
  final double surchargeAmount;

  const IncomingRequestScreen({
    super.key,
    required this.jobId,
    this.skill = 'Service',
    this.budget = 0,
    this.description = '',
    this.distanceKm = 0,
    this.timeoutSeconds = 300,
    this.jobType = 'normal',
    this.surchargeAmount = 0,
  });

  @override
  State<IncomingRequestScreen> createState() => _IncomingRequestScreenState();
}

class _IncomingRequestScreenState extends State<IncomingRequestScreen>
    with TickerProviderStateMixin {
  // Timer state
  late AnimationController _timerController;
  int _secondsLeft = 300;
  bool _isActioning = false;
  Timer? _emergencyHapticTimer;

  // Animation Controllers
  late AnimationController _borderPulseController;
  late AnimationController _sheetController;
  late Animation<Offset> _sheetSlide;

  // Accept animation
  bool _didAccept = false;

  // Drag sheet physics fields
  double _dragOffset = 0.0;
  bool _isDragging = false;

  // Listen to dispatch events (JOB_TAKEN dismissal)
  StreamSubscription<Map<String, dynamic>>? _dispatchSub;

  final JobDispatchService _dispatchService = JobDispatchService();

  @override
  void initState() {
    super.initState();
    _secondsLeft = widget.timeoutSeconds;
    print('[INCOMING] Job request received: jobId=${widget.jobId}, '
        'skill=${widget.skill}, budget=${widget.budget}, '
        'distance=${widget.distanceKm}km, timeout=${widget.timeoutSeconds}s');

    // Haptic feedback when screen appears
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await JugaadHaptics.heavy();
      await Future.delayed(200.ms);
      await JugaadHaptics.medium();
    });

    _sheetController = AnimationController(vsync: this, duration: 350.ms)..forward();
    _borderPulseController = AnimationController(vsync: this, duration: 1000.ms)..repeat(reverse: true);

    if (widget.jobType == 'emergency') {
      _emergencyHapticTimer = Timer.periodic(const Duration(milliseconds: 1500), (timer) {
        if (!mounted || _isActioning) {
          timer.cancel();
          return;
        }
        HapticFeedback.heavyImpact();
      });
    }

    _sheetSlide = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _sheetController, curve: Curves.easeOutCubic),
    );

    // Timer countdown
    _timerController = AnimationController(
      vsync: this,
      duration: Duration(seconds: widget.timeoutSeconds),
    )..addListener(() {
        if (!mounted) return;
        final newSecs =
            ((1.0 - _timerController.value) * widget.timeoutSeconds).round();
        if (newSecs != _secondsLeft) {
          setState(() => _secondsLeft = newSecs);
          JugaadHaptics.selection();
          if (_secondsLeft < 10) {
            HapticFeedback.heavyImpact();
          } else if (_secondsLeft < 30) {
            JugaadHaptics.warning();
          }
        }
        if (_timerController.isCompleted && !_isActioning) {
          _onTimerExpired();
        }
      });
    _timerController.forward();

    // Listen for JOB_TAKEN events to auto-dismiss
    _dispatchSub =
        NotificationService().dispatchEvents.listen(_onDispatchEvent);
  }

  void _onDispatchEvent(Map<String, dynamic> data) {
    final type = data['type'];
    final eventJobId = data['job_id'];

    if (type == 'JOB_TAKEN' && eventJobId == widget.jobId) {
      print('[INCOMING] Job taken by another worker. Dismissing.');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Another worker accepted this job first.',
              style: WorkerAppTheme.body(
                  color: Colors.white, weight: FontWeight.w700),
            ),
            backgroundColor: WorkerAppTheme.urgentRed,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        );
        context.go('/worker/home');
      }
    }
  }

  @override
  void dispose() {
    _timerController.dispose();
    _borderPulseController.dispose();
    _sheetController.dispose();
    _dispatchSub?.cancel();
    _emergencyHapticTimer?.cancel();
    super.dispose();
  }

  Future<void> _onTimerExpired() async {
    if (_isActioning) return;
    setState(() => _isActioning = true);
    print('[INCOMING] Timer expired. Auto-dismiss.');
    await _passJob();
  }

  Future<void> _acceptJob() async {
    if (_isActioning) return;
    setState(() {
      _isActioning = true;
      _didAccept = true;
    });
    HapticFeedback.mediumImpact();
    print('[INCOMING] Worker tapped Accept for job: ${widget.jobId}');

    try {
      Map<String, dynamic> result;
      try {
        result = await _dispatchService.respondJobRequest(widget.jobId, action: 'accept');
      } catch (err) {
        if (err.toString().contains('409') || err.toString().contains('404')) {
          rethrow;
        }
        result = await _dispatchService.acceptJob(widget.jobId);
      }
      print('[INCOMING] Accept result: ${result['status']}');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded,
                    color: Colors.white, size: 18),
                const SizedBox(width: 10),
                Text(
                  'Job accepted! Navigating to job details.',
                  style: WorkerAppTheme.body(
                    color: Colors.white,
                    weight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            backgroundColor: WorkerAppTheme.primaryGreen,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            duration: const Duration(seconds: 2),
          ),
        );
        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted) context.go('/worker/active?job_id=${widget.jobId}');
      }
    } catch (e) {
      if (e.toString().contains('409')) {
        print('[INCOMING] Accept result: 409 (Race condition)');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Another worker accepted this job first.',
                  style: WorkerAppTheme.body(
                      color: Colors.white, weight: FontWeight.w700)),
              backgroundColor: WorkerAppTheme.earningGold,
              behavior: SnackBarBehavior.floating,
              margin: const EdgeInsets.all(16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
          );
          context.go('/worker/home');
        }
      } else {
        print('[INCOMING] Error accepting job: $e');
        if (mounted) {
          setState(() {
            _isActioning = false;
            _didAccept = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
      }
    }
  }

  Future<void> _passJob() async {
    try {
      try {
        await _dispatchService.respondJobRequest(widget.jobId, action: 'reject');
      } catch (_) {
        await _dispatchService.rejectJob(widget.jobId, reason: 'declined');
      }
      print('[INCOMING] Reject result: 200');
    } catch (e) {
      print('[INCOMING] Error rejecting job: $e');
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Request declined — waiting for next job',
            style: WorkerAppTheme.body(
                color: Colors.white, weight: FontWeight.w600),
          ),
          backgroundColor: WorkerAppTheme.textSecondary,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      );
      context.go('/worker/home');
    }
  }

  String _formatTimer() {
    final mins = _secondsLeft ~/ 60;
    final secs = _secondsLeft % 60;
    if (mins > 0) {
      return '$mins:${secs.toString().padLeft(2, '0')}';
    }
    return '$_secondsLeft';
  }

  String _formatBudget() {
    if (widget.jobType == 'emergency') {
      return '₹${(widget.budget + widget.surchargeAmount).toInt()}';
    }
    if (widget.budget <= 0) return '₹150 – ₹350';
    return '₹${widget.budget.toInt()}';
  }

  String _formatDistance() {
    if (widget.distanceKm <= 0) return 'Nearby';
    return '${widget.distanceKm.toStringAsFixed(1)} km away';
  }

  String _formatEta() {
    if (widget.distanceKm <= 0) return '~10 min ETA';
    final eta = (widget.distanceKm * 5).round().clamp(5, 60);
    return '~$eta min ETA';
  }

  @override
  Widget build(BuildContext context) {
    final scaleFactor = (1.0 - (_dragOffset / 900.0)).clamp(0.88, 1.0);
    final translateOffset = _dragOffset * 0.45;

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: widget.jobType == 'emergency'
            ? const Color(0xFF7F1D1D).withValues(alpha: 0.8)
            : Colors.black.withValues(alpha: 0.4),
        body: Column(
          children: [
            Expanded(child: Container()),
            GestureDetector(
              onVerticalDragStart: (details) {
                if (!_isActioning) {
                  setState(() {
                    _isDragging = true;
                  });
                }
              },
              onVerticalDragUpdate: (details) {
                if (!_isActioning && _isDragging) {
                  setState(() {
                    _dragOffset = (details.localPosition.dy > 0)
                        ? details.localPosition.dy
                        : 0.0;
                  });
                }
              },
              onVerticalDragEnd: (details) {
                if (!_isActioning && _isDragging) {
                  setState(() {
                    _isDragging = false;
                  });
                  if (_dragOffset > 150.0) {
                    _passJob();
                  } else {
                    HapticFeedback.selectionClick();
                    setState(() {
                      _dragOffset = 0.0;
                    });
                  }
                }
              },
              child: Transform.translate(
                offset: Offset(0, translateOffset),
                child: Transform.scale(
                  scale: scaleFactor,
                  child: AnimatedContainer(
                    duration: _isDragging
                        ? Duration.zero
                        : const Duration(milliseconds: 350),
                    curve: Curves.easeOutCubic,
                    child: SlideTransition(
                      position: _sheetSlide,
                      child: FadeTransition(
                        opacity: _sheetController,
                        child: AnimatedBuilder(
                          animation: _borderPulseController,
                          builder: (context, child) {
                            final borderOpacity =
                                0.4 + (0.6 * _borderPulseController.value);
                            return Container(
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: WorkerAppTheme.surface,
                                borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(24)),
                                border: Border.all(
                                  color: (_didAccept
                                          ? WorkerAppTheme.primaryGreen
                                          : (widget.jobType == 'emergency'
                                              ? WorkerAppTheme.urgentRed
                                              : WorkerAppTheme.primaryGreen))
                                      .withValues(alpha: borderOpacity * 0.5),
                                  width: 2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: (_didAccept
                                            ? WorkerAppTheme.primaryGreen
                                            : (widget.jobType == 'emergency'
                                                ? WorkerAppTheme.urgentRed
                                                : WorkerAppTheme.primaryGreen))
                                        .withValues(alpha: 0.15 *
                                            _borderPulseController.value),
                                    blurRadius: 24,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              child: child,
                            );
                          },
                          child: _buildSheetContent(context),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSheetContent(BuildContext context) {
    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── TOP GRADIENT BANNER ─────────────────────────────
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: widget.jobType == 'emergency'
                  ? const LinearGradient(
                      colors: [Color(0xFFE11D48), Color(0xFF9F1239)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : WorkerAppTheme.primaryGradient,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
            ),
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Pulsing dot
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                )
                    .animate(onPlay: (c) => c.repeat(reverse: true))
                    .scale(
                        begin: const Offset(0.7, 0.7),
                        end: const Offset(1.3, 1.3),
                        duration: 600.ms)
                    .fade(begin: 0.3, end: 1.0, duration: 600.ms),
                const SizedBox(width: 8),
                Text(
                  widget.jobType == 'emergency'
                      ? '🚨 EMERGENCY REQUEST'
                      : 'New Job Request',
                  style: WorkerAppTheme.heading(
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ── CIRCULAR COUNTDOWN TIMER ─────────────────────────
          CircularPercentIndicator(
            radius: 70.0,
            lineWidth: 10.0,
            percent: (widget.timeoutSeconds > 0)
                ? (_secondsLeft / widget.timeoutSeconds).clamp(0.0, 1.0)
                : 0.0,
            circularStrokeCap: CircularStrokeCap.round,
            progressColor: _secondsLeft < 10
                ? WorkerAppTheme.urgentRed
                : _secondsLeft < 30
                    ? WorkerAppTheme.earningGold
                    : WorkerAppTheme.primaryGreen,
            backgroundColor: const Color(0xFFE5E7EB),
            animation: false,
            center: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _formatTimer(),
                  style: WorkerAppTheme.display(
                    size: 36,
                    color: WorkerAppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Accept before\ntime runs out',
                  textAlign: TextAlign.center,
                  style: WorkerAppTheme.label(
                    size: 10,
                    color: WorkerAppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ── ESTIMATED EARNING HERO ───────────────────────────
          Column(
            children: [
              Text(
                widget.jobType == 'emergency'
                    ? "Total Earnings (Includes Surcharge)"
                    : "You'll earn",
                style: WorkerAppTheme.label(
                  size: 13,
                  color: WorkerAppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _formatBudget(),
                style: WorkerAppTheme.display(
                  size: 44,
                  color: widget.jobType == 'emergency'
                      ? WorkerAppTheme.urgentRed
                      : WorkerAppTheme.primaryGreen,
                ),
              ),
              if (widget.jobType == 'emergency') ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: WorkerAppTheme.urgentRed.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: WorkerAppTheme.urgentRed.withValues(alpha: 0.2),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Base: ₹${widget.budget.toInt()}',
                        style: WorkerAppTheme.body(
                          size: 12,
                          color: WorkerAppTheme.textSecondary,
                          weight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Text(
                        'Surcharge: +₹${widget.surchargeAmount.toInt()}',
                        style: WorkerAppTheme.body(
                          size: 12,
                          color: WorkerAppTheme.urgentRed,
                          weight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ).animate().scale(
                duration: 400.ms,
                curve: Curves.easeOutBack,
              ),
          const SizedBox(height: 20),

          // ── JOB DETAILS CARD ────────────────────────────────
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: WorkerAppTheme.surface,
              borderRadius: WorkerAppTheme.cardBorderRadius,
              boxShadow: WorkerAppTheme.cardShadow,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Service Badges
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.build_rounded,
                              size: 12, color: WorkerAppTheme.trustBlue),
                          const SizedBox(width: 4),
                          Text(
                            widget.skill.isNotEmpty
                                ? widget.skill.replaceAll('_', ' ')
                                : 'Service',
                            style: WorkerAppTheme.label(
                                color: WorkerAppTheme.trustBlue, size: 11),
                          ),
                        ],
                      ),
                    ),
                    // Urgency Badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: widget.jobType == 'emergency'
                            ? const Color(0xFF7F1D1D)
                            : const Color(0xFFFEE2E2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            widget.jobType == 'emergency'
                                ? Icons.warning_rounded
                                : Icons.flash_on_rounded,
                            size: 12,
                            color: widget.jobType == 'emergency'
                                ? Colors.white
                                : WorkerAppTheme.urgentRed,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            widget.jobType == 'emergency' ? 'EMERGENCY' : 'Urgent',
                            style: WorkerAppTheme.label(
                              color: widget.jobType == 'emergency'
                                  ? Colors.white
                                  : WorkerAppTheme.urgentRed,
                              size: 11,
                              weight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                // Distance & ETA Row
                Row(
                  children: [
                    const Icon(Icons.location_on_outlined,
                        size: 16, color: WorkerAppTheme.primaryGreen),
                    const SizedBox(width: 6),
                    Text(
                      _formatDistance(),
                      style: WorkerAppTheme.body(
                        color: WorkerAppTheme.textSecondary,
                        weight: FontWeight.w500,
                      ),
                    ),
                    const Spacer(),
                    const Icon(Icons.schedule_rounded,
                        size: 16, color: WorkerAppTheme.textSecondary),
                    const SizedBox(width: 4),
                    Text(
                      _formatEta(),
                      style: WorkerAppTheme.body(
                        color: WorkerAppTheme.textSecondary,
                        weight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                if (widget.description.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Divider(
                      height: 1, thickness: 1, color: WorkerAppTheme.divider),
                  const SizedBox(height: 12),
                  Text(
                    '"${widget.description}"',
                    style: WorkerAppTheme.body(
                      color: WorkerAppTheme.textSecondary,
                      size: 13,
                    ).copyWith(fontStyle: FontStyle.italic),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ── ACTION BUTTONS ───────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
                // Accept Button
                GestureDetector(
                  onTap: _isActioning ? null : _acceptJob,
                  child: Container(
                    height: 56,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      gradient: widget.jobType == 'emergency'
                          ? const LinearGradient(
                              colors: [Color(0xFFE11D48), Color(0xFF9F1239)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            )
                          : WorkerAppTheme.primaryGradient,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: (widget.jobType == 'emergency'
                                  ? WorkerAppTheme.urgentRed
                                  : WorkerAppTheme.primaryGreen)
                              .withValues(alpha: 0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Center(
                      child: _isActioning && _didAccept
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2.5,
                              ),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.check_rounded,
                                    color: Colors.white, size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  'Accept Job',
                                  style: WorkerAppTheme.heading(
                                    color: Colors.white,
                                    size: 17,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                // Skip Button
                GestureDetector(
                  onTap: _isActioning ? null : _passJob,
                  child: Container(
                    height: 44,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: WorkerAppTheme.urgentRed,
                        width: 1.5,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        'Skip',
                        style: WorkerAppTheme.heading(
                          color: WorkerAppTheme.urgentRed,
                          size: 14,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // ── Incentive Warning ────────────────────────────────
          Padding(
            padding: const EdgeInsets.only(bottom: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.warning_amber_rounded,
                    color: WorkerAppTheme.earningGold, size: 13),
                const SizedBox(width: 5),
                Text(
                  'Declining frequently reduces your job priority.',
                  style: WorkerAppTheme.label(
                    color: WorkerAppTheme.textSecondary,
                    size: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
