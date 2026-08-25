import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class WorkerAppTheme {
  // --- COLORS ---
  static const Color primaryGreen = Color(0xFF16A34A);
  static const Color deepGreen = Color(0xFF14532D);
  static const Color mintAccent = Color(0xFF86EFAC);
  static const Color background = Color(0xFFF4F7F4);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color textPrimary = Color(0xFF0F1F0F);
  static const Color textSecondary = Color(0xFF4B5563);
  static const Color earningGold = Color(0xFFF59E0B);
  static const Color urgentRed = Color(0xFFDC2626);
  static const Color trustBlue = Color(0xFF2563EB);
  static const Color divider = Color(0xFFE5E7EB);
  static const Color shadowColor = Color(0x12000000); // rgba(0,0,0,0.07)

  // --- GRADIENTS ---
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primaryGreen, Color(0xFF22C55E)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient deepGreenGradient = LinearGradient(
    colors: [deepGreen, primaryGreen],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient payoutGradient = LinearGradient(
    colors: [Color(0xFF1D4ED8), Color(0xFF3B82F6)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
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
  static const double buttonHeight = 56.0;
  static final BorderRadius buttonBorderRadius = BorderRadius.circular(14.0);

  // --- TYPOGRAPHY (Plus Jakarta Sans) ---
  static TextStyle display({
    double size = 32.0,
    Color color = textPrimary,
    FontWeight weight = FontWeight.w800,
  }) {
    return GoogleFonts.plusJakartaSans(
      fontSize: size,
      fontWeight: weight,
      color: color,
    );
  }

  static TextStyle heading({
    double size = 18.0,
    Color color = textPrimary,
    FontWeight weight = FontWeight.w700,
  }) {
    return GoogleFonts.plusJakartaSans(
      fontSize: size,
      fontWeight: weight,
      color: color,
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
    FontWeight weight = FontWeight.w600,
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
        displayLarge: GoogleFonts.plusJakartaSans(fontSize: 32, fontWeight: FontWeight.w800, color: textPrimary),
        displayMedium: GoogleFonts.plusJakartaSans(fontSize: 28, fontWeight: FontWeight.w800, color: textPrimary),
        headlineMedium: GoogleFonts.plusJakartaSans(fontSize: 22, fontWeight: FontWeight.w700, color: textPrimary),
        titleLarge: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w700, color: textPrimary),
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
