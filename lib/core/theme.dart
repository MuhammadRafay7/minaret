import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class MinaretTheme {
  // ── iOS 18 Islamic Palette ───────────────────────────────────────────────────
  static const Color background = Color(0xFFF2EDE3); // warm sandstone
  static const Color surface = Color(0xFFFFFFFF); // glass base (use w/ opacity)
  static const Color emerald = Color(0xFF166A45); // nabawi vivid
  static const Color emeraldLight = Color(0xFF1A7D52); // lighter dome green
  static const Color gold = Color(0xFFC9962A); // aged dome gold
  static const Color goldSoft = Color(0xFFE8C96A); // soft glow gold
  static const Color onyx = Color(0xFF1A1A1A); // near-black
  static const Color slate = Color(0xFF6B6B6B); // muted text
  static const Color dividerColor = Color(0x1A000000); // 10% black

  // ── Dark-mode background colours (use instead of raw hex literals) ───────
  static const Color darkBackground = Color(0xFF0D1117);
  static const Color darkSurface = Color(0xFF151B24);

  // ── Blur / Glass helpers ────────────────────────────────────────────────────
  // Usage: ClipRRect + BackdropFilter(filter: MinaretTheme.blur, child: ...)
  static ImageFilter get blur => ImageFilter.blur(sigmaX: 22, sigmaY: 22);

  static ImageFilter get blurHeavy => ImageFilter.blur(sigmaX: 40, sigmaY: 40);

  // ── Glass surface colors (use these as Container colors over blur) ──────────
  static Color get glassSurface => Colors.white.withOpacity(0.62);
  static Color get glassSurfaceThick => Colors.white.withOpacity(0.82);
  static Color get glassChrome => Colors.white.withOpacity(0.45);

  // ── Spacing ─────────────────────────────────────────────────────────────────
  static const double cardPadding = 20.0;
  static const double cardRadius = 20.0;
  static const double buttonRadius = 14.0;
  static const double letterSpacingLarge = 2.0;
  static const double letterSpacingSmall = 1.2;

  // ── Typography ──────────────────────────────────────────────────────────────
  static TextStyle get heading =>
      GoogleFonts.amiri(fontWeight: FontWeight.w700, letterSpacing: 0.5);

  static TextStyle get arabicDisplay =>
      GoogleFonts.amiri(fontWeight: FontWeight.w700, fontSize: 22);

  static TextStyle get detailHeader => GoogleFonts.cairo(
    fontSize: 10,
    letterSpacing: 1.2,
    fontWeight: FontWeight.w600,
  );

  static TextStyle get label => GoogleFonts.cairo(
    color: gold,
    fontSize: 9,
    letterSpacing: 1.6,
    fontWeight: FontWeight.w700,
  );

  // ── Shadows ──────────────────────────────────────────────────────────────────
  static List<BoxShadow> get cardShadow => [
    BoxShadow(
      color: Colors.black.withOpacity(0.06),
      blurRadius: 24,
      offset: const Offset(0, 2),
    ),
    BoxShadow(
      color: Colors.black.withOpacity(0.04),
      blurRadius: 4,
      offset: const Offset(0, 1),
    ),
  ];

  static List<BoxShadow> get goldShadow => [
    BoxShadow(
      color: gold.withOpacity(0.22),
      blurRadius: 24,
      offset: const Offset(0, 4),
    ),
  ];

  static List<BoxShadow> get heroShadow => [
    BoxShadow(
      color: emerald.withOpacity(0.35),
      blurRadius: 32,
      offset: const Offset(0, 8),
    ),
  ];

  // ── ThemeData ───────────────────────────────────────────────────────────────
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: background,
      colorScheme: const ColorScheme.light(
        primary: emerald,
        secondary: gold,
        surface: Color(0xFFF2EDE3),
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: onyx,
      ),
      textTheme: TextTheme(
        displayLarge: heading,
        bodyMedium: GoogleFonts.notoNaskhArabic(
          color: onyx,
          fontSize: 16,
          height: 2.0,
        ),
        titleMedium: GoogleFonts.cairo(
          color: onyx,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
        bodyLarge: GoogleFonts.cairo(color: onyx, fontSize: 17, height: 1.7),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white.withOpacity(0.45),
        labelStyle: GoogleFonts.cairo(
          fontSize: 10,
          letterSpacing: 1.2,
          color: slate,
          fontWeight: FontWeight.w600,
        ),
        floatingLabelStyle: GoogleFonts.cairo(
          fontSize: 10,
          letterSpacing: 1.2,
          color: gold,
          fontWeight: FontWeight.w700,
        ),
        enabledBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: dividerColor, width: 1.0),
        ),
        focusedBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: gold, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 10),
      ),
      dividerTheme: const DividerThemeData(thickness: 0.5, color: dividerColor),
      cardTheme: CardThemeData(
        elevation: 0,
        color: Colors.white.withOpacity(0.62), // glass base
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(cardRadius),
          side: BorderSide(color: Colors.white.withOpacity(0.5), width: 0.8),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: emerald,
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        contentTextStyle: GoogleFonts.cairo(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
          color: Colors.white,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: emerald, width: 1.5),
          padding: const EdgeInsets.symmetric(vertical: 22),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(buttonRadius),
          ),
          textStyle: GoogleFonts.cairo(
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: emerald,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(54),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(buttonRadius),
          ),
          textStyle: GoogleFonts.cairo(
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      appBarTheme: AppBarTheme(
        // Use with BackdropFilter(filter: MinaretTheme.blur) in your AppBar
        backgroundColor: Colors.white.withOpacity(0.45),
        foregroundColor: onyx,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return emerald;
          return Colors.white;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return emerald.withOpacity(0.35);
          }
          return slate.withOpacity(0.28);
        }),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: Colors.white.withOpacity(0.84),
        showDragHandle: true,
        dragHandleColor: slate.withOpacity(0.45),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: glassSurfaceThick,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: emerald,
        textColor: onyx,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white.withOpacity(0.78),
        indicatorColor: emerald.withOpacity(0.16),
        elevation: 0,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(color: selected ? emerald : slate, size: 22);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return GoogleFonts.cairo(
            fontSize: 11,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
            color: selected ? emerald : slate,
          );
        }),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        // Wrap in BackdropFilter for glass effect
        backgroundColor: Colors.white.withOpacity(0.82),
        selectedItemColor: emerald,
        unselectedItemColor: slate,
        elevation: 0,
        selectedLabelStyle: GoogleFonts.cairo(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
        ),
        unselectedLabelStyle: GoogleFonts.cairo(
          fontSize: 9,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  // ── Dark Theme ───────────────────────────────────────────────────────────────
  static ThemeData get darkTheme {
    const darkBg = Color(0xFF0D1117);
    const darkSurface = Color(0xFF151B24);
    const darkDivider = Color(0x1AFFFFFF); // 10% white

    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: darkBg,
      colorScheme: const ColorScheme.dark(
        primary: gold,
        secondary: emeraldLight,
        surface: darkSurface,
        onPrimary: Colors.black,
        onSecondary: Colors.white,
      ),
      textTheme: TextTheme(
        displayLarge: GoogleFonts.amiri(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
        bodyMedium: GoogleFonts.notoNaskhArabic(
          color: Colors.white.withOpacity(0.92),
          fontSize: 16,
          height: 2.0,
        ),
        titleMedium: GoogleFonts.cairo(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
        bodyLarge: GoogleFonts.cairo(
          color: Colors.white.withOpacity(0.92),
          fontSize: 17,
          height: 1.7,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white.withOpacity(0.06),
        labelStyle: GoogleFonts.cairo(
          fontSize: 10,
          letterSpacing: 1.2,
          color: Colors.white70,
          fontWeight: FontWeight.w600,
        ),
        floatingLabelStyle: GoogleFonts.cairo(
          fontSize: 10,
          letterSpacing: 1.2,
          color: gold,
          fontWeight: FontWeight.w700,
        ),
        enabledBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: darkDivider, width: 1.0),
        ),
        focusedBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: gold, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 10),
      ),
      dividerTheme: const DividerThemeData(thickness: 0.5, color: darkDivider),
      cardTheme: CardThemeData(
        elevation: 0,
        color: Colors.white.withOpacity(0.07),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(cardRadius),
          side: BorderSide(color: Colors.white.withOpacity(0.12), width: 0.8),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: const Color(0xFF1E2A38),
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        contentTextStyle: GoogleFonts.cairo(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: gold, width: 1.3),
          padding: const EdgeInsets.symmetric(vertical: 22),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(buttonRadius),
          ),
          foregroundColor: Colors.white,
          textStyle: GoogleFonts.cairo(
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: emerald,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(54),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(buttonRadius),
          ),
          textStyle: GoogleFonts.cairo(
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.black.withOpacity(0.22),
        foregroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return gold;
          return Colors.white70;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return gold.withOpacity(0.35);
          }
          return Colors.white24;
        }),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: const Color(0xFF0D1117).withOpacity(0.88),
        showDragHandle: true,
        dragHandleColor: Colors.white38,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: const Color(0xFF111826).withOpacity(0.92),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: gold,
        textColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.black.withOpacity(0.62),
        indicatorColor: gold.withOpacity(0.2),
        elevation: 0,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? gold : Colors.white70,
            size: 22,
          );
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return GoogleFonts.cairo(
            fontSize: 11,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
            color: selected ? gold : Colors.white70,
          );
        }),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: Colors.black.withOpacity(0.70),
        selectedItemColor: gold,
        unselectedItemColor: Colors.white38,
        elevation: 0,
        selectedLabelStyle: GoogleFonts.cairo(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
        ),
        unselectedLabelStyle: GoogleFonts.cairo(
          fontSize: 9,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}
