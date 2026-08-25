import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

enum JugaadToastType { success, error, info }

class JugaadToast {
  static void show(
    BuildContext context, {
    required String message,
    JugaadToastType type = JugaadToastType.success,
  }) {
    // Trigger proper haptic feedback based on toast type
    switch (type) {
      case JugaadToastType.success:
        HapticFeedback.mediumImpact();
        break;
      case JugaadToastType.error:
        HapticFeedback.vibrate();
        break;
      case JugaadToastType.info:
        HapticFeedback.lightImpact();
        break;
    }

    final overlayState = Overlay.of(context);
    late OverlayEntry overlayEntry;

    overlayEntry = OverlayEntry(
      builder: (context) => _JugaadToastWidget(
        message: message,
        type: type,
        onDismiss: () => overlayEntry.remove(),
      ),
    );

    overlayState.insert(overlayEntry);
  }
}

class _JugaadToastWidget extends StatefulWidget {
  final String message;
  final JugaadToastType type;
  final VoidCallback onDismiss;

  const _JugaadToastWidget({
    required this.message,
    required this.type,
    required this.onDismiss,
  });

  @override
  State<_JugaadToastWidget> createState() => _JugaadToastWidgetState();
}

class _JugaadToastWidgetState extends State<_JugaadToastWidget> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _slideAnimation = Tween<double>(begin: -100, end: 0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _controller.forward();

    // Auto dismiss after 3 seconds
    Future.delayed(const Duration(milliseconds: 3000), () {
      if (mounted) {
        _dismiss();
      }
    });
  }

  void _dismiss() {
    _controller.reverse().then((_) => widget.onDismiss());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Color leftBorderColor;
    IconData icon;
    Color iconColor;

    switch (widget.type) {
      case JugaadToastType.success:
        leftBorderColor = AppColors.success;
        icon = Icons.check_circle_rounded;
        iconColor = AppColors.success;
        break;
      case JugaadToastType.error:
        leftBorderColor = AppColors.danger;
        icon = Icons.error_rounded;
        iconColor = AppColors.danger;
        break;
      case JugaadToastType.info:
        leftBorderColor = AppColors.primary;
        icon = Icons.info_rounded;
        iconColor = AppColors.primary;
        break;
    }

    return SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Transform.translate(
              offset: Offset(0, _slideAnimation.value),
              child: Opacity(
                opacity: _fadeAnimation.value,
                child: child,
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: Material(
              color: Colors.transparent,
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  _dismiss();
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16.0),
                    border: Border(
                      left: BorderSide(color: leftBorderColor, width: 5.0),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 15.0,
                        offset: const Offset(0, 8.0),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Icon(icon, color: iconColor, size: 24.0),
                      const SizedBox(width: 12.0),
                      Expanded(
                        child: Text(
                          widget.message,
                          style: AppTextStyles.bodyMedium(
                            color: AppColors.textPrimary,
                            weight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
