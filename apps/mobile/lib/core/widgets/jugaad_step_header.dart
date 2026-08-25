import 'package:flutter/material.dart';
import '../../core/theme/user_app_theme.dart';

class JugaadStepHeader extends StatelessWidget {
  final String title;
  final int currentStep; // 1-based index (e.g. 1, 2, 3)
  final int totalSteps; // Can be overridden or default to 4
  final VoidCallback? onBack;

  const JugaadStepHeader({
    super.key,
    required this.title,
    required this.currentStep,
    this.totalSteps = 4,
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Back button + Step label
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (onBack != null)
                  GestureDetector(
                    onTap: onBack,
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: UserAppTheme.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: UserAppTheme.divider, width: 1.0),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.03),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        size: 16,
                        color: UserAppTheme.textPrimary,
                      ),
                    ),
                  )
                else
                  const SizedBox(width: 40),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: UserAppTheme.primaryBlue.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Step $currentStep of $totalSteps',
                    style: UserAppTheme.label(
                      size: 12,
                      color: UserAppTheme.primaryBlue,
                      weight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: UserAppTheme.heading(
                size: 22,
                weight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 20),
            // 4-segmented progress bar with labels below
            Row(
              children: List.generate(4, (index) {
                final active = index < currentStep;
                final isLast = index == 3;
                final labelText = [
                  'Choose service',
                  'Details',
                  'Urgency',
                  'Confirm',
                ][index];

                return Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: EdgeInsets.only(right: isLast ? 0 : 8),
                        height: 5,
                        decoration: BoxDecoration(
                          color: active ? UserAppTheme.primaryBlue : UserAppTheme.divider,
                          borderRadius: BorderRadius.circular(2.5),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Padding(
                        padding: EdgeInsets.only(right: isLast ? 0 : 8),
                        child: Text(
                          labelText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: UserAppTheme.label(
                            size: 10,
                            color: active ? UserAppTheme.primaryBlue : UserAppTheme.textSecondary,
                            weight: active ? FontWeight.w700 : FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}

