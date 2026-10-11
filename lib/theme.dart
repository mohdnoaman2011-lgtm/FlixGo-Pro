import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class C {
  static const bg = Color(0xFF0B0B0E);
  static const nav = Color(0xFF101014);
  static const surface = Color(0xFF16161B);
  static const surface2 = Color(0xFF1F1F26);
  static const border = Color(0xFF2A2A33);
  static const border2 = Color(0xFF3A3A45);
  static const accent = Color(0xFFFF8A1F);
  static const onAccent = Color(0xFF1A0A00);
  static const accentTint = Color(0xFF3A1E0C);
  static const text = Color(0xFFE8EDF2);
  static const text2 = Color(0xFFC8D1DA);
  static const muted = Color(0xFF9AA7B4);
  static const orange = Color(0xFFF5C84C);
  static const danger = Color(0xFFFF7A7A);
}

ThemeData buildTheme() {
  final base = ThemeData.dark(useMaterial3: true);
  return base.copyWith(
    scaffoldBackgroundColor: C.bg,
    colorScheme: const ColorScheme.dark(
      primary: C.accent,
      onPrimary: C.onAccent,
      surface: C.surface,
    ),
    textTheme: GoogleFonts.cairoTextTheme(base.textTheme)
        .apply(bodyColor: C.text, displayColor: C.text),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: C.nav,
      indicatorColor: C.accentTint,
      height: 72,
      iconTheme: WidgetStateProperty.resolveWith(
        (s) => IconThemeData(
          color: s.contains(WidgetState.selected) ? C.accent : C.muted,
        ),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (s) => GoogleFonts.cairo(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: s.contains(WidgetState.selected) ? C.accent : C.muted,
        ),
      ),
    ),
  );
}
