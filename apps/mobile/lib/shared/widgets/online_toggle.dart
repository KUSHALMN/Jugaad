import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

/// Custom animated online/offline toggle for worker portal.
/// 60px wide pill — offline: grey, online: emerald green with pulsing glow ring.
/// 400ms smooth transition.
class OnlineToggle extends StatefulWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const OnlineToggle({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  State<OnlineToggle> createState() => _OnlineToggleState();
}

class _OnlineToggleState extends State<OnlineToggle>
    with TickerProviderStateMixin {
  late AnimationController _glowController;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _glowAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );
    if (widget.value) {
      _glowController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(OnlineToggle oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value && !oldWidget.value) {
      _glowController.repeat(reverse: true);
    } else if (!widget.value && oldWidget.value) {
      _glowController.stop();
      _glowController.reset();
    }
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  void _handleTap() {
    widget.onChanged(!widget.value);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _handleTap,
      child: AnimatedBuilder(
        animation: _glowAnimation,
        builder: (context, child) {
          return Stack(
            alignment: Alignment.center,
            children: [
              // Pulsing glow ring when online
              if (widget.value)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 400),
                  width: 72,
                  height: 36,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.success.withValues(
                            alpha: 0.3 * _glowAnimation.value),
                        blurRadius: 12,
                        spreadRadius: 3,
                      ),
                    ],
                  ),
                ),
              // Main toggle pill
              AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeInOut,
                width: 60,
                height: 32,
                decoration: BoxDecoration(
                  color: widget.value
                      ? AppColors.success
                      : const Color(0xFFE5E7EB),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Stack(
                  children: [
                    // Thumb
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 400),
                      curve: Curves.easeInOut,
                      left: widget.value ? 30 : 2,
                      top: 2,
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.15),
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        child: widget.value
                            ? const Icon(Icons.check,
                                color: AppColors.success, size: 14)
                            : null,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Compact online status row widget — toggle + status text + description.
/// Drop this directly into a JugaadCard for the worker home screen.
class OnlineStatusRow extends StatelessWidget {
  final bool isOnline;
  final ValueChanged<bool> onChanged;

  const OnlineStatusRow({
    super.key,
    required this.isOnline,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Status icon
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: isOnline
                ? AppColors.success.withValues(alpha: 0.12)
                : AppColors.textSecondary.withValues(alpha: 0.08),
            shape: BoxShape.circle,
          ),
          child: Icon(
            isOnline ? Icons.wifi_rounded : Icons.wifi_off_rounded,
            color: isOnline ? AppColors.success : AppColors.textSecondary,
            size: 22,
          ),
        ),
        const SizedBox(width: 14),
        // Status text
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Text(
                  isOnline ? "You're online 🟢" : "You're offline",
                  key: ValueKey(isOnline),
                  style: AppTextStyles.heading4(
                    color: isOnline ? AppColors.success : AppColors.textSecondary,
                  ),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                isOnline
                    ? 'Receiving nearby job requests'
                    : 'Toggle to start earning',
                style: AppTextStyles.bodySmall(
                  color: AppColors.textSecondary,
                  weight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        // Toggle
        OnlineToggle(value: isOnline, onChanged: onChanged),
      ],
    );
  }
}
