import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:jugaad_mvp/core/theme/app_colors.dart';

class ApprovalSubmittedScreen extends StatefulWidget {
  const ApprovalSubmittedScreen({super.key});

  @override
  State<ApprovalSubmittedScreen> createState() => _ApprovalSubmittedScreenState();
}

class _ApprovalSubmittedScreenState extends State<ApprovalSubmittedScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _scaleAnimation = CurvedAnimation(parent: _animController, curve: Curves.elasticOut);
    
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) _animController.forward();
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.kBackground,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              
              ScaleTransition(
                scale: _scaleAnimation,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: AppColors.kSuccess.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check_circle, color: AppColors.kSuccess, size: 56),
                ),
              ),
              const SizedBox(height: 24),
              
              const Text(
                'Registration submitted!',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.kTextPrimary),
              ),
              const SizedBox(height: 16),
              const Text(
                "Your registration is under review. You will be notified once approved.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.kTextPrimary),
              ),
              
              const Spacer(),
              
              ElevatedButton(
                onPressed: () => context.go('/worker/home'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.kWorkerPrimary,
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('Go to home', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
