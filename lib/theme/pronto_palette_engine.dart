import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:material_color_utilities/material_color_utilities.dart';
import 'pronto_tokens.dart';

/// Complete resolved theme bundle (Material [ColorScheme], [ProntoTokens], and [ThemeData]).
@immutable
class ProntoThemeSpec {
  final Color seedColor;
  final ProntoThemeId themeId;
  final Brightness brightness;
  final ColorScheme colorScheme;
  final ProntoTokens tokens;
  final ThemeData themeData;

  const ProntoThemeSpec({
    required this.seedColor,
    required this.themeId,
    required this.brightness,
    required this.colorScheme,
    required this.tokens,
    required this.themeData,
  });
}

/// HCT-based 5-harmony palette and [ThemeData] engine for ProntoChat Admin Web.
///
/// Rules:
/// - Built directly from [Hct] and [TonalPalette] (never `ColorScheme.fromSeed`).
/// - Neutrals (`surface`, `pageBg`, `cardBg`, `outline`) use the accent's HCT hue
///   at low chroma (6 for neutral, 12 for neutral-variant) so zero default Material
///   purple/pink tint remains.
/// - Secondary & tertiary palettes stay at moderate chroma (12–28) so they never
///   impersonate semantic status colors (`success`, `warning`, `danger`).
/// - Status colors remain fixed and semantic across all themes.
/// - WCAG AA (>= 4.5:1) is enforced across body/label/action pairs by adjusting
///   **tone only** on the target [TonalPalette], never shifting hue.
class ProntoPaletteEngine {
  const ProntoPaletteEngine._();

  static const String defaultAccentHex = '#295CB4';
  static const ProntoThemeId defaultThemeId = ProntoThemeId.calm;

  /// Curated accent swatches offered in the Admin Customization picker.
  static const List<Color> presetAccents = [
    Color(0xFF00C853), // Vibrant Green
    Color(0xFF059669), // Deep Emerald
    Color(0xFF295CB4), // Classic Pronto Blue
    Color(0xFF2563EB), // Royal Blue
    Color(0xFF7C3AED), // Violet
    Color(0xFF0D9488), // Teal
    Color(0xFFD97706), // Warm Amber
    Color(0xFFE11D48), // Rose
  ];

  static const Color transparent = Colors.transparent;
  static const Color qrQuietZoneBg = Colors.white;

  // Fixed semantic status hues in HCT (never derived from seed accent).
  static const double _successHue = 152.0;
  static const double _warningHue = 70.0;
  static const double _dangerHue = 25.0;

  /// Parses `#RRGGBB` or `RRGGBB` safely.
  static Color parseHex(String? hex, {Color fallback = const Color(0xFF295CB4)}) {
    if (hex == null || hex.trim().isEmpty) return fallback;
    final clean = hex.trim().toUpperCase().replaceAll('#', '');
    if (clean.length == 6) {
      final val = int.tryParse('FF$clean', radix: 16);
      if (val != null) return Color(val);
    } else if (clean.length == 8) {
      final val = int.tryParse(clean, radix: 16);
      if (val != null) return Color(val);
    }
    return fallback;
  }

  /// Formats a [Color] as `#RRGGBB`.
  static String toHex(Color color) {
    return '#${color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';
  }

  /// Exact WCAG 2.1 contrast ratio in `[1.0, 21.0]`.
  static double contrastRatio(Color a, Color b) {
    final l1 = a.computeLuminance();
    final l2 = b.computeLuminance();
    final lighter = math.max(l1, l2);
    final darker = math.min(l1, l2);
    return (lighter + 0.05) / (darker + 0.05);
  }

  static double _wrapHue(double degrees) {
    final mod = degrees % 360.0;
    return mod < 0 ? mod + 360.0 : mod;
  }

  static Color _fromTone(TonalPalette palette, int tone) {
    return Color(palette.get(tone.clamp(0, 100)));
  }

  /// Adjusts **tone only** on [palette] starting from [preferredTone] until
  /// `contrastRatio(fg, bg) >= minRatio` (default 4.55 for safety margin over 4.5).
  /// Because `max(contrast(black, bg), contrast(white, bg)) >= sqrt(21) ≈ 4.583`,
  /// a tone in `[0, 100]` on [palette] is guaranteed to satisfy >= 4.5:1.
  static Color _resolveContrastColor(
    TonalPalette palette, {
    required int preferredTone,
    required Color against,
    double minRatio = 4.55,
    bool? preferDarker,
  }) {
    final initial = _fromTone(palette, preferredTone);
    if (contrastRatio(initial, against) >= minRatio) {
      return initial;
    }

    final bgLum = against.computeLuminance();
    final goDarkerFirst = preferDarker ?? (bgLum > 0.179);

    Color? searchDirection(bool darker) {
      if (darker) {
        for (int t = preferredTone - 1; t >= 0; t--) {
          final candidate = _fromTone(palette, t);
          if (contrastRatio(candidate, against) >= minRatio) return candidate;
        }
      } else {
        for (int t = preferredTone + 1; t <= 100; t++) {
          final candidate = _fromTone(palette, t);
          if (contrastRatio(candidate, against) >= minRatio) return candidate;
        }
      }
      return null;
    }

    final primaryHit = searchDirection(goDarkerFirst);
    if (primaryHit != null) return primaryHit;

    final fallbackHit = searchDirection(!goDarkerFirst);
    if (fallbackHit != null) return fallbackHit;

    // Extreme fallback: pick whichever endpoint (tone 0 or tone 100) has higher contrast.
    final t0 = _fromTone(palette, 0);
    final t100 = _fromTone(palette, 100);
    return contrastRatio(t0, against) >= contrastRatio(t100, against) ? t0 : t100;
  }

  /// Ensures a color meets [minRatio] against ALL provided [backgrounds] by adjusting tone only.
  static Color _resolveContrastAgainstAll(
    TonalPalette palette, {
    required int preferredTone,
    required List<Color> backgrounds,
    double minRatio = 4.55,
    required bool darker,
  }) {
    int start = preferredTone.clamp(0, 100);
    bool passesAll(Color c) =>
        backgrounds.every((bg) => contrastRatio(c, bg) >= minRatio);

    final initial = _fromTone(palette, start);
    if (passesAll(initial)) return initial;

    if (darker) {
      for (int t = start - 1; t >= 0; t--) {
        final c = _fromTone(palette, t);
        if (passesAll(c)) return c;
      }
    } else {
      for (int t = start + 1; t <= 100; t++) {
        final c = _fromTone(palette, t);
        if (passesAll(c)) return c;
      }
    }
    return _fromTone(palette, darker ? 0 : 100);
  }

  /// Builds the three harmonious accent palettes `(primary, secondary, tertiary)`
  /// plus accent-tinted `(neutral, neutralVariant)` palettes for [themeId].
  static ({
    TonalPalette primary,
    TonalPalette secondary,
    TonalPalette tertiary,
    TonalPalette neutral,
    TonalPalette neutralVariant,
  }) buildPalettes({
    required Color seedColor,
    required ProntoThemeId themeId,
  }) {
    final seedHct = Hct.fromInt(seedColor.toARGB32());
    final double h = seedHct.hue;
    final double rawChroma = seedHct.chroma;

    // Preserve achromatic restraint if seed is near-grey/white/black, otherwise vivid primary.
    final double primaryChroma =
        rawChroma < 8.0 ? 22.0 : rawChroma.clamp(36.0, 78.0);

    final primary = TonalPalette.of(h, primaryChroma);

    late final TonalPalette secondary;
    late final TonalPalette tertiary;

    switch (themeId) {
      case ProntoThemeId.calm:
        // Monochromatic: same hue, distinct moderate/low chromas.
        final secChroma = rawChroma < 8.0 ? 10.0 : 16.0;
        final terChroma = rawChroma < 8.0 ? 16.0 : 28.0;
        secondary = TonalPalette.of(h, secChroma);
        tertiary = TonalPalette.of(h, terChroma);
        break;
      case ProntoThemeId.harmony:
        // Analogous: -30 deg and +30 deg at moderate chroma.
        secondary = TonalPalette.of(_wrapHue(h - 30.0), 24.0);
        tertiary = TonalPalette.of(_wrapHue(h + 30.0), 26.0);
        break;
      case ProntoThemeId.contrast:
        // Complementary: +180 deg secondary, low-chroma primary hue tertiary.
        secondary = TonalPalette.of(_wrapHue(h + 180.0), 26.0);
        tertiary = TonalPalette.of(h, 12.0);
        break;
      case ProntoThemeId.balanced:
        // Split-complementary: +150 deg and +210 deg at moderate chroma.
        secondary = TonalPalette.of(_wrapHue(h + 150.0), 24.0);
        tertiary = TonalPalette.of(_wrapHue(h + 210.0), 24.0);
        break;
      case ProntoThemeId.playful:
        // Triadic: +120 deg and +240 deg at moderate chroma.
        secondary = TonalPalette.of(_wrapHue(h + 120.0), 26.0);
        tertiary = TonalPalette.of(_wrapHue(h + 240.0), 26.0);
        break;
    }

    // Accent-tinted neutrals: 6 chroma for neutral (in 4–8), 12 for neutralVariant (in 8–16).
    final neutral = TonalPalette.of(h, 6.0);
    final neutralVariant = TonalPalette.of(h, 12.0);

    return (
      primary: primary,
      secondary: secondary,
      tertiary: tertiary,
      neutral: neutral,
      neutralVariant: neutralVariant,
    );
  }

  /// Builds the full [ProntoThemeSpec] (`ColorScheme` + `ProntoTokens` + `ThemeData`)
  /// for [seedColor], [themeId], and [brightness].
  static ProntoThemeSpec build({
    required Color seedColor,
    required ProntoThemeId themeId,
    required Brightness brightness,
  }) {
    final isDark = brightness == Brightness.dark;
    final p = buildPalettes(seedColor: seedColor, themeId: themeId);
    final seedHct = Hct.fromInt(seedColor.toARGB32());

    // ── 1. Neutral Surfaces (Accent-Tinted, Zero Material Pink) ─────────────
    final Color pageBg = _fromTone(p.neutral, isDark ? 8 : 96);
    final Color sidebarBg = _fromTone(p.neutral, isDark ? 10 : 94);
    final Color cardBg = _fromTone(p.neutral, isDark ? 13 : 100);
    final Color cardSubtleBg = _fromTone(p.neutral, isDark ? 18 : 95);
    final Color surfaceDim = _fromTone(p.neutral, isDark ? 6 : 90);
    final Color surfaceBright = _fromTone(p.neutral, isDark ? 24 : 100);
    final Color surfaceContainerLowest = _fromTone(p.neutral, isDark ? 5 : 100);
    final Color surfaceContainerLow = _fromTone(p.neutral, isDark ? 11 : 97);
    final Color surfaceContainer = _fromTone(p.neutral, isDark ? 14 : 95);
    final Color surfaceContainerHigh = _fromTone(p.neutral, isDark ? 18 : 92);
    final Color surfaceContainerHighest = _fromTone(p.neutral, isDark ? 22 : 89);

    final allSurfaces = <Color>[
      pageBg,
      sidebarBg,
      cardBg,
      cardSubtleBg,
      surfaceContainerLow,
      surfaceContainer,
      surfaceContainerHigh,
    ];

    final Color textPrimary = _resolveContrastAgainstAll(
      p.neutral,
      preferredTone: isDark ? 94 : 10,
      backgrounds: allSurfaces,
      minRatio: 9.0,
      darker: !isDark,
    );

    final Color textSecondary = _resolveContrastAgainstAll(
      p.neutralVariant,
      preferredTone: isDark ? 80 : 30,
      backgrounds: allSurfaces,
      minRatio: 5.5,
      darker: !isDark,
    );

    // Even muted / label text meets WCAG AA >= 4.5:1 against all container surfaces!
    final Color textMuted = _resolveContrastAgainstAll(
      p.neutralVariant,
      preferredTone: isDark ? 72 : 38,
      backgrounds: allSurfaces,
      minRatio: 4.6,
      darker: !isDark,
    );

    final Color cardBorder = _fromTone(p.neutralVariant, isDark ? 26 : 84);
    final Color outline = _resolveContrastAgainstAll(
      p.neutralVariant,
      preferredTone: isDark ? 60 : 46,
      backgrounds: [cardBg, pageBg],
      minRatio: 3.1,
      darker: !isDark,
    );

    // ── 2. Primary, Secondary & Tertiary Roles ──────────────────────────────
    // Keep seed's tone feeling in light mode when already within readable [28..39] range.
    final int lightPrimaryTone = seedHct.chroma >= 12.0
        ? seedHct.tone.round().clamp(28, 39)
        : 36;

    final Color primary = isDark
        ? _resolveContrastAgainstAll(
            p.primary,
            preferredTone: 78,
            backgrounds: [pageBg, cardBg, sidebarBg, cardSubtleBg],
            minRatio: 4.6,
            darker: false,
          )
        : _resolveContrastAgainstAll(
            p.primary,
            preferredTone: lightPrimaryTone,
            backgrounds: [pageBg, cardBg, sidebarBg, cardSubtleBg],
            minRatio: 4.6,
            darker: true,
          );
    final Color onPrimary = _resolveContrastColor(
      p.primary,
      preferredTone: isDark ? 14 : 100,
      against: primary,
      minRatio: 4.6,
      preferDarker: isDark,
    );
    final primaryContainerPalette = TonalPalette.of(
      seedHct.hue,
      seedHct.chroma < 8.0 ? 14.0 : seedHct.chroma.clamp(24.0, 32.0),
    );
    final Color primaryContainer =
        _fromTone(primaryContainerPalette, isDark ? 25 : 91);
    final Color onPrimaryContainer = _resolveContrastColor(
      p.primary,
      preferredTone: isDark ? 92 : 14,
      against: primaryContainer,
      minRatio: 4.6,
      preferDarker: !isDark,
    );

    final Color secondary = isDark
        ? _resolveContrastAgainstAll(
            p.secondary,
            preferredTone: 78,
            backgrounds: [pageBg, cardBg, cardSubtleBg],
            minRatio: 4.6,
            darker: false,
          )
        : _resolveContrastAgainstAll(
            p.secondary,
            preferredTone: 38,
            backgrounds: [pageBg, cardBg, cardSubtleBg],
            minRatio: 4.6,
            darker: true,
          );
    final Color onSecondary = _resolveContrastColor(
      p.secondary,
      preferredTone: isDark ? 15 : 100,
      against: secondary,
      minRatio: 4.6,
      preferDarker: isDark,
    );
    final Color secondaryContainer = _fromTone(p.secondary, isDark ? 26 : 90);
    final Color onSecondaryContainer = _resolveContrastColor(
      p.secondary,
      preferredTone: isDark ? 92 : 15,
      against: secondaryContainer,
      minRatio: 4.6,
      preferDarker: !isDark,
    );

    final Color tertiary = isDark
        ? _resolveContrastAgainstAll(
            p.tertiary,
            preferredTone: 78,
            backgrounds: [pageBg, cardBg, cardSubtleBg],
            minRatio: 4.6,
            darker: false,
          )
        : _resolveContrastAgainstAll(
            p.tertiary,
            preferredTone: 38,
            backgrounds: [pageBg, cardBg, cardSubtleBg],
            minRatio: 4.6,
            darker: true,
          );
    final Color onTertiary = _resolveContrastColor(
      p.tertiary,
      preferredTone: isDark ? 15 : 100,
      against: tertiary,
      minRatio: 4.6,
      preferDarker: isDark,
    );
    final Color tertiaryContainer = _fromTone(p.tertiary, isDark ? 26 : 90);
    final Color onTertiaryContainer = _resolveContrastColor(
      p.tertiary,
      preferredTone: isDark ? 92 : 15,
      against: tertiaryContainer,
      minRatio: 4.6,
      preferDarker: !isDark,
    );

    // ── 3. Fixed Semantic Status Colors (Independent of Accent) ─────────────
    final successPalette = TonalPalette.of(_successHue, 48.0);
    final successSoftPalette = TonalPalette.of(_successHue, 30.0);
    final warningPalette = TonalPalette.of(_warningHue, 56.0);
    final warningSoftPalette = TonalPalette.of(_warningHue, 36.0);
    final dangerPalette = TonalPalette.of(_dangerHue, 68.0);
    final dangerSoftPalette = TonalPalette.of(_dangerHue, 38.0);

    final Color success = _resolveContrastAgainstAll(
      successPalette,
      preferredTone: isDark ? 78 : 34,
      backgrounds: [pageBg, cardBg, cardSubtleBg],
      minRatio: 4.6,
      darker: !isDark,
    );
    final Color onSuccess = _resolveContrastColor(
      successPalette,
      preferredTone: isDark ? 12 : 100,
      against: success,
      minRatio: 4.6,
      preferDarker: isDark,
    );
    final Color successContainer = _fromTone(successSoftPalette, isDark ? 22 : 92);
    final Color onSuccessContainer = _resolveContrastColor(
      successPalette,
      preferredTone: isDark ? 90 : 16,
      against: successContainer,
      minRatio: 4.6,
      preferDarker: !isDark,
    );

    final Color warning = _resolveContrastAgainstAll(
      warningPalette,
      preferredTone: isDark ? 80 : 34,
      backgrounds: [pageBg, cardBg, cardSubtleBg],
      minRatio: 4.6,
      darker: !isDark,
    );
    final Color onWarning = _resolveContrastColor(
      warningPalette,
      preferredTone: isDark ? 12 : 100,
      against: warning,
      minRatio: 4.6,
      preferDarker: isDark,
    );
    final Color warningContainer = _fromTone(warningSoftPalette, isDark ? 22 : 92);
    final Color onWarningContainer = _resolveContrastColor(
      warningPalette,
      preferredTone: isDark ? 90 : 16,
      against: warningContainer,
      minRatio: 4.6,
      preferDarker: !isDark,
    );

    final Color danger = _resolveContrastAgainstAll(
      dangerPalette,
      preferredTone: isDark ? 78 : 36,
      backgrounds: [pageBg, cardBg, cardSubtleBg],
      minRatio: 4.6,
      darker: !isDark,
    );
    final Color onDanger = _resolveContrastColor(
      dangerPalette,
      preferredTone: isDark ? 12 : 100,
      against: danger,
      minRatio: 4.6,
      preferDarker: isDark,
    );
    final Color dangerContainer = _fromTone(dangerSoftPalette, isDark ? 22 : 92);
    final Color onDangerContainer = _resolveContrastColor(
      dangerPalette,
      preferredTone: isDark ? 90 : 16,
      against: dangerContainer,
      minRatio: 4.6,
      preferDarker: !isDark,
    );

    // ── 4. Sidebar & 5-Series Chart Palette ─────────────────────────────────
    final Color sidebarActive = isDark
        ? _fromTone(primaryContainerPalette, 24)
        : _fromTone(primaryContainerPalette, 90);
    final Color sidebarActiveFg = _resolveContrastColor(
      p.primary,
      preferredTone: isDark ? 92 : 15,
      against: sidebarActive,
      minRatio: 4.6,
      preferDarker: !isDark,
    );

    final List<Color> chartPalette = [
      primary,
      secondary,
      tertiary,
      _fromTone(p.primary, isDark ? 60 : 56),
      _fromTone(p.secondary, isDark ? 58 : 58),
    ];

    final Color inverseSurface = _fromTone(p.neutral, isDark ? 92 : 16);
    final Color onInverseSurface = _resolveContrastColor(
      p.neutral,
      preferredTone: isDark ? 14 : 95,
      against: inverseSurface,
      minRatio: 4.6,
      preferDarker: isDark,
    );
    final Color inversePrimary = _fromTone(p.primary, isDark ? 40 : 80);

    final colorScheme = ColorScheme(
      brightness: brightness,
      primary: primary,
      onPrimary: onPrimary,
      primaryContainer: primaryContainer,
      onPrimaryContainer: onPrimaryContainer,
      secondary: secondary,
      onSecondary: onSecondary,
      secondaryContainer: secondaryContainer,
      onSecondaryContainer: onSecondaryContainer,
      tertiary: tertiary,
      onTertiary: onTertiary,
      tertiaryContainer: tertiaryContainer,
      onTertiaryContainer: onTertiaryContainer,
      error: danger,
      onError: onDanger,
      errorContainer: dangerContainer,
      onErrorContainer: onDangerContainer,
      surface: cardBg,
      onSurface: textPrimary,
      onSurfaceVariant: textSecondary,
      surfaceDim: surfaceDim,
      surfaceBright: surfaceBright,
      surfaceContainerLowest: surfaceContainerLowest,
      surfaceContainerLow: surfaceContainerLow,
      surfaceContainer: surfaceContainer,
      surfaceContainerHigh: surfaceContainerHigh,
      surfaceContainerHighest: surfaceContainerHighest,
      outline: outline,
      outlineVariant: cardBorder,
      shadow: _fromTone(p.neutral, 0),
      scrim: _fromTone(p.neutral, 0),
      inverseSurface: inverseSurface,
      onInverseSurface: onInverseSurface,
      inversePrimary: inversePrimary,
      surfaceTint: Colors.transparent,
    );

    final prontoTokens = ProntoTokens(
      sidebarBg: sidebarBg,
      sidebarFg: textPrimary,
      sidebarMuted: textMuted,
      sidebarActive: sidebarActive,
      sidebarActiveFg: sidebarActiveFg,
      sidebarBorder: cardBorder,
      pageBg: pageBg,
      cardBg: cardBg,
      cardSubtleBg: cardSubtleBg,
      cardBorder: cardBorder,
      textPrimary: textPrimary,
      textSecondary: textSecondary,
      textMuted: textMuted,
      success: success,
      onSuccess: onSuccess,
      successContainer: successContainer,
      onSuccessContainer: onSuccessContainer,
      warning: warning,
      onWarning: onWarning,
      warningContainer: warningContainer,
      onWarningContainer: onWarningContainer,
      danger: danger,
      onDanger: onDanger,
      dangerContainer: dangerContainer,
      onDangerContainer: onDangerContainer,
      chartPalette: chartPalette,
    );

    final baseTextTheme = isDark
        ? Typography.material2021().white
        : Typography.material2021().black;
    final textTheme = baseTextTheme.apply(
      bodyColor: textPrimary,
      displayColor: textPrimary,
    );

    final themeData = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      textTheme: textTheme,
      scaffoldBackgroundColor: pageBg,
      canvasColor: cardBg,
      cardColor: cardBg,
      dividerColor: cardBorder,
      extensions: [prontoTokens],
      appBarTheme: AppBarTheme(
        backgroundColor: cardBg,
        foregroundColor: textPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: textSecondary),
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.2,
        ),
      ),
      cardTheme: CardThemeData(
        color: cardBg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: cardBorder),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: cardBg,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: cardBorder),
        ),
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
        contentTextStyle: TextStyle(
          color: textSecondary,
          fontSize: 14,
        ),
      ),
      dividerTheme: DividerThemeData(
        color: cardBorder,
        thickness: 1,
        space: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cardSubtleBg,
        hintStyle: TextStyle(color: textMuted, fontSize: 13.5),
        labelStyle: TextStyle(color: textSecondary, fontSize: 13.5),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: cardBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: cardBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: primary, width: 1.6),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: onPrimary,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textPrimary,
          side: BorderSide(color: outline),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
          textStyle: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: secondaryContainer,
        labelStyle: TextStyle(
          color: onSecondaryContainer,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        side: BorderSide.none,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: cardBg,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: cardBorder),
        ),
        textStyle: TextStyle(color: textPrimary, fontSize: 13.5),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: inverseSurface,
        contentTextStyle: TextStyle(color: onInverseSurface, fontSize: 13.5),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: inverseSurface,
          borderRadius: BorderRadius.circular(8),
        ),
        textStyle: TextStyle(
          color: onInverseSurface,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      ),
      dataTableTheme: DataTableThemeData(
        headingTextStyle: TextStyle(
          color: textSecondary,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
        dataTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 12,
        ),
        dividerThickness: 1,
      ),
    );

    return ProntoThemeSpec(
      seedColor: seedColor,
      themeId: themeId,
      brightness: brightness,
      colorScheme: colorScheme,
      tokens: prontoTokens,
      themeData: themeData,
    );
  }
}
