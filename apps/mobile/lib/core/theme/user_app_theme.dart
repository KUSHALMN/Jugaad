import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class UserAppTheme {
  // --- COLORS (Jugaad Brand: Forest Green & Vibrant Orange) ---
  static const Color primaryColor = Color(0xFF0D7844); // Signature Forest Green
  static const Color primaryBlue = primaryColor; // Backward-compatible alias
  static const Color primaryGreen = primaryColor; // Forest Green
  static const Color accentOrange = Color(0xFFEA580C); // Signature Orange
  static const Color skyAccent = accentOrange; // Backward-compatible alias
  static const Color background = Color(0xFFF8FAFC);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color successGreen = Color(0xFF16A34A);
  static const Color urgentRed = Color(0xFFDC2626);
  static const Color divider = Color(0xFFE2E8F0);
  static const Color shadowColor = Color(0x14000000); // rgba(0,0,0,0.08)

  // --- GRADIENTS ---
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primaryColor, Color(0xFF16A34A)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient orangeGradient = LinearGradient(
    colors: [accentOrange, Color(0xFFF97316)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient successGradient = LinearGradient(
    colors: [successGreen, Color(0xFF22C55E)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient headerGradient = LinearGradient(
    colors: [Color(0xFFF0FDF4), Color(0xFFF8FAFC)],
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

  // --- TYPOGRAPHY (Google Fonts Plus Jakarta Sans everywhere) ---
  static TextStyle display({
    double size = 28.0,
    Color color = textPrimary,
    FontWeight weight = FontWeight.w800,
  }) {
    return GoogleFonts.plusJakartaSans(
      fontSize: size,
      fontWeight: weight,
      color: color,
      letterSpacing: -0.6,
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
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        primary: primaryColor,
        secondary: accentOrange,
        surface: surface,
      ),
      textTheme: TextTheme(
        displayLarge: GoogleFonts.plusJakartaSans(fontSize: 32, fontWeight: FontWeight.w800, color: textPrimary, letterSpacing: -0.6),
        displayMedium: GoogleFonts.plusJakartaSans(fontSize: 28, fontWeight: FontWeight.w800, color: textPrimary, letterSpacing: -0.5),
        headlineMedium: GoogleFonts.plusJakartaSans(fontSize: 22, fontWeight: FontWeight.w700, color: textPrimary, letterSpacing: -0.3),
        titleLarge: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w700, color: textPrimary, letterSpacing: -0.2),
        titleMedium: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w600, color: textPrimary),
        bodyLarge: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w500, color: textPrimary),
        bodyMedium: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w400, color: textSecondary),
        labelLarge: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w700, color: primaryColor),
        labelSmall: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w600, color: textSecondary),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: buttonBorderRadius,
          ),
          textStyle: GoogleFonts.plusJakartaSans(
            fontSize: 16.0,
            fontWeight: FontWeight.bold,
          ),
          minimumSize: const Size.fromHeight(buttonHeight),
        ),
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
