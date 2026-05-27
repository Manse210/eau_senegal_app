import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  PALETTE — Style "Fitness App Clean"
// ─────────────────────────────────────────────────────────────────────────────
class AppColors {
  AppColors._();

  // Fonds
  static const background   = Color(0xFFF4F7FB); // gris très clair
  static const surface      = Colors.white;
  static const surfaceAlt   = Color(0xFFF0F4FF); // fond bleu pâle

  // Couleurs principales
  static const primary      = Color(0xFF1565C0); // bleu profond
  static const primaryLight = Color(0xFF1E88E5); // bleu vif
  static const cyan         = Color(0xFF00B4D8); // cyan vif
  static const cyanLight    = Color(0xFFE0F7FA); // cyan pastel

  // Accent
  static const amber        = Color(0xFFFFC107); // jaune/amber
  static const amberLight   = Color(0xFFFFF8E1); // amber pastel
  static const green        = Color(0xFF00C853); // vert succès
  static const greenLight   = Color(0xFFE8F5E9); // vert pastel
  static const red          = Color(0xFFE53935); // rouge erreur

  // Textes
  static const textPrimary  = Color(0xFF1A1A2E); // quasi-noir
  static const textSecond   = Color(0xFF6B7280); // gris moyen
  static const textLight    = Color(0xFFB0BEC5); // gris clair

  // Utilitaires
  static const divider      = Color(0xFFE8ECF2);
  static const shadow       = Color(0x14000000);
  static const shadowMedium = Color(0x22000000);
}

// ─────────────────────────────────────────────────────────────────────────────
//  TYPOGRAPHIE — Poppins (style fitness)
// ─────────────────────────────────────────────────────────────────────────────
class AppText {
  AppText._();

  static TextStyle get display => GoogleFonts.poppins(
        fontSize: 36,
        fontWeight: FontWeight.w800,
        color: AppColors.textPrimary,
        height: 1.1,
      );

  static TextStyle get heading => GoogleFonts.poppins(
        fontSize: 26,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
        height: 1.2,
      );

  static TextStyle get subheading => GoogleFonts.poppins(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      );

  static TextStyle get body => GoogleFonts.poppins(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: AppColors.textSecond,
        height: 1.5,
      );

  static TextStyle get label => GoogleFonts.poppins(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: AppColors.textLight,
        letterSpacing: 1.5,
      );

  static TextStyle get caption => GoogleFonts.poppins(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: AppColors.textSecond,
      );

  static TextStyle get button => GoogleFonts.poppins(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.5,
      );

  static TextStyle get stat => GoogleFonts.poppins(
        fontSize: 42,
        fontWeight: FontWeight.w800,
        color: AppColors.textPrimary,
        height: 1.0,
      );
}

// ─────────────────────────────────────────────────────────────────────────────
//  DÉCORATIONS COMMUNES
// ─────────────────────────────────────────────────────────────────────────────
class AppDecorations {
  AppDecorations._();

  /// Carte standard blanche avec ombre douce
  static BoxDecoration card({
    double radius = 20,
    Color? border,
  }) =>
      BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(radius),
        border: border != null ? Border.all(color: border, width: 1.5) : null,
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      );

  /// Chip colorée
  static BoxDecoration chip(Color color) => BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(50),
      );

  /// Fond d'icône
  static BoxDecoration iconBg(Color color, {double radius = 14}) =>
      BoxDecoration(
        color: color.withOpacity(0.13),
        borderRadius: BorderRadius.circular(radius),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
//  THEME DATA
// ─────────────────────────────────────────────────────────────────────────────
class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        primary: AppColors.primary,
        secondary: AppColors.cyan,
        surface: AppColors.surface,
        brightness: Brightness.light,
      ),
      textTheme: GoogleFonts.poppinsTextTheme().copyWith(
        headlineLarge: AppText.heading,
        titleLarge: AppText.subheading,
        bodyMedium: AppText.body,
        labelSmall: AppText.label,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.surface,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        titleTextStyle: GoogleFonts.poppins(
          color: AppColors.textPrimary,
          fontSize: 17,
          fontWeight: FontWeight.w700,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        shadowColor: AppColors.shadow,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(50)),
          padding:
              const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          textStyle: AppText.button,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.primary, width: 1.5),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(50)),
          padding:
              const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          textStyle: AppText.button,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceAlt,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        labelStyle: AppText.body,
        hintStyle: AppText.caption.copyWith(color: AppColors.textLight),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.surface,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textLight,
        elevation: 0,
        type: BottomNavigationBarType.fixed,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 4,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.textPrimary,
        contentTextStyle: GoogleFonts.poppins(color: Colors.white),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.divider,
        thickness: 1,
        space: 1,
      ),
    );
  }
}
