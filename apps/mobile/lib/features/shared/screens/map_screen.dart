import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:jugaad_mvp/core/theme/app_colors.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> with TickerProviderStateMixin {
  late AnimationController _pinPulseController; // 1500ms, repeat reverse
  late AnimationController _entryController;    // 600ms, forward on init
  late AnimationController _workerDotController; // 2000ms, repeat

  bool _animationsInitialized = false;

  @override
  void initState() {
    super.initState();
    
    // PHASE 1 — Setup Controllers
    _pinPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _workerDotController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_animationsInitialized) {
      _animationsInitialized = true;
      if (MediaQuery.of(context).disableAnimations) {
        _pinPulseController.value = 1.0;
        _entryController.value = 1.0;
        _workerDotController.value = 1.0;
      } else {
        _pinPulseController.repeat(reverse: true);
        _entryController.forward();
        _workerDotController.repeat();
      }
    }
  }

  @override
  void dispose() {
    _pinPulseController.dispose();
    _entryController.dispose();
    _workerDotController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Map'),
      ),
      body: Stack(
        children: [
          // Mock Existing Map Logic (placeholder)
          Container(
            color: const Color(0xFFE2E8F0),
            child: const Center(
              child: Text('Map View Placeholder'),
            ),
          ),
          
          // PHASE 2 — LOTTIE Location Pin Overlay
          Positioned(
            top: MediaQuery.of(context).size.height / 2 - 30,
            left: MediaQuery.of(context).size.width / 2 - 30,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.8, end: 1.2).animate(
                CurvedAnimation(
                  parent: _pinPulseController,
                  curve: Curves.easeInOut,
                ),
              ),
              child: RepaintBoundary(
                child: SizedBox(
                  width: 60,
                  height: 60,
                  child: Lottie.asset(
                    'assets/lottie/location_pin.json',
                    repeat: true,
                    frameRate: FrameRate(30),
                  ),
                ),
              ),
            ),
          ),
          
          // PHASE 3 — Worker Dot Pulse Aura
          Positioned(
            top: MediaQuery.of(context).size.height / 3,
            left: MediaQuery.of(context).size.width / 3,
            child: AnimatedBuilder(
              animation: _workerDotController,
              builder: (context, child) {
                final scale = 1.0 + (_workerDotController.value * 0.6);
                final opacity = (1.0 - _workerDotController.value) * 0.4;
                return Stack(
                  alignment: Alignment.center,
                  children: [
                    Transform.scale(
                      scale: scale,
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.primary.withValues(alpha: opacity), // Using AppColors.primary as cyan alternative
                        ),
                      ),
                    ),
                    child!,
                  ],
                );
              },
              child: Container(
                width: 14,
                height: 14,
                decoration: const BoxDecoration(
                  color: AppColors.success,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // PHASE 4 — Bottom Sheet Slide Entry
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 20,
                    offset: Offset(0, -5),
                  )
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Searching for Providers...',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'We are finding the best match nearby.',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            )
            .animate(controller: _entryController)
            .slideY(begin: 0.5, duration: 500.ms, curve: Curves.easeOutCubic)
            .fadeIn(duration: 400.ms),
          ),
        ],
      ),
    );
  }
}
