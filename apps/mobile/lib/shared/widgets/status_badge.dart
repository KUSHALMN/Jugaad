import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

enum BadgeStatus {
  completed,
  pending,
  active,
  cancelled,
  // Job-specific statuses
  searching,
  assigned,
  inProgress,
}

class StatusBadge extends StatelessWidget {
  final String? customText;
  final BadgeStatus status;
  final bool compact;
  final Color? color;

  const StatusBadge({
    super.key,
    required this.status,
    this.customText,
    this.compact = false,
    this.color,
  });

  Color get _color {
    if (color != null) return color!;
    switch (status) {
      case BadgeStatus.completed:
        return AppColors.success;
      case BadgeStatus.pending:
        return AppColors.warning;
      case BadgeStatus.active:
        return AppColors.primary;
      case BadgeStatus.cancelled:
        return AppColors.danger;
      case BadgeStatus.searching:
        return AppColors.primary;
      case BadgeStatus.assigned:
        return AppColors.warning;
      case BadgeStatus.inProgress:
        return AppColors.success;
    }
  }

  String get _text {
    if (customText != null) return customText!;
    switch (status) {
      case BadgeStatus.completed:
        return 'Completed';
      case BadgeStatus.pending:
        return 'Pending';
      case BadgeStatus.active:
        return 'Active';
      case BadgeStatus.cancelled:
        return 'Cancelled';
      case BadgeStatus.searching:
        return 'Searching';
      case BadgeStatus.assigned:
        return 'Worker Assigned';
      case BadgeStatus.inProgress:
        return 'In Progress';
    }
  }

  bool get _hasPulse =>
      status == BadgeStatus.active ||
      status == BadgeStatus.searching ||
      status == BadgeStatus.inProgress;

  @override
  Widget build(BuildContext context) {
    final padding = compact
        ? const EdgeInsets.symmetric(vertical: 3.0, horizontal: 8.0)
        : const EdgeInsets.symmetric(vertical: 5.0, horizontal: 10.0);

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(50.0),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_hasPulse) ...[
            Container(
              width: compact ? 6.0 : 7.0,
              height: compact ? 6.0 : 7.0,
              decoration: BoxDecoration(
                color: _color,
                shape: BoxShape.circle,
              ),
            )
                .animate(onPlay: (controller) => controller.repeat(reverse: true))
                .scale(
                    begin: const Offset(0.7, 0.7),
                    end: const Offset(1.3, 1.3),
                    duration: 800.ms)
                .fadeIn(duration: 800.ms),
            const SizedBox(width: 5.0),
          ],
          Text(
            _text,
            style: (compact ? AppTextStyles.bodySmall : AppTextStyles.bodySmall)(
              color: _color,
              weight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
