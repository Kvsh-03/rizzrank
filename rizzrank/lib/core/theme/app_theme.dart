import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const Color primary = Color(0xFF895AF6);
  static const Color backgroundDark = Color(0xFF151022);
  static const Color backgroundLight = Color(0xFFF6F5F8);

  static final List<BoxShadow> glowPrimary = [
    BoxShadow(
      color: primary.withOpacity(0.4),
      blurRadius: 20,
      spreadRadius: 0,
    ),
  ];

  static ThemeData get darkTheme {
    return ThemeData.dark().copyWith(
      scaffoldBackgroundColor: backgroundDark,
      colorScheme: const ColorScheme.dark(
        primary: primary,
        surface: backgroundDark,
      ),
      textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
    );
  }
}
