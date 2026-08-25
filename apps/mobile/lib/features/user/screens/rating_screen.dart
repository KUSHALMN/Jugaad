import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:jugaad_mvp/core/theme/app_colors.dart';
import 'package:jugaad_mvp/core/theme/app_text_styles.dart';
import 'package:jugaad_mvp/core/utils/jugaad_haptics.dart';

class RatingScreen extends StatefulWidget {
  final String workerName;
  const RatingScreen({super.key, this.workerName = 'Provider'});

  @override
  State<RatingScreen> createState() => _RatingScreenState();
}

class _RatingScreenState extends State<RatingScreen> with TickerProviderStateMixin {
  // PHASE 1 — Setup Controllers
  late AnimationController _submitController;     // 500ms, forward on submit
  late AnimationController _celebrationController; // 1000ms, forward after submit
  late AnimationController _ratingLottieController;

  int _selectedRating = 0;
  bool _isSubmitted = false;

  @override
  void initState() {
    super.initState();
    _submitController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _celebrationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _ratingLottieController = AnimationController(
      vsync: this,
    );
  }

  @override
  void dispose() {
    _submitController.dispose();
    _celebrationController.dispose();
    _ratingLottieController.dispose();
    super.dispose();
  }

  void _onStarTapped(int rating) {
    if (_isSubmitted) return;
    
    setState(() {
      _selectedRating = rating;
    });

    // Haptic per star tap
    JugaadHaptics.selection();

    // PHASE 2 — LOTTIE Star Rating Update progress
    if (MediaQuery.of(context).disableAnimations) {
      _ratingLottieController.value = _selectedRating / 5.0;
    } else {
      _ratingLottieController.animateTo(
        _selectedRating / 5.0,
        duration: 300.ms,
      );
    }
  }

  void _submitRating() async {
    if (_selectedRating == 0) return;

    setState(() {
      _isSubmitted = true;
    });

    // Haptic on submit
    JugaadHaptics.success();

    if (MediaQuery.of(context).disableAnimations) {
      _submitController.value = 1.0;
      _celebrationController.value = 1.0;
    } else {
      _submitController.forward();
      await Future.delayed(300.ms);
      if (mounted) _celebrationController.forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Rate Your Experience'),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 40),
                Text(
                  'How was your job with ${widget.workerName}?',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.heading2(color: AppColors.textPrimary),
                ),
                const SizedBox(height: 40),

                // PHASE 2 — LOTTIE Star Rating 
                SizedBox(
                  width: 200,
                  height: 50,
                  child: Lottie.asset(
                    'assets/lottie/stars_rating.json',
                    controller: _ratingLottieController,
                    repeat: false,
                    frameRate: FrameRate(60),
                  ),
                ),
                
                const SizedBox(height: 20),

                // Interactive Star Selection Logic
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (index) {
                    return GestureDetector(
                      onTap: () => _onStarTapped(index + 1),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                        child: Icon(
                          index < _selectedRating ? Icons.star_rounded : Icons.star_outline_rounded,
                          size: 48,
                          color: index < _selectedRating ? AppColors.warning : AppColors.textSecondary.withValues(alpha: 0.3),
                        ),
                      ),
                    );
                  }),
                ),

                const SizedBox(height: 60),

                AnimatedSwitcher(
                  duration: 400.ms,
                  transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
                  child: _isSubmitted
                      ? Container(
                          key: const ValueKey('done'),
                          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF00FF88), Color(0xFF00CC6A)],
                            ),
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.success.withValues(alpha: 0.4),
                                blurRadius: 20, spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.star, color: Colors.black, size: 18),
                              SizedBox(width: 8),
                              Text('Rating Submitted!',
                                style: TextStyle(
                                  color: Colors.black,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                )),
                            ],
                          ),
                        )
                      : SizedBox(
                          key: const ValueKey('submit'),
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _selectedRating > 0 ? _submitRating : null,
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              backgroundColor: AppColors.primary,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: const Text(
                              'Submit Review',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                ),
              ],
            ),
          ),
          
          // PHASE 2 — Celebration Burst
          if (_isSubmitted)
            Positioned.fill(
              child: IgnorePointer(
                child: RepaintBoundary(
                  child: Lottie.asset(
                    'assets/lottie/celebration_burst.json',
                    controller: _celebrationController,
                    repeat: false,
                    frameRate: FrameRate(60),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
