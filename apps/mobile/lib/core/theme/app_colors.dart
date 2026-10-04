import 'package:flutter/material.dart';

class AppColors {
  // BRAND COLOR PALETTE
  static const Color background = Color(0xFFF8FAFC); // clean, crisp neutral background
  static const Color surface = Color(0xFFFFFFFF); // elevated surfaces/cards
  
  // JUGAAD Brand Colors: Green and Orange
  static const Color primary = Color(0xFF0D7844); // Signature Forest/Emerald Green
  static const Color primaryLight = Color(0xFF059669); // Bright emerald green
  static const Color secondary = Color(0xFFEA580C); // Signature Warm Orange
  static const Color secondaryLight = Color(0xFFF97316); // Bright Orange
  static const Color accentOrange = Color(0xFFF25C05); // Action Orange
  
  static const Color success = Color(0xFF16A34A); // forest green (success/online/earnings)
  static const Color warning = Color(0xFFF59E0B); // amber (warning/pending)
  static const Color danger = Color(0xFFDC2626); // red (danger/logout)
  
  static const Color textPrimary = Color(0xFF0F172A); // dark slate text
  static const Color textSecondary = Color(0xFF64748B); // slate gray text
  static const Color accentHighlight = Color(0xFFF0FDF4); // light mint tint for card backgrounds
  static const Color accentOrangeLight = Color(0xFFFFF7ED); // light orange tint for badges/highlights

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, Color(0xFF16A34A)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient brandGradient = LinearGradient(
    colors: [primary, secondary],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient secondaryGradient = LinearGradient(
    colors: [secondary, Color(0xFFF97316)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Compatibility Aliases for existing features
  static const Color kUserPrimary = primary;
  static const Color kUserPrimaryLight = accentHighlight;
  static const Color kUserBorder = Color(0xFFDCFCE7);
  static const Color kWorkerPrimary = primary;
  static const Color kWorkerPrimaryLight = accentHighlight;
  static const Color kWorkerBorder = Color(0xFFDCFCE7);
  static const Color kAdminPrimary = primary;
  static const Color kWarning = warning;
  static const Color kWarningLight = Color(0xFFFFFBEB);
  static const Color kWarningBorder = warning;
  static const Color kDanger = danger;
  static const Color kDangerLight = Color(0xFFFEF2F2);
  static const Color kDangerBorder = danger;
  static const Color kSuccess = success;
  static const Color kNeutral = textSecondary;
  static const Color kNeutralLight = background;
  static const Color kNeutralBorder = Color(0xFFE2E8F0);
  static const Color kBackground = background;
  static const Color kSurface = surface;
  static const Color kSurface2 = background;
  static const Color kSurface3 = Color(0xFFE2E8F0);
  static const Color kBorder = Color(0xFFE2E8F0);
  static const Color kTextPrimary = textPrimary;
  static const Color kTextSecond = textSecondary;
  static const Color kTextTertiary = textSecondary;

  // Extra helper for opacity rings
  static Color opacityColor(Color color, double opacity) {
    return color.withValues(alpha: opacity);
  }
}
