import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Every color in the app, in one place.
abstract final class AppColors {
  // The clock face.
  static const Color background = Color(0xFF05070D);
  static const Color panel = Color(0xFF0A1020);
  static const Color panelBorder = Color(0xFF1B2A48);

  /// The azure blue of lit digits.
  static const Color digitLit = Color(0xFF3FA9FF);

  /// How strong unlit segments look next to lit ones, like a real LED clock.
  static const double digitUnlitOpacity = 0.12;

  // Text on the clock face.
  static const Color labelText = Color(0xFF8FA6C8);
  static const Color valueText = Color(0xFFE8F0FF);

  // The cat.
  static const Color fur = Color(0xFFC98A4B);
  static const Color furDark = Color(0xFF8F5A2A);
  static const Color furLight = Color(0xFFF0D2A5);
  static const Color earInner = Color(0xFFE7A2A0);
  static const Color nose = Color(0xFFD9707F);
  static const Color outline = Color(0xFF2A1A12);
  static const Color eye = Color(0xFF14110F);
  static const Color whisker = Color(0xFFF4EBDD);

  // Weather pictures. Muted, so the blue digits stay the focus.
  static const Color sun = Color(0xFFFFC247);
  static const Color moon = Color(0xFFE4E9F3);
  static const Color cloudLight = Color(0xFFC5D0E0);
  static const Color cloudDark = Color(0xFF8E9BB2);
  static const Color rain = Color(0xFF5AA9FF);
  static const Color snow = Color(0xFFFFFFFF);
  static const Color bolt = Color(0xFFFFD84A);
  static const Color fog = Color(0xFF9FB0C8);
  static const Color unavailable = Color(0xFF6B7A94);

  // The alarm bar and footer.
  static const Color barBackground = Color(0xFF0D1424);
  static const Color switchOn = Color(0xFF3FA9FF);
  static const Color switchOff = Color(0xFF3A4660);
}

/// How bright a color is to the eye, from 0 (black) to 1 (white). WCAG's definition.
double relativeLuminance(Color color) {
  double channel(double value) {
    return value <= 0.03928 ? value / 12.92 : math.pow((value + 0.055) / 1.055, 2.4).toDouble();
  }

  return 0.2126 * channel(color.r) + 0.7152 * channel(color.g) + 0.0722 * channel(color.b);
}

/// How well two colors stand apart, from 1 (identical) to 21 (black on white).
/// 4.5 is the usual minimum for easy reading.
double contrastRatio(Color a, Color b) {
  final first = relativeLuminance(a);
  final second = relativeLuminance(b);
  final lighter = math.max(first, second);
  final darker = math.min(first, second);
  return (lighter + 0.05) / (darker + 0.05);
}

ThemeData buildAppTheme() {
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.background,
    colorScheme: ColorScheme.dark(
      primary: AppColors.digitLit,
      surface: AppColors.background,
    ),
  );
}
