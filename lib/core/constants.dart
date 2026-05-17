import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class MinaretTheme {
  // 1. Core Color Palette
  static const Color background = Color(0xFFFBFBF9); // Off-white luxury
  static const Color gold = Color(0xFFC5A358);       // Signature Gold
  static const Color onyx = Color(0xFF1A1A1A);       // Deep Black
  static const Color slate = Color(0xFF707070);      // Muted Grey

  // 2. Spacing & Layout Constants
  static const double cardPadding = 24.0;
  static const double letterSpacingLarge = 6.0;
  static const double letterSpacingSmall = 2.0;

  // 3. Text Styles (Reusable across the app)
  static TextStyle get heading => GoogleFonts.playfairDisplay(
        color: onyx,
        fontWeight: FontWeight.bold,
        letterSpacing: letterSpacingLarge,
      );

  static TextStyle get detailHeader => GoogleFonts.montserrat(
        fontSize: 10,
        letterSpacing: letterSpacingSmall,
        fontWeight: FontWeight.w600,
        color: slate,
      );

  // 4. Main App Theme
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: background,
      colorScheme: ColorScheme.light(
        primary: onyx,
        secondary: gold,
        surface: Colors.white,
      ),
      // Consistent Typography
      textTheme: TextTheme(
        displayLarge: heading,
        bodyMedium: GoogleFonts.inter(color: onyx, fontSize: 14),
      ),
      // Modern Divider Styling
      dividerTheme: const DividerThemeData(
        thickness: 0.5,
        color: Color(0xFFEEEEEE),
      ),
    );
  }
}