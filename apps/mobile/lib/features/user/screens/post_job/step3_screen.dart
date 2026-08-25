import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:dio/dio.dart';
import 'dart:async';

import '../../../../core/theme/user_app_theme.dart';
import '../../../../core/services/api_service.dart';
import '../../../../core/config/services_list.dart';
import '../../../../core/providers/services_provider.dart';
import '../../../../core/widgets/jugaad_step_header.dart';
import 'post_job_state.dart';

class PostJobStep3Screen extends ConsumerStatefulWidget {
  const PostJobStep3Screen({super.key});

  @override
  ConsumerState<PostJobStep3Screen> createState() => _PostJobStep3ScreenState();
}

class _PostJobStep3ScreenState extends ConsumerState<PostJobStep3Screen> {
  bool _isPosting = false;
  bool _showSearchOverlay = false;

  String _formatScheduledAt(DateTime? dt) {
    if (dt == null) return '—';
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final period = dt.hour < 12 ? 'AM' : 'PM';
    final min = dt.minute.toString().padLeft(2, '0');
    return '${dt.day} ${months[dt.month - 1]}, $hour:$min $period';
  }

  Future<void> _postJob() async {
    final jobState = ref.read(postJobProvider);

    if (jobState.lat == 0.0 && jobState.lng == 0.0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.location_off, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Location is required. Please enable GPS and go back to refresh.',
                    style: UserAppTheme.body(color: Colors.white, weight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            backgroundColor: UserAppTheme.urgentRed,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
      return;
    }

    if (jobState.description.trim().length < 10) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Issue description must be at least 10 characters.',
                    style: UserAppTheme.body(color: Colors.white, weight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            backgroundColor: UserAppTheme.urgentRed,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
      return;
    }

    // Show the searching animation overlay IMMEDIATELY
    setState(() {
      _isPosting = true;
      _showSearchOverlay = true;
    });
    print('[POST_JOB] Posting job to API...');

    try {
      final res = await ApiService().createJob({
        'skill': jobState.skill.toLowerCase().replaceAll(' ', '_'),
        'description': jobState.description,
        'lat': jobState.lat,
        'lng': jobState.lng,
        'urgency': jobState.urgency,
        'scheduled_at': jobState.scheduledAt?.toIso8601String(),
        'job_type': jobState.jobType,
        'service_fee_type': jobState.serviceFeeType,
        'surcharge_amount': jobState.surchargeAmount,
      });
      final jobId = res['job_id'] ?? res['id'];
      if (jobId == null || jobId.toString().isEmpty) {
        throw Exception('Backend did not return job_id');
      }

      print('[POST_JOB] Job created: job_id=$jobId');
      ref.read(postJobProvider.notifier).reset();

      if (mounted) {
        context.go('/user/matching?job_id=$jobId');
      }
    } catch (e) {
      if (e is DioException) {
        final respData = e.response?.data;
        final errMsg = respData is Map && respData.containsKey('detail') 
            ? respData['detail'] 
            : e.message;
        print('[POST_JOB] DioError during job post: Type=${e.type} | Message=$errMsg | Data=$respData');
      } else {
        print('[POST_JOB] Exception during job post: $e');
      }
      
      setState(() {
        _isPosting = false;
        _showSearchOverlay = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _parseApiError(e),
                    style: UserAppTheme.body(color: Colors.white, weight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            backgroundColor: UserAppTheme.urgentRed,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    }
  }

  String _parseApiError(dynamic error) {
    try {
      if (error is DioException && error.response?.data != null) {
        final data = error.response!.data;
        if (data is Map && data.containsKey('detail')) {
          final detail = data['detail'];
          if (detail is String) return detail;
          if (detail is List) return detail.map((e) => e.toString()).join('\n');
        }
      }
    } catch (_) {
      // Fall through to default
    }
    return "Couldn't post job. Please try again.";
  }

  @override
  Widget build(BuildContext context) {
    final jobState = ref.watch(postJobProvider);
    final isScheduled = jobState.urgency == 'scheduled';
    final servicesAsync = ref.watch(servicesProvider);
    final service = servicesAsync.maybeWhen(
      data: (list) => list.firstWhere(
        (s) => s.title.toLowerCase() == jobState.skill.toLowerCase() || s.id == jobState.skill.toLowerCase().replaceAll(' ', '_'),
        orElse: () => kAllServices.firstWhere(
          (s) => s.title.toLowerCase() == jobState.skill.toLowerCase(),
          orElse: () => kAllServices.first,
        ),
      ),
      orElse: () => kAllServices.firstWhere(
        (s) => s.title.toLowerCase() == jobState.skill.toLowerCase(),
        orElse: () => kAllServices.first,
      ),
    );
    final priceMinStr = service.priceMin.toStringAsFixed(0);
    final priceMaxStr = service.priceMax.toStringAsFixed(0);

    final bool isLocationEmpty = jobState.lat == 0.0 && jobState.lng == 0.0;
    final btnText = isScheduled ? 'Schedule Booking' : 'Find Workers Now';

    return Scaffold(
      backgroundColor: UserAppTheme.background,
      body: Stack(
        children: [
          Column(
        children: [
          JugaadStepHeader(
            title: "Confirm your job",
            currentStep: 3,
            totalSteps: 4,
            onBack: () => context.pop(),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- ORDER SUMMARY CARD Title
                  Row(
                    children: [
                      const Icon(Icons.receipt_long_rounded, color: UserAppTheme.primaryBlue, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        'Order Summary',
                        style: UserAppTheme.body(
                          size: 16,
                          weight: FontWeight.bold,
                          color: UserAppTheme.textPrimary,
                        ),
                      ),
                    ],
                  ).animate().fadeIn(duration: 350.ms),
                  const SizedBox(height: 12),

                  // --- ORDER SUMMARY CARD
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: UserAppTheme.cardShadow,
                      border: Border.all(color: UserAppTheme.divider, width: 1.0),
                    ),
                    child: Column(
                      children: [
                        _buildSummaryRow(
                          icon: Icons.build_circle_outlined,
                          iconColor: UserAppTheme.primaryBlue,
                          label: 'Service Required',
                          valueWidget: Text(
                            jobState.skill,
                            style: UserAppTheme.body(
                              size: 15,
                              weight: FontWeight.bold,
                              color: UserAppTheme.textPrimary,
                            ),
                          ),
                        ),
                        _buildSummaryRow(
                          icon: isScheduled ? Icons.calendar_today_outlined : Icons.flash_on_rounded,
                          iconColor: UserAppTheme.skyAccent,
                          label: 'Timing Mode',
                          valueWidget: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isScheduled ? 'Scheduled Session' : 'Instant Match (Now)',
                                style: UserAppTheme.body(
                                  size: 15,
                                  weight: FontWeight.bold,
                                  color: UserAppTheme.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                isScheduled ? _formatScheduledAt(jobState.scheduledAt) : 'Finds closest worker immediately',
                                style: UserAppTheme.body(
                                  size: 12,
                                  color: UserAppTheme.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        _buildSummaryRow(
                          icon: Icons.location_on_outlined,
                          iconColor: UserAppTheme.primaryBlue,
                          label: 'Location',
                          valueWidget: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (isLocationEmpty) ...[
                                const SizedBox(height: 4),
                                // --- LOCATION ERROR STATE
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: UserAppTheme.urgentRed.withValues(alpha: 0.05),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: UserAppTheme.urgentRed.withValues(alpha: 0.15)),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.warning_amber_rounded, color: UserAppTheme.urgentRed, size: 20),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              "Location required",
                                              style: UserAppTheme.body(
                                                color: UserAppTheme.urgentRed,
                                                weight: FontWeight.bold,
                                                size: 13,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              "Enable GPS to continue",
                                              style: UserAppTheme.label(
                                                color: UserAppTheme.textSecondary,
                                                size: 11,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      TextButton(
                                        onPressed: () => context.pop(), // Goes back to Step 2
                                        style: TextButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          minimumSize: Size.zero,
                                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                        ),
                                        child: Text(
                                          "Enable GPS",
                                          style: UserAppTheme.body(
                                            color: UserAppTheme.primaryBlue,
                                            size: 12,
                                            weight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ] else ...[
                                Text(
                                  jobState.address,
                                  style: UserAppTheme.body(
                                    size: 15,
                                    weight: FontWeight.bold,
                                    color: UserAppTheme.textPrimary,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ],
                          ),
                        ),
                        _buildSummaryRow(
                          icon: Icons.currency_rupee_rounded,
                          iconColor: UserAppTheme.successGreen,
                          label: 'Estimated Cost',
                          valueWidget: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '₹$priceMinStr – ₹$priceMaxStr',
                                style: UserAppTheme.body(
                                  size: 15,
                                  weight: FontWeight.bold,
                                  color: UserAppTheme.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Pay after service is completed',
                                style: UserAppTheme.body(
                                  size: 12,
                                  color: UserAppTheme.textSecondary,
                                ),
                              ),
                            ],
                          ),
                          showDivider: false,
                        ),
                      ],
                    ),
                  ).animate().fadeIn(delay: 100.ms, duration: 400.ms).slideY(begin: 0.05),
                  const SizedBox(height: 24),

                  // --- ISSUE DETAILS CARD
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: UserAppTheme.cardShadow,
                      border: Border.all(color: UserAppTheme.divider, width: 1.0),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Issue Details",
                          style: UserAppTheme.body(
                            size: 16,
                            weight: FontWeight.bold,
                            color: UserAppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          jobState.description.trim().isNotEmpty
                              ? jobState.description
                              : "No description added",
                          style: UserAppTheme.body(
                            size: 14,
                            color: jobState.description.trim().isNotEmpty
                                ? UserAppTheme.textPrimary
                                : UserAppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ).animate().fadeIn(delay: 150.ms, duration: 400.ms).slideY(begin: 0.05),
                  const SizedBox(height: 20),

                  // Scheduled note / disclaimer
                  if (isScheduled)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: UserAppTheme.primaryBlue.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: UserAppTheme.primaryBlue.withValues(alpha: 0.1)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline, color: UserAppTheme.primaryBlue, size: 18),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'We will assign and notify you of the worker details exactly 2 hours before your scheduled time slot.',
                              style: UserAppTheme.body(
                                size: 11,
                                color: UserAppTheme.textPrimary,
                                weight: FontWeight.bold,
                              ).copyWith(height: 1.4),
                            ),
                          ),
                        ],
                      ),
                    ).animate().fadeIn(delay: 200.ms),
                ],
              ),
            ),
          ),

          // --- Pinned Bottom Action Button
          Container(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 20,
                  offset: const Offset(0, -5),
                ),
              ],
              border: Border.all(color: UserAppTheme.divider, width: 0.5),
            ),
            child: Row(
              children: [
                Expanded(
                  child: ConfirmScaleButton(
                    onPressed: isLocationEmpty ? null : _postJob,
                    text: btnText,
                    disabled: isLocationEmpty,
                    loading: _isPosting,
                  ),
                ),
              ],
            ),
          ).animate().fadeIn(delay: 250.ms),
        ],
      ),

          // ─── FULL-SCREEN SEARCHING ANIMATION OVERLAY ───
          if (_showSearchOverlay)
            _SearchingOverlay(
              serviceType: jobState.skill,
              onCancel: () {
                setState(() {
                  _showSearchOverlay = false;
                  _isPosting = false;
                });
              },
            ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow({
    required IconData icon,
    required Color iconColor,
    required String label,
    required Widget valueWidget,
    bool showDivider = true,
  }) {
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Icon(icon, size: 16, color: iconColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: UserAppTheme.label(
                      size: 12,
                      color: UserAppTheme.textSecondary,
                      weight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  valueWidget,
                ],
              ),
            ),
          ],
        ),
        if (showDivider) ...[
          const SizedBox(height: 12),
          const Divider(height: 1, color: UserAppTheme.divider, thickness: 1),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

// --- HELPER WIDGETS
class ConfirmScaleButton extends StatefulWidget {
  final VoidCallback? onPressed;
  final String text;
  final bool disabled;
  final bool loading;

  const ConfirmScaleButton({
    super.key,
    required this.onPressed,
    required this.text,
    this.disabled = false,
    this.loading = false,
  });

  @override
  State<ConfirmScaleButton> createState() => _ConfirmScaleButtonState();
}

class _ConfirmScaleButtonState extends State<ConfirmScaleButton> with SingleTickerProviderStateMixin {
  double _scale = 1.0;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isReallyDisabled = widget.disabled || widget.onPressed == null || widget.loading;
    return GestureDetector(
      onTapDown: isReallyDisabled ? null : (_) => setState(() => _scale = 0.97),
      onTapUp: isReallyDisabled ? null : (_) => setState(() => _scale = 1.0),
      onTapCancel: isReallyDisabled ? null : () => setState(() => _scale = 1.0),
      onTap: isReallyDisabled ? null : () {
        HapticFeedback.mediumImpact();
        widget.onPressed!();
      },
      child: Tooltip(
        message: widget.disabled ? "Enable GPS first" : "",
        child: AnimatedScale(
          scale: _scale,
          duration: const Duration(milliseconds: 100),
          child: Container(
            height: UserAppTheme.buttonHeight,
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: isReallyDisabled ? null : UserAppTheme.primaryGradient,
              color: isReallyDisabled ? const Color(0xFFE2E8F0) : null,
              borderRadius: UserAppTheme.buttonBorderRadius,
              boxShadow: isReallyDisabled
                  ? []
                  : [
                      BoxShadow(
                        color: UserAppTheme.primaryBlue.withValues(alpha: 0.25),
                        blurRadius: 15,
                        offset: const Offset(0, 4),
                      )
                    ],
            ),
            alignment: Alignment.center,
            child: widget.loading
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        "Finding workers...",
                        style: UserAppTheme.body(
                          color: Colors.white,
                          weight: FontWeight.bold,
                          size: 16,
                        ),
                      ),
                    ],
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        widget.text,
                        style: UserAppTheme.body(
                          color: isReallyDisabled ? UserAppTheme.textSecondary : Colors.white,
                          weight: FontWeight.bold,
                          size: 16,
                        ),
                      ),
                      const SizedBox(width: 8),
                      AnimatedBuilder(
                        animation: _pulseController,
                        builder: (context, child) {
                          return Transform.scale(
                            scale: 1.0 + _pulseController.value * 0.15,
                            child: Icon(
                              Icons.bolt_rounded,
                              color: isReallyDisabled ? UserAppTheme.textSecondary : Colors.white,
                              size: 18,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

// ─── FULL-SCREEN SEARCHING ANIMATION OVERLAY ────────────────────────
class _SearchingOverlay extends StatefulWidget {
  final String serviceType;
  final VoidCallback onCancel;

  const _SearchingOverlay({
    required this.serviceType,
    required this.onCancel,
  });

  @override
  State<_SearchingOverlay> createState() => _SearchingOverlayState();
}

class _SearchingOverlayState extends State<_SearchingOverlay>
    with TickerProviderStateMixin {
  late AnimationController _radarController;
  late AnimationController _fadeInController;
  late AnimationController _iconPulseController;
  late AnimationController _glowController;

  // Typewriter
  late List<String> _statuses;
  int _currentIndex = 0;
  String _displayText = '';
  Timer? _cycleTimer;
  Timer? _typewriterTimer;
  int _dotCount = 0;
  Timer? _dotTimer;

  @override
  void initState() {
    super.initState();

    _radarController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    _fadeInController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();

    _iconPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _initStatuses();
    _startCycle();
    _startDotAnimation();
  }

  void _initStatuses() {
    final displayService = widget.serviceType
        .replaceAll('_', ' ')
        .split(' ')
        .map((word) =>
            word.isNotEmpty ? '${word[0].toUpperCase()}${word.substring(1)}' : '')
        .join(' ');

    _statuses = [
      'Scanning nearby coordinates',
      'Locating active ${displayService}s',
      'Checking live availability',
      'Optimizing nearest routes',
      'Matching best worker for you',
    ];
  }

  void _startDotAnimation() {
    _dotTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (mounted) {
        setState(() => _dotCount = (_dotCount + 1) % 4);
      }
    });
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
    _typewriterTimer =
        Timer.periodic(const Duration(milliseconds: 25), (timer) {
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
  void dispose() {
    _radarController.dispose();
    _fadeInController.dispose();
    _iconPulseController.dispose();
    _glowController.dispose();
    _cycleTimer?.cancel();
    _typewriterTimer?.cancel();
    _dotTimer?.cancel();
    super.dispose();
  }

  IconData _getServiceIcon(String service) {
    final s = service.toLowerCase().replaceAll('_', ' ');
    if (s.contains('electrician') || s.contains('power') || s.contains('circuit')) {
      return Icons.bolt_rounded;
    } else if (s.contains('plumb') || s.contains('water') || s.contains('leak') || s.contains('drain') || s.contains('toilet')) {
      return Icons.plumbing_rounded;
    } else if (s.contains('laptop')) {
      return Icons.laptop_chromebook_rounded;
    } else if (s.contains('phone')) {
      return Icons.phone_android_rounded;
    } else if (s.contains('carpenter')) {
      return Icons.handyman_rounded;
    } else if (s.contains('painter')) {
      return Icons.format_paint_rounded;
    } else if (s.contains('ac') || s.contains('air conditioning')) {
      return Icons.ac_unit_rounded;
    } else if (s.contains('cleaning')) {
      return Icons.cleaning_services_rounded;
    } else if (s.contains('lock') || s.contains('key')) {
      return Icons.vpn_key_rounded;
    } else {
      return Icons.person_search_rounded;
    }
  }

  Widget _buildRadarRing(double delayFraction) {
    return AnimatedBuilder(
      animation: _radarController,
      builder: (context, child) {
        double t = (_radarController.value - delayFraction) % 1.0;
        double scale = 1.0 + (t * 1.8);
        double opacity = (1.0 - t) * 0.5;

        return Opacity(
          opacity: opacity.clamp(0.0, 1.0),
          child: Transform.scale(
            scale: scale,
            child: Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: UserAppTheme.skyAccent,
                  width: 2.0,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final dots = '.' * _dotCount;
    final paddedDots = dots.padRight(3);

    return FadeTransition(
      opacity: CurvedAnimation(
        parent: _fadeInController,
        curve: Curves.easeOut,
      ),
      child: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.1),
            colors: [
              Color(0xFF1E3A8A), // Deep blue center
              Color(0xFF0F172A), // Dark slate edge
            ],
            radius: 1.5,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Top bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '🔍 Finding Helpers...',
                            style: UserAppTheme.heading(
                              size: 18,
                              weight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Connecting to nearby experts',
                            style: UserAppTheme.body(
                              size: 13,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
                    OutlinedButton(
                      onPressed: widget.onCancel,
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.white30, width: 1.0),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
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

              const Spacer(flex: 2),

              // Pulsing Radar
              SizedBox(
                width: 280,
                height: 280,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Outer glow
                    AnimatedBuilder(
                      animation: _glowController,
                      builder: (context, _) {
                        return Container(
                          width: 180,
                          height: 180,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: UserAppTheme.skyAccent.withValues(
                                    alpha: 0.08 + _glowController.value * 0.07),
                                blurRadius: 60,
                                spreadRadius: 30,
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    // Radar rings
                    _buildRadarRing(0),
                    _buildRadarRing(0.25),
                    _buildRadarRing(0.50),
                    _buildRadarRing(0.75),
                    // Center icon
                    AnimatedBuilder(
                      animation: _iconPulseController,
                      builder: (context, _) {
                        final scale =
                            1.0 + _iconPulseController.value * 0.08;
                        return Transform.scale(
                          scale: scale,
                          child: Container(
                            width: 68,
                            height: 68,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [
                                  UserAppTheme.primaryBlue,
                                  UserAppTheme.skyAccent,
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: UserAppTheme.primaryBlue
                                      .withValues(alpha: 0.4),
                                  blurRadius: 20,
                                  spreadRadius: 4,
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
              ),

              const SizedBox(height: 32),

              // Typewriter status text
              Container(
                height: 28,
                alignment: Alignment.center,
                child: Text(
                  '$_displayText$paddedDots',
                  style: UserAppTheme.body(
                    size: 16,
                    color: Colors.white,
                    weight: FontWeight.w600,
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Subtle shimmer bar
              Container(
                width: 200,
                height: 4,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(2),
                  color: Colors.white.withValues(alpha: 0.1),
                ),
                child: AnimatedBuilder(
                  animation: _radarController,
                  builder: (context, _) {
                    return FractionallySizedBox(
                      widthFactor: 0.4,
                      alignment: Alignment(
                        -1.0 + _radarController.value * 2.0,
                        0,
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(2),
                          gradient: LinearGradient(
                            colors: [
                              Colors.transparent,
                              UserAppTheme.skyAccent.withValues(alpha: 0.8),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

              const Spacer(flex: 3),

              // Bottom text
              Padding(
                padding: const EdgeInsets.only(bottom: 32),
                child: Text(
                  'This may take a few seconds',
                  style: UserAppTheme.body(
                    size: 12,
                    color: Colors.white38,
                    weight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
