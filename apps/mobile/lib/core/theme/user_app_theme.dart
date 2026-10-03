import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class UserAppTheme {
  // --- COLORS ---
  static const Color primaryBlue = Color(0xFF1A56DB);
  static const Color skyAccent = Color(0xFF60A5FA);
  static const Color background = Color(0xFFF8FAFF);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color successGreen = Color(0xFF16A34A);
  static const Color urgentRed = Color(0xFFDC2626);
  static const Color divider = Color(0xFFE2E8F0);
  static const Color shadowColor = Color(0x14000000); // rgba(0,0,0,0.08)

  // --- GRADIENTS ---
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primaryBlue, Color(0xFF3B82F6)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient successGradient = LinearGradient(
    colors: [successGreen, Color(0xFF22C55E)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient headerGradient = LinearGradient(
    colors: [Color(0xFFEFF6FF), Color(0xFFF8FAFF)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  // --- CARDS & DECORATIONS ---
  static const double cardRadius = 16.0;
  static const double cardPadding = 16.0;
  static final BorderRadius cardBorderRadius = BorderRadius.circular(cardRadius);

  static final List<BoxShadow> cardShadow = [
    const BoxShadow(
      color: shadowColor,
      blurRadius: 20,
      offset: Offset(0, 4),
    ),
  ];

  // --- BUTTONS ---
  static const double buttonHeight = 52.0;
  static final BorderRadius buttonBorderRadius = BorderRadius.circular(14.0);

  // --- TYPOGRAPHY (Claude Newsreader Serif for Headlines + Plus Jakarta Sans for Body) ---
  static TextStyle display({
    double size = 28.0,
    Color color = textPrimary,
    FontWeight weight = FontWeight.w600,
  }) {
    return GoogleFonts.newsreader(
      fontSize: size,
      fontWeight: weight,
      color: color,
      letterSpacing: -0.6,
    );
  }

  static TextStyle heading({
    double size = 18.0,
    Color color = textPrimary,
    FontWeight weight = FontWeight.w600,
  }) {
    return GoogleFonts.newsreader(
      fontSize: size,
      fontWeight: weight,
      color: color,
      letterSpacing: -0.3,
    );
  }

  static TextStyle body({
    double size = 14.0,
    Color color = textPrimary,
    FontWeight weight = FontWeight.w400,
  }) {
    return GoogleFonts.plusJakartaSans(
      fontSize: size,
      fontWeight: weight,
      color: color,
    );
  }

  static TextStyle label({
    double size = 12.0,
    Color color = textSecondary,
    FontWeight weight = FontWeight.w500,
  }) {
    return GoogleFonts.plusJakartaSans(
      fontSize: size,
      fontWeight: weight,
      color: color,
    );
  }

  // --- THEME DATA INTEGRATION ---
  static ThemeData get themeData {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: background,
      fontFamily: GoogleFonts.plusJakartaSans().fontFamily,
      textTheme: TextTheme(
        displayLarge: GoogleFonts.newsreader(fontSize: 32, fontWeight: FontWeight.w600, color: textPrimary, letterSpacing: -0.6),
        displayMedium: GoogleFonts.newsreader(fontSize: 28, fontWeight: FontWeight.w600, color: textPrimary, letterSpacing: -0.5),
        headlineMedium: GoogleFonts.newsreader(fontSize: 22, fontWeight: FontWeight.w600, color: textPrimary, letterSpacing: -0.3),
        titleLarge: GoogleFonts.newsreader(fontSize: 18, fontWeight: FontWeight.w600, color: textPrimary, letterSpacing: -0.2),
        bodyLarge: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w400, color: textPrimary),
        bodyMedium: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w400, color: textSecondary),
        labelLarge: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w600, color: textPrimary),
      ),
      dividerColor: divider,
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: cardBorderRadius,
        ),
      ),
    );
  }
}
