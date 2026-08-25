import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTextStyles {
  // Headings: Google Fonts 'Nunito' — weight 800, bold, rounded feel
  static TextStyle heading1({Color color = AppColors.textPrimary}) => GoogleFonts.nunito(
        fontSize: 28,
        fontWeight: FontWeight.w800,
        color: color,
      );

  static TextStyle heading2({Color color = AppColors.textPrimary}) => GoogleFonts.nunito(
        fontSize: 22,
        fontWeight: FontWeight.w800,
        color: color,
      );

  static TextStyle heading3({Color color = AppColors.textPrimary}) => GoogleFonts.nunito(
        fontSize: 18,
        fontWeight: FontWeight.w800,
        color: color,
      );

  static TextStyle heading4({Color color = AppColors.textPrimary}) => GoogleFonts.nunito(
        fontSize: 16,
        fontWeight: FontWeight.w800,
        color: color,
      );

  // Body: Google Fonts 'DM Sans' — weight 400/500, clean and readable
  static TextStyle bodyLarge({Color color = AppColors.textPrimary, FontWeight weight = FontWeight.w500}) => GoogleFonts.dmSans(
        fontSize: 16,
        fontWeight: weight,
        color: color,
      );

  static TextStyle bodyMedium({Color color = AppColors.textSecondary, FontWeight weight = FontWeight.w400}) => GoogleFonts.dmSans(
        fontSize: 14,
        fontWeight: weight,
        color: color,
      );

  static TextStyle bodySmall({Color color = AppColors.textSecondary, FontWeight weight = FontWeight.w400}) => GoogleFonts.dmSans(
        fontSize: 12,
        fontWeight: weight,
        color: color,
      );

  // Numbers/Stats: Nunito weight 900, large display size
  static TextStyle numbersDisplay({double fontSize = 36, Color color = AppColors.primary}) => GoogleFonts.nunito(
        fontSize: fontSize,
        fontWeight: FontWeight.w900,
        color: color,
      );

  // Display Hero: Nunito 900, extra large for earnings/key metrics
  static TextStyle displayHero({double fontSize = 48, Color color = AppColors.textPrimary}) => GoogleFonts.nunito(
        fontSize: fontSize,
        fontWeight: FontWeight.w900,
        color: color,
        letterSpacing: -1.0,
      );

  // Label Caps: Small-caps uppercase tracking for section headers
  static TextStyle labelCaps({Color color = AppColors.textPrimary}) => GoogleFonts.dmSans(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: color,
        letterSpacing: 1.2,
      );
}
