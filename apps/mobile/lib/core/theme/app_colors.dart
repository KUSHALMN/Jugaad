import 'package:flutter/material.dart';

class AppColors {
  // BRAND COLOR PALETTE
  static const Color background = Color(0xFFF8FAFF); // premium background color
  static const Color surface = Color(0xFFFFFFFF); // elevated surfaces/cards
  
  static const Color primary = Color(0xFF1A56DB); // primary blue — modern, premium
  static const Color secondary = Color(0xFF7C3AED); // electric violet — premium, modern
  
  static const Color success = Color(0xFF16A34A); // forest green (success/online/earnings)
  static const Color warning = Color(0xFFF59E0B); // amber (warning/pending)
  static const Color danger = Color(0xFFDC2626); // red (danger/logout)
  
  static const Color textPrimary = Color(0xFF0F172A); // dark slate text
  static const Color textSecondary = Color(0xFF64748B); // slate gray text
  static const Color accentHighlight = Color(0xFFEFF6FF); // light blue tint for card backgrounds

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, Color(0xFFFF8C42)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient secondaryGradient = LinearGradient(
    colors: [primary, secondary],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Compatibility Aliases for existing features
  static const Color kUserPrimary = primary;
  static const Color kUserPrimaryLight = accentHighlight;
  static const Color kUserBorder = accentHighlight;
  static const Color kWorkerPrimary = success; // emerald green
  static const Color kWorkerPrimaryLight = Color(0xFFE1F5EE);
  static const Color kWorkerBorder = success;
  static const Color kAdminPrimary = secondary;
  static const Color kWarning = warning;
  static const Color kWarningLight = Color(0xFFFFFBEB);
  static const Color kWarningBorder = warning;
  static const Color kDanger = danger;
  static const Color kDangerLight = Color(0xFFFEF2F2);
  static const Color kDangerBorder = danger;
  static const Color kSuccess = success;
  static const Color kNeutral = textSecondary;
  static const Color kNeutralLight = background;
  static const Color kNeutralBorder = Color(0xFFE5E7EB);
  static const Color kBackground = background;
  static const Color kSurface = surface;
  static const Color kSurface2 = background;
  static const Color kSurface3 = Color(0xFFE5E7EB);
  static const Color kBorder = Color(0xFFE5E7EB);
  static const Color kTextPrimary = textPrimary;
  static const Color kTextSecond = textSecondary;
  static const Color kTextTertiary = textSecondary;

  // Extra helper for opacity rings
  static Color opacityColor(Color color, double opacity) {
    return color.withValues(alpha: opacity);
  }
}
