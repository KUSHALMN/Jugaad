import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// Global Typography System
/// Powered strictly by Google Fonts 'Plus Jakarta Sans' across all headlines and body
/// for a 100% unified, consistent, modern, readable brand experience.
class AppTextStyles {
  // Headings: Plus Jakarta Sans — modern, crisp, geometric humanist
  static TextStyle heading1({Color color = AppColors.textPrimary}) => GoogleFonts.plusJakartaSans(
        fontSize: 32,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.6,
        color: color,
      );

  static TextStyle heading2({Color color = AppColors.textPrimary}) => GoogleFonts.plusJakartaSans(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.4,
        color: color,
      );

  static TextStyle heading3({Color color = AppColors.textPrimary}) => GoogleFonts.plusJakartaSans(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
        color: color,
      );

  static TextStyle heading4({Color color = AppColors.textPrimary}) => GoogleFonts.plusJakartaSans(
        fontSize: 17,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
        color: color,
      );

  // Body: Google Fonts 'Plus Jakarta Sans' — clean, modern, ultra-readable
  static TextStyle bodyLarge({Color color = AppColors.textPrimary, FontWeight weight = FontWeight.w500}) =>
      GoogleFonts.plusJakartaSans(
        fontSize: 16,
        fontWeight: weight,
        color: color,
        height: 1.5,
      );

  static TextStyle bodyMedium({Color color = AppColors.textSecondary, FontWeight weight = FontWeight.w400}) =>
      GoogleFonts.plusJakartaSans(
        fontSize: 14,
        fontWeight: weight,
        color: color,
        height: 1.45,
      );

  static TextStyle bodySmall({Color color = AppColors.textSecondary, FontWeight weight = FontWeight.w400}) =>
      GoogleFonts.plusJakartaSans(
        fontSize: 12,
        fontWeight: weight,
        color: color,
        height: 1.4,
      );

  // Numbers/Stats: Plus Jakarta Sans display
  static TextStyle numbersDisplay({double fontSize = 36, Color color = AppColors.primary}) =>
      GoogleFonts.plusJakartaSans(
        fontSize: fontSize,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.5,
        color: color,
      );

  // Display Hero: Extra large for hero banners / milestone totals
  static TextStyle displayHero({double fontSize = 44, Color color = AppColors.textPrimary}) =>
      GoogleFonts.plusJakartaSans(
        fontSize: fontSize,
        fontWeight: FontWeight.w800,
        color: color,
        letterSpacing: -1.0,
        height: 1.15,
      );

  // Label Caps: Small-caps uppercase tracking for section headers
  static TextStyle labelCaps({Color color = AppColors.textPrimary}) =>
      GoogleFonts.plusJakartaSans(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: color,
        letterSpacing: 1.2,
      );
}
