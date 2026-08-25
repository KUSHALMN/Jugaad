import 'package:flutter/material.dart';

class AppColors extends ThemeExtension<AppColors> {
  // Core Accent (Dynamic based on mode, but hardcoded here for simplicity or overridden)
  final Color primary;
  final Color lightFill; // Replaced by Surface-2/3 in dark mode if needed, but Prompt says accent stays same.
  // Actually, lightFill for accents (e.g. 10% opacity) should ideally adapt, but let's keep it simple.
  
  // Neutral Surfaces
  final Color background;
  final Color surface;
  final Color surface2;
  final Color surface3;
  
  // Borders
  final Color neutralBorder;
  final Color neutralFill;
  
  // Text
  final Color neutralPrimary; // Secondary text in prompt, mapping to neutralPrimary in our code
  final Color textPrimary;
  final Color textTertiary;

  // Status (These stay the same in Dark Mode per prompt)
  final Color successPrimary;
  final Color warningPrimary;
  final Color warningFill;
  final Color warningBorder;
  final Color dangerPrimary;
  final Color dangerFill;
  final Color dangerBorder;

  const AppColors({
    required this.primary,
    required this.lightFill,
    required this.background,
    required this.surface,
    required this.surface2,
    required this.surface3,
    required this.neutralBorder,
    required this.neutralFill,
    required this.neutralPrimary,
    required this.textPrimary,
    required this.textTertiary,
    required this.successPrimary,
    required this.warningPrimary,
    required this.warningFill,
    required this.warningBorder,
    required this.dangerPrimary,
    required this.dangerFill,
    required this.dangerBorder,
  });

  @override
  ThemeExtension<AppColors> copyWith({
    Color? primary,
    Color? lightFill,
    Color? background,
    Color? surface,
    Color? surface2,
    Color? surface3,
    Color? neutralBorder,
    Color? neutralFill,
    Color? neutralPrimary,
    Color? textPrimary,
    Color? textTertiary,
  }) {
    return AppColors(
      primary: primary ?? this.primary,
      lightFill: lightFill ?? this.lightFill,
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surface2: surface2 ?? this.surface2,
      surface3: surface3 ?? this.surface3,
      neutralBorder: neutralBorder ?? this.neutralBorder,
      neutralFill: neutralFill ?? this.neutralFill,
      neutralPrimary: neutralPrimary ?? this.neutralPrimary,
      textPrimary: textPrimary ?? this.textPrimary,
      textTertiary: textTertiary ?? this.textTertiary,
      successPrimary: successPrimary,
      warningPrimary: warningPrimary,
      warningFill: warningFill,
      warningBorder: warningBorder,
      dangerPrimary: dangerPrimary,
      dangerFill: dangerFill,
      dangerBorder: dangerBorder,
    );
  }

  @override
  ThemeExtension<AppColors> lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      primary: Color.lerp(primary, other.primary, t)!,
      lightFill: Color.lerp(lightFill, other.lightFill, t)!,
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surface2: Color.lerp(surface2, other.surface2, t)!,
      surface3: Color.lerp(surface3, other.surface3, t)!,
      neutralBorder: Color.lerp(neutralBorder, other.neutralBorder, t)!,
      neutralFill: Color.lerp(neutralFill, other.neutralFill, t)!,
      neutralPrimary: Color.lerp(neutralPrimary, other.neutralPrimary, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textTertiary: Color.lerp(textTertiary, other.textTertiary, t)!,
      successPrimary: successPrimary,
      warningPrimary: warningPrimary,
      warningFill: warningFill,
      warningBorder: warningBorder,
      dangerPrimary: dangerPrimary,
      dangerFill: dangerFill,
      dangerBorder: dangerBorder,
    );
  }

  // --- LIGHT THEMES ---
  
  static AppColors lightUser() {
    return const AppColors(
      primary: Color(0xFF185FA5),
      lightFill: Color(0xFFE6F1FB),
      background: Colors.white,
      surface: Colors.white,
      surface2: Color(0xFFF8F9FA),
      surface3: Color(0xFFF1F3F5),
      neutralBorder: Color(0xFFD3D8DB),
      neutralFill: Color(0xFFF2F4F5),
      textPrimary: Colors.black,
      neutralPrimary: Color(0xFF5F5E5A), // Secondary text
      textTertiary: Color(0xFF8A8A8A),
      successPrimary: Color(0xFF0F6E56),
      warningPrimary: Color(0xFFBA7517),
      warningFill: Color(0xFFFAEEDA),
      warningBorder: Color(0xFFEF9F27),
      dangerPrimary: Color(0xFFA32D2D),
      dangerFill: Color(0xFFFCEBEB),
      dangerBorder: Color(0xFFE2A1A1),
    );
  }

  static AppColors lightWorker() {
    return lightUser().copyWith(
      primary: const Color(0xFF0F6E56),
      lightFill: const Color(0xFFE1F5EE),
    ) as AppColors;
  }

  // --- DARK THEMES ---
  
  static AppColors darkUser() {
    return const AppColors(
      primary: Color(0xFF185FA5), // Accents stay same
      lightFill: Color(0xFF1E3A5F), // Adjusted for dark mode contrast if heavily used, or keep accent logic
      background: Color(0xFF121212),
      surface: Color(0xFF1E1E1E),
      surface2: Color(0xFF2A2A2A),
      surface3: Color(0xFF333333),
      neutralBorder: Color(0xFF3A3A3A),
      neutralFill: Color(0xFF2A2A2A), // mapping neutral fill to surface 2
      textPrimary: Color(0xFFF5F3ED),
      neutralPrimary: Color(0xFF9E9C96), // Text secondary
      textTertiary: Color(0xFF6B6966),
      // Status colors remain the same per prompt
      successPrimary: Color(0xFF0F6E56),
      warningPrimary: Color(0xFFBA7517),
      warningFill: Color(0xFF332716), // Darkened fills for amber so text is readable
      warningBorder: Color(0xFFBA7517),
      dangerPrimary: Color(0xFFA32D2D),
      dangerFill: Color(0xFF331616),
      dangerBorder: Color(0xFFA32D2D),
    );
  }

  static AppColors darkWorker() {
    return darkUser().copyWith(
      primary: const Color(0xFF0F6E56), // Worker Teal
      lightFill: const Color(0xFF16332B), // Dark tinted teal
    ) as AppColors;
  }
}

class AppTheme {
  static ThemeData getLightTheme({required String mode}) {
    final colors = mode == 'worker' ? AppColors.lightWorker() : AppColors.lightUser();
    return ThemeData(
      brightness: Brightness.light,
      primaryColor: colors.primary,
      scaffoldBackgroundColor: colors.background,
      fontFamily: 'Inter',
      extensions: [colors],
      appBarTheme: AppBarTheme(
        backgroundColor: colors.background,
        elevation: 0,
        iconTheme: IconThemeData(color: colors.textPrimary),
        titleTextStyle: TextStyle(color: colors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
      ),
      textTheme: TextTheme(
        bodyLarge: TextStyle(color: colors.textPrimary),
        bodyMedium: TextStyle(color: colors.textPrimary),
      ),
    );
  }

  static ThemeData getDarkTheme({required String mode}) {
    final colors = mode == 'worker' ? AppColors.darkWorker() : AppColors.darkUser();
    return ThemeData(
      brightness: Brightness.dark,
      primaryColor: colors.primary,
      scaffoldBackgroundColor: colors.background,
      fontFamily: 'Inter',
      extensions: [colors],
      appBarTheme: AppBarTheme(
        backgroundColor: colors.background,
        elevation: 0,
        iconTheme: IconThemeData(color: colors.textPrimary),
        titleTextStyle: TextStyle(color: colors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
      ),
      textTheme: TextTheme(
        bodyLarge: TextStyle(color: colors.textPrimary),
        bodyMedium: TextStyle(color: colors.textPrimary),
      ),
    );
  }
}
