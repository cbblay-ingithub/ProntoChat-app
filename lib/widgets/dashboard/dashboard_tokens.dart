import 'package:flutter/material.dart';

/// Design tokens for the Admin Dashboard visual refresh.
/// Adheres to an 8pt spatial grid, minimum 12px font sizes, WCAG AA 4.5:1 contrast,
/// and an evolutionary dark theme with vibrant green accents.
class DashboardTokens {
  DashboardTokens._();

  // Surface Colors
  static const Color surfaceDark = Color(0xFF1E1D1D);
  static const Color surfaceCard = Color(0xFF232222);
  static const Color surfaceHover = Color(0xFF2A2929);
  static const Color surfaceBorder = Color(0x14FFFFFF); // ~8% white
  static const Color surfaceDivider = Color(0x1AFFFFFF); // ~10% white

  // Accent Colors
  static const Color accentGreen = Color(0xFF34D399); // Emerald-400 (high contrast on dark)
  static const Color accentGreenLight = Color(0xFF6EE7B7);
  static const Color accentGreenMuted = Color(0x1F34D399);

  static const Color accentOrange = Color(0xFFFBBF24); // Amber-400
  static const Color accentOrangeMuted = Color(0x1FFBBF24);

  static const Color accentRed = Color(0xFFF87171); // Red-400
  static const Color accentRedMuted = Color(0x1FF87171);

  static const Color accentBlue = Color(0xFF60A5FA); // Blue-400
  static const Color accentBlueMuted = Color(0x1F60A5FA);

  static const Color accentPurple = Color(0xFFA78BFA); // Purple-400
  static const Color accentPurpleMuted = Color(0x1FA78BFA);

  static const Color accentTeal = Color(0xFF2DD4BF); // Teal-400
  static const Color accentTealMuted = Color(0x1F2DD4BF);

  // Text Colors (High Contrast on 0xFF1E1D1D)
  static const Color textPrimary = Color(0xFFF3F4F6); // Grey-100 (Contrast ratio > 12:1)
  static const Color textSecondary = Color(0xFF9CA3AF); // Grey-400 (Contrast ratio > 4.8:1)
  static const Color textMuted = Color(0xFF6B7280); // Grey-500
  static const Color textDisabled = Color(0xFF4B5563); // Grey-600

  // Spacing (8pt Grid)
  static const double space4 = 4.0;
  static const double space8 = 8.0;
  static const double space12 = 12.0;
  static const double space16 = 16.0;
  static const double space20 = 20.0;
  static const double space24 = 24.0;
  static const double space32 = 32.0;

  // Border Radii
  static const double radiusSm = 6.0;
  static const double radiusMd = 10.0;
  static const double radiusLg = 14.0;
  static const double radiusXl = 18.0;

  // Maximum Dashboard Width
  static const double maxContentWidth = 1440.0;

  /// Parse hex color string safely with fallback
  static Color hexToColor(String? hexString, [Color fallback = const Color(0xFF295CB4)]) {
    if (hexString == null || hexString.isEmpty) return fallback;
    try {
      String clean = hexString.toUpperCase().replaceAll('#', '');
      if (clean.length == 6) clean = 'FF$clean';
      if (clean.length == 8) {
        final val = int.tryParse(clean, radix: 16);
        if (val != null) return Color(val);
      }
    } catch (_) {}
    return fallback;
  }
}
