import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_colors.dart';

/// Animated counter that counts up from 0 to [value] over [duration].
/// Uses Nunito weight 900 for that premium display number feel.
class AnimatedCounter extends StatelessWidget {
  final int value;
  final String prefix;
  final String suffix;
  final double fontSize;
  final Color color;
  final Duration duration;
  final Curve curve;

  const AnimatedCounter({
    super.key,
    required this.value,
    this.prefix = '',
    this.suffix = '',
    this.fontSize = 36,
    this.color = AppColors.primary,
    this.duration = const Duration(milliseconds: 1200),
    this.curve = Curves.easeOut,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: value.toDouble()),
      duration: duration,
      curve: curve,
      builder: (context, animatedValue, child) {
        return Text(
          '$prefix${animatedValue.toInt()}$suffix',
          style: GoogleFonts.nunito(
            fontSize: fontSize,
            fontWeight: FontWeight.w900,
            color: color,
          ),
        );
      },
    );
  }
}

/// Double-precision animated counter — for decimal values (e.g. ratings)
class AnimatedDoubleCounter extends StatelessWidget {
  final double value;
  final String prefix;
  final String suffix;
  final int decimalPlaces;
  final double fontSize;
  final Color color;
  final Duration duration;

  const AnimatedDoubleCounter({
    super.key,
    required this.value,
    this.prefix = '',
    this.suffix = '',
    this.decimalPlaces = 1,
    this.fontSize = 36,
    this.color = AppColors.primary,
    this.duration = const Duration(milliseconds: 1200),
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: value),
      duration: duration,
      curve: Curves.easeOut,
      builder: (context, animatedValue, child) {
        return Text(
          '$prefix${animatedValue.toStringAsFixed(decimalPlaces)}$suffix',
          style: GoogleFonts.nunito(
            fontSize: fontSize,
            fontWeight: FontWeight.w900,
            color: color,
          ),
        );
      },
    );
  }
}
