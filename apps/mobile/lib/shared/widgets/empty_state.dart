import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import 'jugaad_button.dart';

/// Reusable empty state widget — shown whenever a list has no content.
/// Never use plain text centered on screen — use this widget instead.
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String heading;
  final String subtitle;
  final String? buttonText;
  final VoidCallback? onButtonPressed;
  final Color? iconColor;
  final Color? iconBackground;

  const EmptyState({
    super.key,
    required this.icon,
    required this.heading,
    required this.subtitle,
    this.buttonText,
    this.onButtonPressed,
    this.iconColor,
    this.iconBackground,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Large icon in 100px circle with orange tint
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: iconBackground ?? AppColors.accentHighlight,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 44,
                color: iconColor ?? AppColors.primary,
              ),
            )
                .animate()
                .fadeIn(duration: 400.ms)
                .scale(begin: const Offset(0.8, 0.8), end: const Offset(1.0, 1.0), curve: Curves.easeOutBack),

            const SizedBox(height: 24),

            // Bold heading
            Text(
              heading,
              textAlign: TextAlign.center,
              style: AppTextStyles.heading3(color: AppColors.textPrimary),
            )
                .animate()
                .fadeIn(delay: 100.ms, duration: 350.ms)
                .slideY(begin: 0.2, end: 0),

            const SizedBox(height: 8),

            // Grey subtitle
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMedium(
                color: AppColors.textSecondary,
                weight: FontWeight.w400,
              ),
            )
                .animate()
                .fadeIn(delay: 180.ms, duration: 350.ms),

            if (buttonText != null && onButtonPressed != null) ...[
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: JugaadButton(
                  text: buttonText!,
                  onPressed: onButtonPressed,
                ),
              )
                  .animate()
                  .fadeIn(delay: 260.ms, duration: 350.ms)
                  .slideY(begin: 0.2, end: 0),
            ],
          ],
        ),
      ),
    );
  }
}
