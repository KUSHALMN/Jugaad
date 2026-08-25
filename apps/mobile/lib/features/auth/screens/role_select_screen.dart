import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/portal_mode.dart';
import '../../../shared/widgets/jugaad_card.dart';

import 'package:provider/provider.dart' as pkg_provider;

class RoleSelectScreen extends StatelessWidget {
  const RoleSelectScreen({super.key});

  void _selectRole(BuildContext context, PortalMode mode) {
    pkg_provider.Provider.of<PortalModeProvider>(context, listen: false).setMode(mode);
    context.go('/auth/otp?role=${mode.name}');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Container(
          margin: const EdgeInsets.only(left: 16.0, top: 8.0, bottom: 8.0),
          decoration: BoxDecoration(
            color: AppColors.surface,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: IconButton(
            icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary, size: 20.0),
            onPressed: () => context.go('/'),
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24.0),
              
              // Animated Rounded Heading
              Text(
                'How will you use Jugaad?',
                style: AppTextStyles.heading2(color: AppColors.textPrimary).copyWith(
                  fontSize: 26.0,
                  letterSpacing: -0.5,
                ),
              ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.2, end: 0.0),
              
              const SizedBox(height: 8.0),
              
              Text(
                'Choose a portal to start. You can easily switch between them inside the app anytime.',
                style: AppTextStyles.bodyMedium(color: AppColors.textSecondary).copyWith(
                  height: 1.4,
                ),
              ).animate().fadeIn(delay: 100.ms, duration: 300.ms).slideY(begin: 0.2, end: 0.0),
              
              const SizedBox(height: 40.0),

              // User Portal Card (Booking/Saffron Accent)
              JugaadCard(
                index: 0,
                color: AppColors.surface,
                padding: EdgeInsets.zero,
                onTap: () => _selectRole(context, PortalMode.user),
                child: Container(
                  padding: const EdgeInsets.all(24.0),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.12), width: 1.0),
                    borderRadius: BorderRadius.circular(20.0),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16.0),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.08),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.person_search_rounded, color: AppColors.primary, size: 28.0),
                      ),
                      const SizedBox(width: 20.0),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'I want to Book',
                              style: AppTextStyles.heading3(color: AppColors.primary).copyWith(
                                fontSize: 18.0,
                              ),
                            ),
                            const SizedBox(height: 4.0),
                            Text(
                              'Find & book skilled workers in minutes',
                              style: AppTextStyles.bodyMedium(color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.arrow_forward_ios_rounded, color: AppColors.primary, size: 16.0),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 20.0),

              // Worker Portal Card (Earning/Emerald Green Accent)
              JugaadCard(
                index: 1,
                color: AppColors.surface,
                padding: EdgeInsets.zero,
                onTap: () => _selectRole(context, PortalMode.worker),
                child: Container(
                  padding: const EdgeInsets.all(24.0),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.success.withValues(alpha: 0.12), width: 1.0),
                    borderRadius: BorderRadius.circular(20.0),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16.0),
                        decoration: BoxDecoration(
                          color: AppColors.success.withValues(alpha: 0.08),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.handyman_rounded, color: AppColors.success, size: 28.0),
                      ),
                      const SizedBox(width: 20.0),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'I want to Earn',
                              style: AppTextStyles.heading3(color: AppColors.success).copyWith(
                                fontSize: 18.0,
                              ),
                            ),
                            const SizedBox(height: 4.0),
                            Text(
                              'Register skill & complete jobs nearby',
                              style: AppTextStyles.bodyMedium(color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.arrow_forward_ios_rounded, color: AppColors.success, size: 16.0),
                    ],
                  ),
                ),
              ),
              
              const Spacer(),
              
              // Bottom informative badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                decoration: BoxDecoration(
                  color: AppColors.secondary.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(16.0),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline_rounded, color: AppColors.secondary, size: 18.0),
                    const SizedBox(width: 12.0),
                    Expanded(
                      child: Text(
                        'Both portals operate seamlessly inside a single app profile.',
                        style: AppTextStyles.bodySmall(color: AppColors.secondary, weight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn(delay: 500.ms, duration: 400.ms),
              
              const SizedBox(height: 24.0),
            ],
          ),
        ),
      ),
    );
  }
}
