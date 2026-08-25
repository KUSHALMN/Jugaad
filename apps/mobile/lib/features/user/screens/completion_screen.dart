import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:jugaad_mvp/core/config/supabase_config.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:jugaad_mvp/core/theme/user_app_theme.dart';
import 'package:jugaad_mvp/core/utils/jugaad_haptics.dart';
import 'dart:math';

class CompletionScreen extends StatefulWidget {
  final String jobId;
  final String workerName;
  final int durationMinutes;

  const CompletionScreen({
    super.key,
    required this.jobId,
    required this.workerName,
    required this.durationMinutes,
  });

  @override
  State<CompletionScreen> createState() => _CompletionScreenState();
}

class _ConfettiParticle {
  final double angle;
  final double speed;
  final double size;
  final Color color;
  final double rotationSpeed;
  
  _ConfettiParticle({
    required this.angle,
    required this.speed,
    required this.size,
    required this.color,
    required this.rotationSpeed,
  });
}

class _CompletionScreenState extends State<CompletionScreen> with TickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _scaleAnimation;
  late AnimationController _confettiController;
  
  int _rating = 0;
  final TextEditingController _reviewController = TextEditingController();
  bool _isSubmitting = false;
  bool _showDrawCheck = false;
  final List<_ConfettiParticle> _particles = [];

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    _scaleAnimation = CurvedAnimation(parent: _animController, curve: Curves.elasticOut);
    
    _confettiController = AnimationController(vsync: this, duration: const Duration(milliseconds: 2500));
    _initConfetti();

    // Start animation and confetti burst on load
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        _animController.forward();
        _confettiController.forward();
        JugaadHaptics.success();
      }
    });

    _reviewController.addListener(() {
      setState(() {});
    });
  }

  void _initConfetti() {
    final rand = Random();
    final colors = [
      UserAppTheme.primaryBlue,
      UserAppTheme.skyAccent,
      UserAppTheme.successGreen,
      const Color(0xFFF59E0B), // Gold
      const Color(0xFFEC4899), // Pink
      const Color(0xFF8B5CF6), // Purple
    ];
    
    for (int i = 0; i < 70; i++) {
      _particles.add(
        _ConfettiParticle(
          angle: rand.nextDouble() * pi * 2,
          speed: 0.4 + rand.nextDouble() * 0.9,
          size: 6.0 + rand.nextDouble() * 6.0,
          color: colors[rand.nextInt(colors.length)],
          rotationSpeed: -3.0 + rand.nextDouble() * 6.0,
        ),
      );
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    _confettiController.dispose();
    _reviewController.dispose();
    super.dispose();
  }

  Future<void> _submitReview() async {
    HapticFeedback.mediumImpact();
    setState(() {
      _isSubmitting = true;
    });
    
    print('[COMPLETION] Review submitted: rating=$_rating');
    
    try {
      final jobDoc = await SupabaseConfig.client
          .from('jobs')
          .select('employer_id, worker_id')
          .eq('id', widget.jobId)
          .maybeSingle();

      if (jobDoc == null) {
        throw Exception('Job not found');
      }
          
      final employerId = jobDoc['employer_id'] as String;
      final workerId = jobDoc['worker_id'] as String?;

      if (workerId != null) {
        await SupabaseConfig.client.rpc('submit_review_atomic', params: {
          'p_job_id': widget.jobId,
          'p_reviewer_id': employerId,
          'p_reviewee_id': workerId,
          'p_rating': _rating,
          'p_comment': _reviewController.text.trim(),
        });
      }
    } catch (e) {
      print('[COMPLETION] Supabase error in submit_review: $e');
    }
    
    // Spinning loader phase
    await Future.delayed(const Duration(milliseconds: 1000));
    
    if (mounted) {
      setState(() {
        _isSubmitting = false;
        _showDrawCheck = true;
      });
      HapticFeedback.heavyImpact();
    }
    
    // Checkmark drawing phase
    await Future.delayed(const Duration(milliseconds: 1200));
    
    if (mounted) {
      context.go('/user/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: UserAppTheme.background,
      body: Stack(
        children: [
          // Custom Confetti Burst Painter Layer
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _confettiController,
                builder: (context, _) {
                  return CustomPaint(
                    painter: _ConfettiPainter(
                      progress: _confettiController.value,
                      particles: _particles,
                    ),
                  );
                },
              ),
            ),
          ),
          
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 16),
                    
                    // Success Icon Scale & Ripple
                    ScaleTransition(
                      scale: _scaleAnimation,
                      child: Container(
                        width: 90,
                        height: 90,
                        decoration: BoxDecoration(
                          color: UserAppTheme.successGreen.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: UserAppTheme.successGreen.withValues(alpha: 0.15),
                              blurRadius: 24,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.check_circle_rounded,
                          color: UserAppTheme.successGreen,
                          size: 64,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // Job Completed Success Title
                    Text(
                      'Job Completed!',
                      style: UserAppTheme.display(
                        size: 26,
                        weight: FontWeight.w800,
                        color: UserAppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Worker Summary Card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: UserAppTheme.surface,
                        borderRadius: UserAppTheme.cardBorderRadius,
                        border: Border.all(color: UserAppTheme.divider, width: 1.0),
                        boxShadow: UserAppTheme.cardShadow,
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: UserAppTheme.primaryBlue.withValues(alpha: 0.08),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: UserAppTheme.primaryBlue.withValues(alpha: 0.2), width: 1.5),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  widget.workerName.isNotEmpty ? widget.workerName.substring(0, 1).toUpperCase() : 'W',
                                  style: UserAppTheme.heading(
                                    size: 18,
                                    weight: FontWeight.bold,
                                    color: UserAppTheme.primaryBlue,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      widget.workerName,
                                      style: UserAppTheme.heading(
                                        size: 15,
                                        weight: FontWeight.bold,
                                        color: UserAppTheme.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Laptop Repair Partner',
                                      style: UserAppTheme.body(
                                        size: 12,
                                        color: UserAppTheme.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: UserAppTheme.background,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '${widget.durationMinutes} mins',
                                  style: UserAppTheme.body(
                                    size: 12,
                                    weight: FontWeight.bold,
                                    color: UserAppTheme.textPrimary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          const Divider(color: UserAppTheme.divider, height: 1),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.flash_on_rounded, color: UserAppTheme.successGreen, size: 16),
                              const SizedBox(width: 6),
                              Text(
                                'Partner arrived in 12 minutes',
                                style: UserAppTheme.label(
                                  size: 12,
                                  weight: FontWeight.bold,
                                  color: UserAppTheme.successGreen,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.1, end: 0, curve: Curves.easeOutCubic),
                    
                    const SizedBox(height: 36),
                    
                    // Star Rating Header
                    Text(
                      'Tap to rate your experience',
                      style: UserAppTheme.label(
                        size: 12,
                        weight: FontWeight.bold,
                        color: UserAppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    
                    // Interactive Stars Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(5, (index) {
                        final isSelected = index < _rating;
                        return GestureDetector(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() => _rating = index + 1);
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6.0),
                            child: Icon(
                              isSelected ? Icons.star_rounded : Icons.star_border_rounded,
                              color: isSelected ? const Color(0xFFF59E0B) : UserAppTheme.textSecondary.withValues(alpha: 0.3),
                              size: 44,
                            )
                            .animate(
                              target: isSelected ? 1.0 : 0.0,
                            )
                            .scale(
                              begin: const Offset(1.0, 1.0),
                              end: const Offset(1.25, 1.25),
                              duration: 150.ms,
                              curve: Curves.easeOutBack,
                            )
                            .then()
                            .scale(
                              begin: const Offset(1.25, 1.25),
                              end: const Offset(1.0, 1.0),
                              duration: 150.ms,
                            ),
                          ),
                        )
                        .animate()
                        .scale(
                          begin: const Offset(0.0, 0.0),
                          end: const Offset(1.0, 1.0),
                          duration: 400.ms,
                          delay: (index * 80).ms,
                          curve: Curves.elasticOut,
                        );
                      }),
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Animated review section (only visible when rating selected)
                    AnimatedSize(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                      child: _rating > 0
                          ? Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  TextField(
                                    controller: _reviewController,
                                    maxLines: 3,
                                    minLines: 3,
                                    maxLength: 200,
                                    maxLengthEnforcement: MaxLengthEnforcement.enforced,
                                    style: UserAppTheme.body(size: 14),
                                    decoration: InputDecoration(
                                      hintText: 'Share details of your experience...',
                                      hintStyle: UserAppTheme.body(size: 13, color: UserAppTheme.textSecondary.withValues(alpha: 0.6)),
                                      filled: true,
                                      fillColor: UserAppTheme.surface,
                                      counterText: '',
                                      contentPadding: const EdgeInsets.all(16),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(14),
                                        borderSide: const BorderSide(color: UserAppTheme.divider, width: 1.0),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(14),
                                        borderSide: const BorderSide(color: UserAppTheme.divider, width: 1.0),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(14),
                                        borderSide: const BorderSide(color: UserAppTheme.primaryBlue, width: 1.5),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    '${_reviewController.text.length} / 200',
                                    style: UserAppTheme.label(
                                      size: 11,
                                      color: UserAppTheme.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.1, end: 0, curve: Curves.easeOutCubic)
                          : const SizedBox.shrink(),
                    ),
                    
                    const SizedBox(height: 48),
                    
                    // Action Buttons (Vertical Stack, Equal Sizing)
                    Container(
                      height: UserAppTheme.buttonHeight,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        gradient: (_rating > 0 && !_isSubmitting && !_showDrawCheck) 
                            ? UserAppTheme.primaryGradient 
                            : null,
                        color: (_rating == 0 || _isSubmitting || _showDrawCheck) 
                            ? UserAppTheme.divider 
                            : null,
                        borderRadius: UserAppTheme.buttonBorderRadius,
                        boxShadow: (_rating > 0 && !_isSubmitting && !_showDrawCheck)
                            ? [
                                BoxShadow(
                                  color: UserAppTheme.primaryBlue.withValues(alpha: 0.2),
                                  blurRadius: 15,
                                  offset: const Offset(0, 4),
                                )
                              ]
                            : [],
                      ),
                      child: ElevatedButton(
                        onPressed: (_rating > 0 && !_isSubmitting && !_showDrawCheck) ? _submitReview : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          disabledBackgroundColor: Colors.transparent,
                          minimumSize: Size.fromHeight(UserAppTheme.buttonHeight),
                          shape: RoundedRectangleBorder(borderRadius: UserAppTheme.buttonBorderRadius),
                        ),
                        child: _isSubmitting
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                              )
                            : _showDrawCheck
                                ? TweenAnimationBuilder<double>(
                                    tween: Tween<double>(begin: 0.0, end: 1.0),
                                    duration: const Duration(milliseconds: 600),
                                    builder: (context, val, child) {
                                      return SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: CustomPaint(
                                          painter: _CheckmarkPainter(val),
                                        ),
                                      );
                                    },
                                  )
                                : Text(
                                    'Submit Review',
                                    style: UserAppTheme.body(
                                      color: _rating > 0 ? Colors.white : UserAppTheme.textSecondary,
                                      weight: FontWeight.bold,
                                      size: 15,
                                    ),
                                  ),
                      ),
                    ).animate().fadeIn(delay: 300.ms),
                    const SizedBox(height: 12),
                    
                    SizedBox(
                      height: UserAppTheme.buttonHeight,
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () => context.go('/user/book'),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: UserAppTheme.primaryBlue, width: 1.5),
                          shape: RoundedRectangleBorder(borderRadius: UserAppTheme.buttonBorderRadius),
                        ),
                        child: Text(
                          'Book ${widget.workerName} Again',
                          style: UserAppTheme.body(
                            color: UserAppTheme.primaryBlue,
                            weight: FontWeight.bold,
                            size: 15,
                          ),
                        ),
                      ),
                    ).animate().fadeIn(delay: 350.ms),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ConfettiPainter extends CustomPainter {
  final double progress;
  final List<_ConfettiParticle> particles;

  _ConfettiPainter({required this.progress, required this.particles});

  @override
  void paint(Canvas canvas, Size size) {
    if (progress == 0.0 || progress == 1.0) return;
    
    final center = Offset(size.width / 2, size.height * 0.25);
    final paint = Paint()..style = PaintingStyle.fill;
    
    for (final p in particles) {
      final distance = p.speed * progress * 240.0;
      final gravity = progress * progress * 100.0;
      
      final x = center.dx + cos(p.angle) * distance;
      final y = center.dy + sin(p.angle) * distance + gravity;
      
      paint.color = p.color.withValues(alpha: (1.0 - progress).clamp(0.0, 1.0));
      
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(p.rotationSpeed * progress * pi * 2);
      
      if (p.size % 2 == 0) {
        canvas.drawRect(Rect.fromCenter(center: Offset.zero, width: p.size, height: p.size * 0.6), paint);
      } else {
        canvas.drawCircle(Offset.zero, p.size / 2, paint);
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter oldDelegate) => oldDelegate.progress != progress;
}

class _CheckmarkPainter extends CustomPainter {
  final double progress;
  _CheckmarkPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();
    path.moveTo(size.width * 0.25, size.height * 0.5);
    path.lineTo(size.width * 0.45, size.height * 0.7);
    path.lineTo(size.width * 0.75, size.height * 0.3);

    final pathMetrics = path.computeMetrics();
    for (var metric in pathMetrics) {
      final extractPath = metric.extractPath(0.0, metric.length * progress);
      canvas.drawPath(extractPath, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _CheckmarkPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
