import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';

/// Five color-harmony theme families built from HCT tonal palettes.
enum ProntoThemeId {
  calm(
    id: 'calm',
    label: 'Calm',
    ruleLabel: 'Monochromatic',
    description: 'Single accent hue across stepped chroma levels for focused clarity.',
  ),
  harmony(
    id: 'harmony',
    label: 'Harmony',
    ruleLabel: 'Analogous (±30°)',
    description: 'Neighboring hues (-30° / +30°) for smooth, cohesive warmth.',
  ),
  contrast(
    id: 'contrast',
    label: 'Contrast',
    ruleLabel: 'Complementary (+180°)',
    description: 'Opposite secondary accent paired with low-chroma primary support.',
  ),
  balanced(
    id: 'balanced',
    label: 'Balanced',
    ruleLabel: 'Split-Complementary',
    description: 'Dual +150° / +210° counter-accents without harsh opposition.',
  ),
  playful(
    id: 'playful',
    label: 'Playful',
    ruleLabel: 'Triadic (+120° / +240°)',
    description: 'Evenly spaced 120° triadic hues at controlled chroma.',
  );

  final String id;
  final String label;
  final String ruleLabel;
  final String description;

  const ProntoThemeId({
    required this.id,
    required this.label,
    required this.ruleLabel,
    required this.description,
  });

  static ProntoThemeId fromId(String? raw) {
    if (raw == null || raw.isEmpty) return ProntoThemeId.calm;
    for (final value in ProntoThemeId.values) {
      if (value.id == raw.toLowerCase().trim()) return value;
    }
    return ProntoThemeId.calm;
  }
}

/// Semantic design tokens beyond Material [ColorScheme].
/// Attached ONLY to the Admin Web [ThemeData] in Slice 1–4 so shared widgets
/// can check `context.maybeProntoTokens` and fall back to mobile's [PcTokens]
/// when null (ensuring zero visual change on mobile).
@immutable
class ProntoTokens extends ThemeExtension<ProntoTokens> {
  final Color sidebarBg;
  final Color sidebarFg;
  final Color sidebarMuted;
  final Color sidebarActive;
  final Color sidebarActiveFg;
  final Color sidebarBorder;

  final Color pageBg;
  final Color cardBg;
  final Color cardSubtleBg;
  final Color cardBorder;

  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;

  final Color success;
  final Color onSuccess;
  final Color successContainer;
  final Color onSuccessContainer;

  final Color warning;
  final Color onWarning;
  final Color warningContainer;
  final Color onWarningContainer;

  final Color danger;
  final Color onDanger;
  final Color dangerContainer;
  final Color onDangerContainer;

  /// Five harmonious chart series colors derived from the active theme group.
  final List<Color> chartPalette;

  const ProntoTokens({
    required this.sidebarBg,
    required this.sidebarFg,
    required this.sidebarMuted,
    required this.sidebarActive,
    required this.sidebarActiveFg,
    required this.sidebarBorder,
    required this.pageBg,
    required this.cardBg,
    required this.cardSubtleBg,
    required this.cardBorder,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.success,
    required this.onSuccess,
    required this.successContainer,
    required this.onSuccessContainer,
    required this.warning,
    required this.onWarning,
    required this.warningContainer,
    required this.onWarningContainer,
    required this.danger,
    required this.onDanger,
    required this.dangerContainer,
    required this.onDangerContainer,
    required this.chartPalette,
  }) : assert(chartPalette.length == 5, 'chartPalette must contain 5 colors');

  @override
  ProntoTokens copyWith({
    Color? sidebarBg,
    Color? sidebarFg,
    Color? sidebarMuted,
    Color? sidebarActive,
    Color? sidebarActiveFg,
    Color? sidebarBorder,
    Color? pageBg,
    Color? cardBg,
    Color? cardSubtleBg,
    Color? cardBorder,
    Color? textPrimary,
    Color? textSecondary,
    Color? textMuted,
    Color? success,
    Color? onSuccess,
    Color? successContainer,
    Color? onSuccessContainer,
    Color? warning,
    Color? onWarning,
    Color? warningContainer,
    Color? onWarningContainer,
    Color? danger,
    Color? onDanger,
    Color? dangerContainer,
    Color? onDangerContainer,
    List<Color>? chartPalette,
  }) {
    return ProntoTokens(
      sidebarBg: sidebarBg ?? this.sidebarBg,
      sidebarFg: sidebarFg ?? this.sidebarFg,
      sidebarMuted: sidebarMuted ?? this.sidebarMuted,
      sidebarActive: sidebarActive ?? this.sidebarActive,
      sidebarActiveFg: sidebarActiveFg ?? this.sidebarActiveFg,
      sidebarBorder: sidebarBorder ?? this.sidebarBorder,
      pageBg: pageBg ?? this.pageBg,
      cardBg: cardBg ?? this.cardBg,
      cardSubtleBg: cardSubtleBg ?? this.cardSubtleBg,
      cardBorder: cardBorder ?? this.cardBorder,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textMuted: textMuted ?? this.textMuted,
      success: success ?? this.success,
      onSuccess: onSuccess ?? this.onSuccess,
      successContainer: successContainer ?? this.successContainer,
      onSuccessContainer: onSuccessContainer ?? this.onSuccessContainer,
      warning: warning ?? this.warning,
      onWarning: onWarning ?? this.onWarning,
      warningContainer: warningContainer ?? this.warningContainer,
      onWarningContainer: onWarningContainer ?? this.onWarningContainer,
      danger: danger ?? this.danger,
      onDanger: onDanger ?? this.onDanger,
      dangerContainer: dangerContainer ?? this.dangerContainer,
      onDangerContainer: onDangerContainer ?? this.onDangerContainer,
      chartPalette: chartPalette ?? this.chartPalette,
    );
  }

  @override
  ProntoTokens lerp(ThemeExtension<ProntoTokens>? other, double t) {
    if (other is! ProntoTokens) return this;
    return ProntoTokens(
      sidebarBg: Color.lerp(sidebarBg, other.sidebarBg, t)!,
      sidebarFg: Color.lerp(sidebarFg, other.sidebarFg, t)!,
      sidebarMuted: Color.lerp(sidebarMuted, other.sidebarMuted, t)!,
      sidebarActive: Color.lerp(sidebarActive, other.sidebarActive, t)!,
      sidebarActiveFg: Color.lerp(sidebarActiveFg, other.sidebarActiveFg, t)!,
      sidebarBorder: Color.lerp(sidebarBorder, other.sidebarBorder, t)!,
      pageBg: Color.lerp(pageBg, other.pageBg, t)!,
      cardBg: Color.lerp(cardBg, other.cardBg, t)!,
      cardSubtleBg: Color.lerp(cardSubtleBg, other.cardSubtleBg, t)!,
      cardBorder: Color.lerp(cardBorder, other.cardBorder, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      success: Color.lerp(success, other.success, t)!,
      onSuccess: Color.lerp(onSuccess, other.onSuccess, t)!,
      successContainer:
          Color.lerp(successContainer, other.successContainer, t)!,
      onSuccessContainer:
          Color.lerp(onSuccessContainer, other.onSuccessContainer, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      onWarning: Color.lerp(onWarning, other.onWarning, t)!,
      warningContainer:
          Color.lerp(warningContainer, other.warningContainer, t)!,
      onWarningContainer:
          Color.lerp(onWarningContainer, other.onWarningContainer, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      onDanger: Color.lerp(onDanger, other.onDanger, t)!,
      dangerContainer: Color.lerp(dangerContainer, other.dangerContainer, t)!,
      onDangerContainer:
          Color.lerp(onDangerContainer, other.onDangerContainer, t)!,
      chartPalette: List<Color>.generate(
        5,
        (i) => Color.lerp(chartPalette[i], other.chartPalette[i], t)!,
      ),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ProntoTokens &&
        other.sidebarBg == sidebarBg &&
        other.sidebarFg == sidebarFg &&
        other.sidebarMuted == sidebarMuted &&
        other.sidebarActive == sidebarActive &&
        other.sidebarActiveFg == sidebarActiveFg &&
        other.sidebarBorder == sidebarBorder &&
        other.pageBg == pageBg &&
        other.cardBg == cardBg &&
        other.cardSubtleBg == cardSubtleBg &&
        other.cardBorder == cardBorder &&
        other.textPrimary == textPrimary &&
        other.textSecondary == textSecondary &&
        other.textMuted == textMuted &&
        other.success == success &&
        other.onSuccess == onSuccess &&
        other.successContainer == successContainer &&
        other.onSuccessContainer == onSuccessContainer &&
        other.warning == warning &&
        other.onWarning == onWarning &&
        other.warningContainer == warningContainer &&
        other.onWarningContainer == onWarningContainer &&
        other.danger == danger &&
        other.onDanger == onDanger &&
        other.dangerContainer == dangerContainer &&
        other.onDangerContainer == onDangerContainer &&
        listEquals(other.chartPalette, chartPalette);
  }

  @override
  int get hashCode => Object.hashAll([
        sidebarBg,
        sidebarFg,
        sidebarMuted,
        sidebarActive,
        sidebarActiveFg,
        sidebarBorder,
        pageBg,
        cardBg,
        cardSubtleBg,
        cardBorder,
        textPrimary,
        textSecondary,
        textMuted,
        success,
        onSuccess,
        successContainer,
        onSuccessContainer,
        warning,
        onWarning,
        warningContainer,
        onWarningContainer,
        danger,
        onDanger,
        dangerContainer,
        onDangerContainer,
        ...chartPalette,
      ]);
}

extension ProntoThemeContext on BuildContext {
  /// Non-null ONLY when inside the Admin Web theme scope.
  /// Shared widgets use this to keep Mobile 100% unchanged when null.
  ProntoTokens? get maybeProntoTokens =>
      Theme.of(this).extension<ProntoTokens>();

  /// Returns active [ProntoTokens] inside Admin Web routes.
  ProntoTokens get prontoTokens {
    final ext = Theme.of(this).extension<ProntoTokens>();
    assert(
      ext != null,
      'ProntoTokens not found in Theme. Ensure this widget is inside AdminShell or check maybeProntoTokens.',
    );
    return ext!;
  }
}
