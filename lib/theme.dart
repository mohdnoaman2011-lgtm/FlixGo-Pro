import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// ألوان التطبيق. القيم تتبع الوضع الحالي (داكن/فاتح) عبر [C.dark].
class C {
  C._();

  /// يُضبط من [AppSettings] قبل كل بناء للواجهة.
  static bool dark = true;

  static Color _p(Color d, Color l) => dark ? d : l;

  static Color get bg => _p(const Color(0xFF0B0B0E), const Color(0xFFF5F5F8));
  static Color get nav => _p(const Color(0xFF101014), const Color(0xFFFFFFFF));
  static Color get surface => _p(const Color(0xFF16161B), const Color(0xFFFFFFFF));
  static Color get surface2 => _p(const Color(0xFF1F1F26), const Color(0xFFEDEDF2));
  static Color get border => _p(const Color(0xFF2A2A33), const Color(0xFFE1E1E8));
  static Color get border2 => _p(const Color(0xFF3A3A45), const Color(0xFFCBCBD6));
  static Color get accent => _p(const Color(0xFFFF8A1F), const Color(0xFFE67300));
  static Color get onAccent => const Color(0xFF1A0A00);
  static Color get accentTint => _p(const Color(0xFF3A1E0C), const Color(0xFFFFE8D1));
  static Color get text => _p(const Color(0xFFE8EDF2), const Color(0xFF16161B));
  static Color get text2 => _p(const Color(0xFFC8D1DA), const Color(0xFF3A3A46));
  static Color get muted => _p(const Color(0xFF9AA7B4), const Color(0xFF6A7280));
  static Color get orange => _p(const Color(0xFFF5C84C), const Color(0xFFB7791F));
  static Color get danger => _p(const Color(0xFFFF7A7A), const Color(0xFFD63A3A));

  // شاشة البداية داكنة دائماً (الشعار مصمَّم لخلفية داكنة)
  static const splashBg = Color(0xFF0B0B0E);
  static const splashMuted = Color(0xFF9AA7B4);
  static const splashTrack = Color(0xFF2A2A33);
  static const splashAccent = Color(0xFFFF8A1F);
}

ThemeData buildTheme() {
  final dark = C.dark;
  final base = dark ? ThemeData.dark(useMaterial3: true) : ThemeData.light(useMaterial3: true);
  final scheme = dark
      ? ColorScheme.dark(primary: C.accent, onPrimary: C.onAccent, surface: C.surface)
      : ColorScheme.light(primary: C.accent, onPrimary: C.onAccent, surface: C.surface);
  return base.copyWith(
    scaffoldBackgroundColor: C.bg,
    colorScheme: scheme,
    textTheme: GoogleFonts.cairoTextTheme(base.textTheme)
        .apply(bodyColor: C.text, displayColor: C.text),
    dialogTheme: DialogThemeData(backgroundColor: C.surface),
    bottomSheetTheme: BottomSheetThemeData(backgroundColor: C.surface),
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
