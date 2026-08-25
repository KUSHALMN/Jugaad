import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

enum JugaadButtonType { primary, secondary, success, danger }

class JugaadButton extends StatefulWidget {
  final String text;
  final VoidCallback? onPressed;
  final JugaadButtonType type;
  final bool isLoading;
  final bool isLiquidLoading;
  final String? loadingText;
  final Widget? icon;
  final double? width;
  final double height;

  const JugaadButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.type = JugaadButtonType.primary,
    this.isLoading = false,
    this.isLiquidLoading = false,
    this.loadingText,
    this.icon,
    this.width,
    this.height = 52.0,
  });

  @override
  State<JugaadButton> createState() => _JugaadButtonState();
}

class _JugaadButtonState extends State<JugaadButton> with SingleTickerProviderStateMixin {
  double _scale = 1.0;
  late AnimationController _liquidController;
  late Animation<double> _liquidAnimation;

  @override
  void initState() {
    super.initState();
    _liquidController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    _liquidAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _liquidController, curve: Curves.easeInOutQuad),
    );

    if (widget.isLoading && widget.isLiquidLoading) {
      _liquidController.forward();
    }
  }

  @override
  void didUpdateWidget(JugaadButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isLoading && widget.isLiquidLoading) {
      _liquidController.reset();
      _liquidController.forward();
    } else if (!widget.isLoading) {
      _liquidController.stop();
      _liquidController.reset();
    }
  }

  @override
  void dispose() {
    _liquidController.dispose();
    super.dispose();
  }

  Color get _backgroundColor {
    if (widget.onPressed == null) return Colors.grey.shade300;
    switch (widget.type) {
      case JugaadButtonType.primary:
        return AppColors.primary;
      case JugaadButtonType.secondary:
        return Colors.white;
      case JugaadButtonType.success:
        return AppColors.success;
      case JugaadButtonType.danger:
        return AppColors.danger;
    }
  }

  Color get _textColor {
    if (widget.onPressed == null) return Colors.grey.shade500;
    switch (widget.type) {
      case JugaadButtonType.secondary:
        return AppColors.primary;
      default:
        return Colors.white;
    }
  }

  Border? get _border {
    if (widget.type == JugaadButtonType.secondary && widget.onPressed != null) {
      return Border.all(color: AppColors.primary, width: 2.0);
    }
    return null;
  }

  List<BoxShadow> get _boxShadows {
    if (widget.onPressed == null) return [];
    if (widget.type == JugaadButtonType.secondary) return [];
    double blur = _scale == 1.0 ? 15.0 : 6.0;
    double offset = _scale == 1.0 ? 4.0 : 2.0;
    Color shadowColor = _backgroundColor.withValues(alpha: 0.3);
    
    return [
      BoxShadow(
        color: shadowColor,
        blurRadius: blur,
        offset: Offset(0, offset),
      )
    ];
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) {
        if (widget.onPressed != null && !widget.isLoading) {
          setState(() => _scale = 0.95);
        }
      },
      onTapUp: (_) {
        if (widget.onPressed != null && !widget.isLoading) {
          setState(() => _scale = 1.0);
        }
      },
      onTapCancel: () {
        if (widget.onPressed != null && !widget.isLoading) {
          setState(() => _scale = 1.0);
        }
      },
      onTap: () {
        if (widget.isLoading) return;
        if (widget.onPressed != null) {
          HapticFeedback.lightImpact(); // Wow Haptic on every button tap!
          widget.onPressed!();
        }
      },
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOutCubic,
        child: Container(
          width: widget.width ?? double.infinity,
          height: widget.height,
          decoration: BoxDecoration(
            color: _backgroundColor,
            borderRadius: BorderRadius.circular(50.0), // Pill shape
            border: _border,
            boxShadow: _boxShadows,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(50.0),
            child: Stack(
              children: [
                // Liquid loader background sweep (only for primary/success/danger buttons when isLiquidLoading is true)
                if (widget.isLoading && widget.isLiquidLoading && widget.type != JugaadButtonType.secondary)
                  AnimatedBuilder(
                    animation: _liquidAnimation,
                    builder: (context, child) {
                      return FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: _liquidAnimation.value,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: widget.type == JugaadButtonType.primary
                                  ? [AppColors.primary, const Color(0xFFFF8C42)]
                                  : [AppColors.success, const Color(0xFF34D399)],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                
                Center(
                  child: widget.isLoading
                      ? (widget.isLiquidLoading
                          ? Text(
                              widget.loadingText ?? 'Finding worker...',
                              style: AppTextStyles.bodyLarge(
                                color: _textColor,
                                weight: FontWeight.bold,
                              ),
                            )
                          : SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                valueColor: AlwaysStoppedAnimation<Color>(_textColor),
                              ),
                            ))
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (widget.icon != null) ...[
                              widget.icon!,
                              const SizedBox(width: 8.0),
                            ],
                            Text(
                              widget.text,
                              style: AppTextStyles.bodyLarge(
                                color: _textColor,
                                weight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
