import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_color_utilities/material_color_utilities.dart';
import 'package:pronto_chat/theme/pronto_palette_engine.dart';
import 'package:pronto_chat/theme/pronto_tokens.dart';

void main() {
  const difficultSeeds = <String, Color>{
    'paleYellow': Color(0xFFFFF9C4),
    'lemonTint': Color(0xFFFFFFE0),
    'pureWhite': Color(0xFFFFFFFF),
    'nearBlack': Color(0xFF080808),
    'neonGreen': Color(0xFF39FF14),
    'currentVibrantGreen': Color(0xFF00C853),
    'currentEmeraldGreen': Color(0xFF059669),
    'prontoBlue': Color(0xFF295CB4),
  };

  double hueDistance(double a, double b) {
    final diff = (a - b).abs() % 360.0;
    return diff > 180.0 ? 360.0 - diff : diff;
  }

  group('ProntoPaletteEngine WCAG AA Contrast Matrix (5 themes x 2 modes x difficult seeds)', () {
    for (final themeId in ProntoThemeId.values) {
      for (final brightness in Brightness.values) {
        for (final entry in difficultSeeds.entries) {
          final seedName = entry.key;
          final seedColor = entry.value;
          final modeLabel = brightness == Brightness.dark ? 'dark' : 'light';

          test('${themeId.id} / $modeLabel / $seedName meets WCAG AA (>= 4.5:1)', () {
            final spec = ProntoPaletteEngine.build(
              seedColor: seedColor,
              themeId: themeId,
              brightness: brightness,
            );
            final cs = spec.colorScheme;
            final t = spec.tokens;

            final surfaces = <String, Color>{
              'pageBg': t.pageBg,
              'cardBg': t.cardBg,
              'cardSubtleBg': t.cardSubtleBg,
              'sidebarBg': t.sidebarBg,
              'surfaceContainerLow': cs.surfaceContainerLow,
              'surfaceContainer': cs.surfaceContainer,
              'surfaceContainerHigh': cs.surfaceContainerHigh,
            };

            // 1. Body, secondary, and muted/label text >= 4.5:1 on every neutral surface
            for (final s in surfaces.entries) {
              expect(
                ProntoPaletteEngine.contrastRatio(t.textPrimary, s.value),
                greaterThanOrEqualTo(4.5),
                reason: 'textPrimary on ${s.key} failed in ${themeId.id}/$modeLabel/$seedName',
              );
              expect(
                ProntoPaletteEngine.contrastRatio(t.textSecondary, s.value),
                greaterThanOrEqualTo(4.5),
                reason: 'textSecondary on ${s.key} failed in ${themeId.id}/$modeLabel/$seedName',
              );
              expect(
                ProntoPaletteEngine.contrastRatio(t.textMuted, s.value),
                greaterThanOrEqualTo(4.5),
                reason: 'textMuted on ${s.key} failed in ${themeId.id}/$modeLabel/$seedName',
              );
            }

            // 2. Sidebar foregrounds & active item contrast
            expect(
              ProntoPaletteEngine.contrastRatio(t.sidebarFg, t.sidebarBg),
              greaterThanOrEqualTo(4.5),
            );
            expect(
              ProntoPaletteEngine.contrastRatio(t.sidebarMuted, t.sidebarBg),
              greaterThanOrEqualTo(4.5),
            );
            expect(
              ProntoPaletteEngine.contrastRatio(t.sidebarActiveFg, t.sidebarActive),
              greaterThanOrEqualTo(4.5),
            );

            // 3. Primary, Secondary, Tertiary role pairs & readability on surfaces
            expect(
              ProntoPaletteEngine.contrastRatio(cs.onPrimary, cs.primary),
              greaterThanOrEqualTo(4.5),
            );
            expect(
              ProntoPaletteEngine.contrastRatio(cs.onPrimaryContainer, cs.primaryContainer),
              greaterThanOrEqualTo(4.5),
            );
            expect(
              ProntoPaletteEngine.contrastRatio(cs.primary, t.cardBg),
              greaterThanOrEqualTo(4.5),
            );
            expect(
              ProntoPaletteEngine.contrastRatio(cs.primary, t.pageBg),
              greaterThanOrEqualTo(4.5),
            );

            expect(
              ProntoPaletteEngine.contrastRatio(cs.onSecondary, cs.secondary),
              greaterThanOrEqualTo(4.5),
            );
            expect(
              ProntoPaletteEngine.contrastRatio(cs.onSecondaryContainer, cs.secondaryContainer),
              greaterThanOrEqualTo(4.5),
            );
            expect(
              ProntoPaletteEngine.contrastRatio(cs.secondary, t.cardBg),
              greaterThanOrEqualTo(4.5),
            );

            expect(
              ProntoPaletteEngine.contrastRatio(cs.onTertiary, cs.tertiary),
              greaterThanOrEqualTo(4.5),
            );
            expect(
              ProntoPaletteEngine.contrastRatio(cs.onTertiaryContainer, cs.tertiaryContainer),
              greaterThanOrEqualTo(4.5),
            );
            expect(
              ProntoPaletteEngine.contrastRatio(cs.tertiary, t.cardBg),
              greaterThanOrEqualTo(4.5),
            );

            // 4. Semantic status pairs (Success, Warning, Danger) & InverseSurface
            expect(
              ProntoPaletteEngine.contrastRatio(t.onSuccess, t.success),
              greaterThanOrEqualTo(4.5),
            );
            expect(
              ProntoPaletteEngine.contrastRatio(t.onSuccessContainer, t.successContainer),
              greaterThanOrEqualTo(4.5),
            );
            expect(
              ProntoPaletteEngine.contrastRatio(t.onWarning, t.warning),
              greaterThanOrEqualTo(4.5),
            );
            expect(
              ProntoPaletteEngine.contrastRatio(t.onWarningContainer, t.warningContainer),
              greaterThanOrEqualTo(4.5),
            );
            expect(
              ProntoPaletteEngine.contrastRatio(t.onDanger, t.danger),
              greaterThanOrEqualTo(4.5),
            );
            expect(
              ProntoPaletteEngine.contrastRatio(t.onDangerContainer, t.dangerContainer),
              greaterThanOrEqualTo(4.5),
            );
            expect(
              ProntoPaletteEngine.contrastRatio(cs.onInverseSurface, cs.inverseSurface),
              greaterThanOrEqualTo(4.5),
            );

            // 5. Accent-tinted low-chroma neutrals (no Material default pink #FEF7FF)
            expect(t.pageBg.toARGB32(), isNot(equals(0xFFFEF7FF)));
            expect(t.pageBg.toARGB32(), isNot(equals(0xFFF7F2FA)));
            final pageHct = Hct.fromInt(t.pageBg.toARGB32());
            expect(pageHct.chroma, lessThanOrEqualTo(16.0));

            // 6. 5-series chart palette populated
            expect(t.chartPalette, hasLength(5));
          });
        }
      }
    }
  });

  group('Harmony Hue Rules & Semantic Status Independence', () {
    test('Harmony tonal palettes follow exact hue angle rules without shifting hue', () {
      const seed = Color(0xFF00C853);
      final seedHue = Hct.fromInt(seed.toARGB32()).hue;

      final calm = ProntoPaletteEngine.buildPalettes(
        seedColor: seed,
        themeId: ProntoThemeId.calm,
      );
      expect(hueDistance(calm.secondary.hue, seedHue), lessThan(1e-3));
      expect(hueDistance(calm.tertiary.hue, seedHue), lessThan(1e-3));

      final harmony = ProntoPaletteEngine.buildPalettes(
        seedColor: seed,
        themeId: ProntoThemeId.harmony,
      );
      expect(hueDistance(harmony.secondary.hue, (seedHue - 30) % 360), lessThan(1e-3));
      expect(hueDistance(harmony.tertiary.hue, (seedHue + 30) % 360), lessThan(1e-3));

      final contrast = ProntoPaletteEngine.buildPalettes(
        seedColor: seed,
        themeId: ProntoThemeId.contrast,
      );
      expect(hueDistance(contrast.secondary.hue, (seedHue + 180) % 360), lessThan(1e-3));
      expect(hueDistance(contrast.tertiary.hue, seedHue), lessThan(1e-3));

      final balanced = ProntoPaletteEngine.buildPalettes(
        seedColor: seed,
        themeId: ProntoThemeId.balanced,
      );
      expect(hueDistance(balanced.secondary.hue, (seedHue + 150) % 360), lessThan(1e-3));
      expect(hueDistance(balanced.tertiary.hue, (seedHue + 210) % 360), lessThan(1e-3));

      final playful = ProntoPaletteEngine.buildPalettes(
        seedColor: seed,
        themeId: ProntoThemeId.playful,
      );
      expect(hueDistance(playful.secondary.hue, (seedHue + 120) % 360), lessThan(1e-3));
      expect(hueDistance(playful.tertiary.hue, (seedHue + 240) % 360), lessThan(1e-3));
    });

    test('Status colors remain fixed semantic hues across radically different seed accents', () {
      final blueSpec = ProntoPaletteEngine.build(
        seedColor: const Color(0xFF2563EB),
        themeId: ProntoThemeId.calm,
        brightness: Brightness.light,
      );
      final roseSpec = ProntoPaletteEngine.build(
        seedColor: const Color(0xFFE11D48),
        themeId: ProntoThemeId.playful,
        brightness: Brightness.light,
      );

      expect(blueSpec.tokens.success, equals(roseSpec.tokens.success));
      expect(blueSpec.tokens.warning, equals(roseSpec.tokens.warning));
      expect(blueSpec.tokens.danger, equals(roseSpec.tokens.danger));
    });
  });
}
