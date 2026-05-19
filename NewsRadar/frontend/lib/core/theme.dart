import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  // Stitch Design System - NewsRadar Intelligence (Light Mode)
  static const Color primary = Color(0xFFF1F5F9);       // Light background
  static const Color primaryLight = Color(0xFFFFFFFF);  // Card Layer
  static const Color accent = Color(0xFF38BDF8);        // Sky Blue (Light Blue)
  static const Color accentDeep = Color(0xFF0284C7);    // Darker Blue for hover
  static const Color surface = Color(0xFFFFFFFF);       // Surface
  static const Color surfaceVariant = Color(0xFFF8FAFC);
  
  // Badge / Confidence colors
  static const Color badgeGreen = Color(0xFF10B981);    // Emerald
  static const Color badgeAmber = Color(0xFFF59E0B);    // Amber
  static const Color badgeRed = Color(0xFFEF4444);      // Crimson

  // Sentiment colors
  static const Color positive = badgeGreen;
  static const Color negative = badgeRed;
  static const Color neutral = Color(0xFF64748B);

  // Risk level colors
  static const Color riskLow = badgeGreen;
  static const Color riskMedium = badgeAmber;
  static const Color riskHigh = badgeRed;

  // Text
  static const Color textPrimary = Color(0xFF0F172A);   // Dark Slate
  static const Color textSecondary = Color(0xFF475569); // Slate 600
  static const Color textMuted = Color(0xFF64748B);     // Slate 500

  // Divider
  static const Color divider = Color(0xFFE2E8F0);       // Slate 200
  static const Color outlineVariant = Color(0xFFCBD5E1); // Slate 300

  // Action type colors
  static const Color actionFactCheck = Color(0xFF38BDF8);
  static const Color actionAlert = badgeAmber;
  static const Color actionFlag = badgeRed;
  static const Color actionShare = badgeGreen;
  static const Color actionArchive = textMuted;
}

class AppTheme {
  static ThemeData get light {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.primary,
      colorScheme: const ColorScheme.light(
        primary: AppColors.accent,
        secondary: AppColors.accentDeep,
        surface: AppColors.primaryLight,
        onPrimary: Colors.white,
        onSurface: AppColors.textPrimary,
        primaryContainer: AppColors.accentDeep,
      ),
      textTheme: GoogleFonts.interTextTheme(ThemeData.light().textTheme).copyWith(
        displayLarge: GoogleFonts.inter(
          fontSize: 32, fontWeight: FontWeight.w700, color: AppColors.textPrimary, letterSpacing: -0.01,
        ),
        displayMedium: GoogleFonts.inter(
          fontSize: 24, fontWeight: FontWeight.w600, color: AppColors.textPrimary, letterSpacing: -0.01,
        ),
        titleLarge: GoogleFonts.inter(
          fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textPrimary,
        ),
        titleMedium: GoogleFonts.inter(
          fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary,
        ),
        bodyLarge: GoogleFonts.inter(
          fontSize: 16, fontWeight: FontWeight.w400, color: AppColors.textPrimary, height: 1.5,
        ),
        bodyMedium: GoogleFonts.inter(
          fontSize: 14, fontWeight: FontWeight.w400, color: AppColors.textSecondary, height: 1.5,
        ),
        labelLarge: GoogleFonts.jetBrainsMono(
          fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textPrimary, letterSpacing: 0.02,
        ),
        labelSmall: GoogleFonts.jetBrainsMono(
          fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.textMuted, letterSpacing: 0.02,
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.primary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: AppColors.textPrimary),
        titleTextStyle: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          fontFamily: 'Inter',
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.primaryLight,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: AppColors.divider, width: 1),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.primaryLight,
        selectedItemColor: AppColors.accentDeep,
        unselectedItemColor: AppColors.textMuted,
        type: BottomNavigationBarType.fixed,
        elevation: 4,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.primary,
        labelStyle: GoogleFonts.jetBrainsMono(
          fontSize: 12, color: AppColors.textSecondary,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        side: const BorderSide(color: AppColors.divider),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.divider,
        thickness: 1,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          textStyle: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          side: const BorderSide(color: AppColors.divider),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          textStyle: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: AppColors.textPrimary,
        contentTextStyle: TextStyle(color: Colors.white),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(8)),
        ),
      ),
    );
  }
}
