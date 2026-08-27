import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_skin.dart';

/// Palette mirrors the original web artifact: warm paper in light mode,
/// deep-night indigo in dark mode, amber for the nap timer, coral for alarms.
class AppColors extends ThemeExtension<AppColors> {
  final Color bg;
  final Color surface;
  final Color surface2;
  final Color border;
  final Color text;
  final Color textDim;
  final Color accentAlert;
  final Color accentAlertInk;
  final Color accentNap;
  final Color accentNapInk;
  final Color accentGood;

  const AppColors({
    required this.bg,
    required this.surface,
    required this.surface2,
    required this.border,
    required this.text,
    required this.textDim,
    required this.accentAlert,
    required this.accentAlertInk,
    required this.accentNap,
    required this.accentNapInk,
    required this.accentGood,
  });

  static const light = AppColors(
    bg: Color(0xFFF4F2EA),
    surface: Color(0xFFFFFFFF),
    surface2: Color(0xFFECE8DA),
    border: Color(0x1F1E1C14),
    text: Color(0xFF201D16),
    textDim: Color(0xFF6B6656),
    accentAlert: Color(0xFFE24E2E),
    accentAlertInk: Color(0xFFFFFFFF),
    accentNap: Color(0xFFC97F1E),
    accentNapInk: Color(0xFFFFFFFF),
    accentGood: Color(0xFF2E7D5B),
  );

  static const dark = AppColors(
    bg: Color(0xFF10142A),
    surface: Color(0xFF1A2044),
    surface2: Color(0xFF232B58),
    border: Color(0x17FFFFFF),
    text: Color(0xFFECEBF8),
    textDim: Color(0xFF9BA1C9),
    accentAlert: Color(0xFFFF6B4A),
    accentAlertInk: Color(0xFF1A0E08),
    accentNap: Color(0xFFFFC24B),
    accentNapInk: Color(0xFF2A1B00),
    accentGood: Color(0xFF4ADE9C),
  );

  static AppColors of(BuildContext context) =>
      Theme.of(context).extension<AppColors>() ?? light;

  @override
  AppColors copyWith() => this;

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      bg: Color.lerp(bg, other.bg, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surface2: Color.lerp(surface2, other.surface2, t)!,
      border: Color.lerp(border, other.border, t)!,
      text: Color.lerp(text, other.text, t)!,
      textDim: Color.lerp(textDim, other.textDim, t)!,
      accentAlert: Color.lerp(accentAlert, other.accentAlert, t)!,
      accentAlertInk: Color.lerp(accentAlertInk, other.accentAlertInk, t)!,
      accentNap: Color.lerp(accentNap, other.accentNap, t)!,
      accentNapInk: Color.lerp(accentNapInk, other.accentNapInk, t)!,
      accentGood: Color.lerp(accentGood, other.accentGood, t)!,
    );
  }
}

class AppTheme {
  static TextTheme _textTheme(AppColors c) {
    final display = GoogleFonts.zenKakuGothicNew();
    final body = GoogleFonts.notoSansJp();
    return TextTheme(
      headlineMedium: display.copyWith(
        fontWeight: FontWeight.w800,
        color: c.text,
        fontSize: 23,
      ),
      titleLarge: display.copyWith(fontWeight: FontWeight.w700, color: c.text),
      titleMedium: display.copyWith(
        fontWeight: FontWeight.w700,
        color: c.text,
        fontSize: 16,
      ),
      bodyLarge: body.copyWith(color: c.text, fontSize: 15, height: 1.6),
      bodyMedium: body.copyWith(color: c.textDim, fontSize: 13.5, height: 1.6),
      labelLarge: body.copyWith(color: c.text, fontWeight: FontWeight.w700),
    );
  }

  static ThemeData _build(AppColors c, Brightness brightness) {
    return ThemeData(
      brightness: brightness,
      scaffoldBackgroundColor: c.bg,
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: c.accentAlert,
        onPrimary: c.accentAlertInk,
        secondary: c.accentNap,
        onSecondary: c.accentNapInk,
        error: c.accentAlert,
        onError: c.accentAlertInk,
        surface: c.surface,
        onSurface: c.text,
      ),
      textTheme: _textTheme(c),
      cardTheme: CardThemeData(
        color: c.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: c.border),
        ),
      ),
      dividerColor: c.border,
      extensions: [c],
    );
  }

  static ThemeData get lightTheme => _build(AppColors.light, Brightness.light);
  static ThemeData get darkTheme => _build(AppColors.dark, Brightness.dark);

  /// Build a theme for a purchased skin. Every skin ships both brightnesses,
  /// so choosing one never overrides the phone's light/dark preference.
  static ThemeData lightFor(AppSkin skin) =>
      _build(skin.light, Brightness.light);
  static ThemeData darkFor(AppSkin skin) => _build(skin.dark, Brightness.dark);
}
