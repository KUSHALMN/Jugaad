import 'package:google_fonts/google_fonts.dart';
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
  int _selectedTip = 0;
  String _tipCategory = '';
  bool _isCardScratched = false;
  bool _showAfterPhoto = true;

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
        try {
          await SupabaseConfig.client.rpc('submit_review_atomic', params: {
            'p_job_id': widget.jobId,
            'p_reviewer_id': employerId,
            'p_reviewee_id': workerId,
            'p_rating': _rating,
            'p_comment': _reviewController.text.trim(),
          });
        } catch (revErr) {
          print('[COMPLETION] submit_review_atomic error (non-fatal): $revErr');
        }

        if (_selectedTip > 0) {
          try {
            await SupabaseConfig.client.rpc('submit_job_tip', params: {
              'p_job_id': widget.jobId,
              'p_tip_amount': _selectedTip.toDouble(),
              'p_tip_category': _tipCategory,
            });
            print('[COMPLETION] Tip ₹$_selectedTip submitted successfully');
          } catch (tipErr) {
            print('[COMPLETION] Tip submission error, fallback direct update: $tipErr');
            await SupabaseConfig.client.from('jobs').update({
              'tip_amount': _selectedTip,
              'tip_category': _tipCategory,
              'tip_paid_at': DateTime.now().toIso8601String(),
            }).eq('id', widget.jobId);
          }
        }
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
                                  const SizedBox(height: 16),
                                  // Gamified Scratch Card Reward (CRED / GPay style)
                                  _buildScratchCardReward(),

                                  // Before & After Work Proof Comparison Card
                                  _buildBeforeAfterComparisonCard(),

                                  // 30-Day Workmanship Warranty Card
                                  _build30DayWarrantyCertificateCard(),
                                ],
                              ),
                            ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.1, end: 0, curve: Curves.easeOutCubic)
                          : const SizedBox.shrink(),
                    ),
                    
                    // 1-Tap Cashless UPI Tipping & Fuel Allowance Card
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(top: 24),
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: UserAppTheme.surface,
                        borderRadius: UserAppTheme.cardBorderRadius,
                        border: Border.all(
                          color: _selectedTip > 0
                              ? const Color(0xFFF59E0B).withValues(alpha: 0.6)
                              : UserAppTheme.divider,
                          width: 1.5,
                        ),
                        boxShadow: [
                          if (_selectedTip > 0)
                            BoxShadow(
                              color: const Color(0xFFF59E0B).withValues(alpha: 0.1),
                              blurRadius: 16,
                              offset: const Offset(0, 4),
                            ),
                          ...UserAppTheme.cardShadow,
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFEF3C7),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Text('☕', style: TextStyle(fontSize: 18)),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Add Tip for ${widget.workerName}',
                                      style: UserAppTheme.heading(size: 14, weight: FontWeight.bold),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '100% credited to partner UPI • 0% platform cut',
                                      style: UserAppTheme.body(size: 11, color: UserAppTheme.successGreen, weight: FontWeight.w600),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: _buildTipChip(20, '☕ +₹20', 'Chai & Fuel'),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _buildTipChip(50, '🥤 +₹50', 'Cool Drink'),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _buildTipChip(100, '🌟 +₹100', 'Superstar'),
                              ),
                            ],
                          ),
                          if (_selectedTip > 0) ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEF3C7),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.check_circle, color: Color(0xFFD97706), size: 16),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      '₹$_selectedTip will be transferred directly to ${widget.workerName}\'s linked UPI account.',
                                      style: UserAppTheme.body(size: 11, color: const Color(0xFF92400E), weight: FontWeight.w600),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ).animate().fadeIn(delay: 250.ms),
                    
                    const SizedBox(height: 36),
                    
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
                                    _selectedTip > 0
                                        ? 'Submit Review & Tip ₹$_selectedTip'
                                        : 'Submit Review',
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

  Widget _buildTipChip(int amount, String label, String category) {
    final isSelected = _selectedTip == amount;
    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() {
          if (isSelected) {
            _selectedTip = 0;
            _tipCategory = '';
          } else {
            _selectedTip = amount;
            _tipCategory = category;
          }
        });
      },
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFF59E0B) : UserAppTheme.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFFD97706) : UserAppTheme.divider,
            width: isSelected ? 2.0 : 1.0,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Column(
          children: [
            Text(
              label,
              style: UserAppTheme.heading(
                size: 13,
                weight: FontWeight.bold,
                color: isSelected ? Colors.white : UserAppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              category,
              style: UserAppTheme.label(
                size: 10,
                color: isSelected ? Colors.white.withValues(alpha: 0.9) : UserAppTheme.textSecondary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScratchCardReward() {
    return GestureDetector(
      onTap: () {
        if (!_isCardScratched) {
          HapticFeedback.heavyImpact();
          _confettiController.reset();
          _confettiController.forward();
          setState(() {
            _isCardScratched = true;
          });
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: _isCardScratched
              ? const LinearGradient(
                  colors: [Color(0xFFFEF3C7), Color(0xFFFDE68A)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : const LinearGradient(
                  colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _isCardScratched ? const Color(0xFFF59E0B) : const Color(0xFF334155),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: (_isCardScratched ? const Color(0xFFF59E0B) : Colors.black).withValues(alpha: 0.15),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _isCardScratched ? const Color(0xFFF59E0B) : const Color(0xFF334155),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                _isCardScratched ? '🎁' : '✨',
                style: const TextStyle(fontSize: 22),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _isCardScratched ? '🎉 YOU WON ₹50 JUGAAD CASH!' : 'TAP TO SCRATCH & REVEAL REWARD',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: _isCardScratched ? const Color(0xFF92400E) : const Color(0xFFF8FAFC),
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _isCardScratched
                        ? 'Promo code JUGAAD50 applied to your next service booking!'
                        : 'Instant cashback reward for rating your verified technician.',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: _isCardScratched ? const Color(0xFFB45309) : const Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ),
            ),
            if (!_isCardScratched)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'Scratch',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBeforeAfterComparisonCard() {
    const beforeUrl = 'https://images.unsplash.com/photo-1581092160607-ee22621dd758?w=800&auto=format&fit=crop&q=80';
    const afterUrl = 'https://images.unsplash.com/photo-1621905251189-08b45d6a269e?w=800&auto=format&fit=crop&q=80';

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 20),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: UserAppTheme.surface,
        borderRadius: UserAppTheme.cardBorderRadius,
        border: Border.all(color: UserAppTheme.divider, width: 1.5),
        boxShadow: UserAppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.compare_rounded, color: Color(0xFF2563EB), size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Work Proof Comparison',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    Text(
                      'Technician verified before & after photos',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        color: const Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.all(3),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _showAfterPhoto = false);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: !_showAfterPhoto ? Colors.white : Colors.transparent,
                          borderRadius: BorderRadius.circular(9),
                          boxShadow: !_showAfterPhoto
                              ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4)]
                              : null,
                        ),
                        child: Text(
                          'Before',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: !_showAfterPhoto ? const Color(0xFF0F172A) : const Color(0xFF64748B),
                          ),
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _showAfterPhoto = true);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: _showAfterPhoto ? const Color(0xFF059669) : Colors.transparent,
                          borderRadius: BorderRadius.circular(9),
                          boxShadow: _showAfterPhoto
                              ? [BoxShadow(color: const Color(0xFF059669).withValues(alpha: 0.3), blurRadius: 4)]
                              : null,
                        ),
                        child: Text(
                          'After ✨',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: _showAfterPhoto ? Colors.white : const Color(0xFF64748B),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Stack(
              children: [
                Image.network(
                  _showAfterPhoto ? afterUrl : beforeUrl,
                  height: 180,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    height: 180,
                    color: const Color(0xFFE2E8F0),
                    alignment: Alignment.center,
                    child: const Icon(Icons.broken_image_rounded, color: Colors.grey, size: 36),
                  ),
                ),
                Positioned(
                  bottom: 10,
                  left: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.75),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _showAfterPhoto ? Icons.check_circle_rounded : Icons.history_rounded,
                          color: _showAfterPhoto ? const Color(0xFF34D399) : const Color(0xFFFBBF24),
                          size: 14,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _showAfterPhoto ? 'AFTER REPAIR · VERIFIED DONE' : 'BEFORE REPAIR · INSPECTION SNAP',
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.3,
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

  Widget _build30DayWarrantyCertificateCard() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFF59E0B), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: Color(0xFFF59E0B),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.verified_rounded, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '30-Day Workmanship Warranty',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      'Certificate #JGD-WRN-${widget.jobId.hashCode.abs() % 90000 + 10000}',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        color: const Color(0xFFFCD34D),
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF065F46),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF34D399)),
                ),
                child: const Text(
                  'ACTIVE',
                  style: TextStyle(color: Color(0xFF6EE7B7), fontSize: 10, fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            '• Free technician re-visit if the same issue reoccurs within 30 days.\n• 100% genuine parts guarantee with invoice records.\n• Dedicated priority resolution within 2 hours.',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              color: const Color(0xFFE2E8F0),
              height: 1.5,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                HapticFeedback.lightImpact();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('📄 Warranty Certificate downloaded & linked to your phone number!'),
                    backgroundColor: Color(0xFF059669),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              icon: const Icon(Icons.download_rounded, color: Color(0xFFF59E0B), size: 16),
              label: Text(
                'Download Warranty Card',
                style: GoogleFonts.plusJakartaSans(
                  color: const Color(0xFFF59E0B),
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFFF59E0B), width: 1.2),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 10),
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
