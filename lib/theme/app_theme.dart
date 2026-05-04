// lib/theme/app_theme.dart
// PREMIUM v11: Glassmorphism, gradient utilities, glow shadows, ambient depth

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  AppTheme._();

  // ── Brand Colors ──────────────────────────────────────────
  static const Color primaryBlue  = Color(0xFF1E40AF);
  static const Color primaryLight = Color(0xFF3B82F6);
  static const Color accent       = Color(0xFF0EA5E9);
  static const Color accentCyan   = Color(0xFF06B6D4);
  static const Color success      = Color(0xFF22C55E);
  static const Color warning      = Color(0xFFF59E0B);
  static const Color danger       = Color(0xFFEF4444);

  // ── Dark Palette ──────────────────────────────────────────
  static const Color darkBg      = Color(0xFF060D1A);
  static const Color darkCard    = Color(0xFF0D1526);
  static const Color darkSurface = Color(0xFF152035);
  static const Color darkBorder  = Color(0xFF1E3A5F);
  static const Color darkGlass   = Color(0x1A3B82F6);

  // ── Light Palette ─────────────────────────────────────────
  static const Color lightBg     = Color(0xFFEEF2FF);
  static const Color lightCard   = Color(0xFFFFFFFF);
  static const Color lightBorder = Color(0xFFCBD5E1);

  // ── Premium Gradients ─────────────────────────────────────
  static const Gradient heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF0D1526), Color(0xFF0A1628), Color(0xFF060D1A)],
    stops: [0.0, 0.5, 1.0],
  );

  static const Gradient accentGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [Color(0xFF1E40AF), Color(0xFF0EA5E9)],
  );

  static const Gradient accentGradientV = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF1E40AF), Color(0xFF0EA5E9)],
  );

  static const Gradient successGradient = LinearGradient(
    colors: [Color(0xFF16A34A), Color(0xFF22C55E)],
  );

  static const Gradient dangerGradient = LinearGradient(
    colors: [Color(0xFFDC2626), Color(0xFFEF4444)],
  );

  static const Gradient warmGradient = LinearGradient(
    colors: [Color(0xFFF59E0B), Color(0xFFEF4444)],
  );

  // ── Glow Shadows ──────────────────────────────────────────
  static List<BoxShadow> glowBlue({double intensity = 0.5}) => [
    BoxShadow(
      color: accent.withValues(alpha: intensity * 0.6),
      blurRadius: 24,
      spreadRadius: -4,
    ),
    BoxShadow(
      color: primaryLight.withValues(alpha: intensity * 0.3),
      blurRadius: 48,
      spreadRadius: -8,
    ),
  ];

  static List<BoxShadow> glowSuccess({double intensity = 0.5}) => [
    BoxShadow(
      color: success.withValues(alpha: intensity * 0.6),
      blurRadius: 20,
      spreadRadius: -4,
    ),
  ];

  static List<BoxShadow> glowDanger({double intensity = 0.5}) => [
    BoxShadow(
      color: danger.withValues(alpha: intensity * 0.6),
      blurRadius: 20,
      spreadRadius: -4,
    ),
  ];

  static const List<BoxShadow> cardShadow = [
    BoxShadow(
      color: Color(0x50000000),
      blurRadius: 24,
      offset: Offset(0, 8),
    ),
    BoxShadow(
      color: Color(0x0D3B82F6),
      blurRadius: 1,
      spreadRadius: 1,
    ),
  ];

  // ── Glassmorphism Decoration ──────────────────────────────
  static BoxDecoration glassDecoration({
    double borderRadius = 20,
    Color? borderColor,
    Color? bgColor,
  }) => BoxDecoration(
    color: bgColor ?? const Color(0x1A3B82F6),
    borderRadius: BorderRadius.circular(borderRadius),
    border: Border.all(
      color: borderColor ?? const Color(0x333B82F6),
      width: 1.0,
    ),
  );

  static BoxDecoration cardDecoration({
    double borderRadius = 16,
    bool isDark = true,
    List<BoxShadow>? shadows,
  }) => BoxDecoration(
    color: isDark ? darkCard : lightCard,
    borderRadius: BorderRadius.circular(borderRadius),
    border: Border.all(
      color: isDark ? const Color(0xFF1E3A5F) : lightBorder,
      width: 1.0,
    ),
    boxShadow: shadows ?? (isDark ? cardShadow : []),
  );

  // ── Dark Theme ────────────────────────────────────────────
  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: darkBg,
        colorSchemeSeed: accent,
        textTheme: GoogleFonts.spaceGroteskTextTheme(
          ThemeData.dark().textTheme,
        ),
        cardTheme: CardThemeData(
          color: darkCard,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFF1E3A5F)),
          ),
          shadowColor: Colors.black54,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryLight,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 28),
            elevation: 0,
            textStyle: GoogleFonts.spaceGrotesk(
              fontWeight: FontWeight.w700,
              fontSize: 15,
              letterSpacing: 0.5,
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.white70,
            side: const BorderSide(color: Color(0xFF1E3A5F)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 28),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: darkCard,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFF1E3A5F)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFF1E3A5F)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: accent, width: 1.5),
          ),
          labelStyle: const TextStyle(color: Colors.white54),
          hintStyle: const TextStyle(color: Colors.white24),
          prefixIconColor: Colors.white38,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          titleTextStyle: GoogleFonts.spaceGrotesk(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        dividerTheme: const DividerThemeData(
          color: Color(0xFF1E3A5F),
          thickness: 1,
        ),
        snackBarTheme: SnackBarThemeData(
          backgroundColor: darkSurface,
          contentTextStyle: GoogleFonts.spaceGrotesk(color: Colors.white),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 8,
        ),
        switchTheme: SwitchThemeData(
          thumbColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) return Colors.white;
            return Colors.white38;
          }),
          trackColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) return accent;
            return Colors.white12;
          }),
        ),
        checkboxTheme: CheckboxThemeData(
          fillColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) return accent;
            return Colors.transparent;
          }),
          checkColor: WidgetStateProperty.all(Colors.white),
          side: const BorderSide(color: Colors.white38),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        ),
        listTileTheme: const ListTileThemeData(
          iconColor: Colors.white54,
          textColor: Colors.white,
        ),
      );

  // ── Light Theme ───────────────────────────────────────────
  static ThemeData get light => ThemeData(
        useMaterial3: true,
        colorSchemeSeed: primaryBlue,
        brightness: Brightness.light,
        scaffoldBackgroundColor: lightBg,
        textTheme: GoogleFonts.spaceGroteskTextTheme(),
        cardTheme: CardThemeData(
          color: lightCard,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: lightBorder),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryBlue,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 28),
            elevation: 0,
            textStyle: GoogleFonts.spaceGrotesk(
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: lightBorder),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: lightBorder),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: primaryBlue, width: 1.5),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: primaryBlue,
          foregroundColor: Colors.white,
          elevation: 0,
          titleTextStyle: GoogleFonts.spaceGrotesk(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      );
}
