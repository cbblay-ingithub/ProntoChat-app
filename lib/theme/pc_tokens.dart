import 'package:flutter/material.dart';

/// Responsive viewport breakpoints for Unified Flutter (Mobile + Tablet + Web).
/// Follows Flutter adaptive layout rules: evaluate constraints.maxWidth / MediaQuery.sizeOf,
/// never hardware type or device orientation.
class PcBreakpoints {
  const PcBreakpoints._();

  /// Compact (Mobile): single-pane with bottom NavigationBar (< 680px).
  static const double compact = 680.0;

  /// Medium (Tablet / Narrow Web): NavigationRail + master/detail split (680px - 1080px).
  static const double medium = 1080.0;

  /// Expanded (Desktop Web): 3-pane Slack/Linear workspace (>= 1080px).
  static const double expanded = 1080.0;

  /// Ultra-wide (Desktop Web with right context/directory inspector >= 1340px).
  static const double ultraWide = 1340.0;

  static bool isCompact(double width) => width < compact;
  static bool isMedium(double width) => width >= compact && width < expanded;
  static bool isExpanded(double width) => width >= expanded;
}

/// Shared Clean Light-Mode + Dynamic Firm Accent design tokens for ProntoChat.
@immutable
class PcTokens extends ThemeExtension<PcTokens> {
  final Color canvas;
  final Color surface;
  final Color surfaceSubtle;
  final Color sidebarBg;
  final Color railBg;
  final Color border;
  final Color borderStrong;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color primary;
  final Color onPrimary;
  final Color primarySoft;
  final Color primaryBorder;
  final Color incomingBubble;
  final Color incomingBubbleText;
  final Color outgoingBubble;
  final Color outgoingBubbleText;
  final Color online;
  final Color urgentBg;
  final Color urgentBorder;
  final Color urgentText;
  final Color projectAccent;
  final Color projectSoft;
  final Color warningAccent;
  final Color warningSoft;
  final Color infoAccent;
  final Color infoSoft;

  const PcTokens({
    required this.canvas,
    required this.surface,
    required this.surfaceSubtle,
    required this.sidebarBg,
    required this.railBg,
    required this.border,
    required this.borderStrong,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.primary,
    required this.onPrimary,
    required this.primarySoft,
    required this.primaryBorder,
    required this.incomingBubble,
    required this.incomingBubbleText,
    required this.outgoingBubble,
    required this.outgoingBubbleText,
    required this.online,
    required this.urgentBg,
    required this.urgentBorder,
    required this.urgentText,
    required this.projectAccent,
    required this.projectSoft,
    required this.warningAccent,
    required this.warningSoft,
    required this.infoAccent,
    required this.infoSoft,
  });

  static const Color defaultBrandBlue = Color(0xFF2563EB);

  /// Ensures firm accent colors remain legible on white/light surfaces using relative luminance.
  static Color readableAccentOnLight(Color raw) {
    final hsl = HSLColor.fromColor(raw);
    if (raw.computeLuminance() > 0.42 || hsl.lightness > 0.52) {
      return hsl
          .withLightness(0.38)
          .withSaturation((hsl.saturation * 1.05).clamp(0.40, 1.0))
          .toColor();
    }
    return raw;
  }

  /// Picks white or deep slate foreground depending on luminance of [bg].
  static Color contrastOn(Color bg) {
    return ThemeData.estimateBrightnessForColor(bg) == Brightness.dark
        ? Colors.white
        : const Color(0xFF0F172A);
  }

  factory PcTokens.light({Color primaryColor = defaultBrandBlue}) {
    final accent = readableAccentOnLight(primaryColor);
    final onAccent = contrastOn(accent);

    return PcTokens(
      canvas: const Color(0xFFF8FAFC),
      surface: const Color(0xFFFFFFFF),
      surfaceSubtle: const Color(0xFFF1F5F9),
      sidebarBg: const Color(0xFFF4F6F9),
      railBg: const Color(0xFFEEF2F6),
      border: const Color(0xFFE2E8F0),
      borderStrong: const Color(0xFFCBD5E1),
      textPrimary: const Color(0xFF0F172A),
      textSecondary: const Color(0xFF475569),
      textMuted: const Color(0xFF64748B),
      primary: accent,
      onPrimary: onAccent,
      primarySoft: accent.withValues(alpha: 0.10),
      primaryBorder: accent.withValues(alpha: 0.24),
      incomingBubble: const Color(0xFFF1F5F9),
      incomingBubbleText: const Color(0xFF0F172A),
      outgoingBubble: accent,
      outgoingBubbleText: onAccent,
      online: const Color(0xFF10B981),
      urgentBg: const Color(0xFFFEF2F2),
      urgentBorder: const Color(0xFFFECACA),
      urgentText: const Color(0xFFDC2626),
      projectAccent: const Color(0xFF7C3AED),
      projectSoft: const Color(0xFFF3E8FF),
      warningAccent: const Color(0xFFD97706),
      warningSoft: const Color(0xFFFEF3C7),
      infoAccent: const Color(0xFF0284C7),
      infoSoft: const Color(0xFFE0F2FE),
    );
  }

  @override
  PcTokens copyWith({
    Color? canvas,
    Color? surface,
    Color? surfaceSubtle,
    Color? sidebarBg,
    Color? railBg,
    Color? border,
    Color? borderStrong,
    Color? textPrimary,
    Color? textSecondary,
    Color? textMuted,
    Color? primary,
    Color? onPrimary,
    Color? primarySoft,
    Color? primaryBorder,
    Color? incomingBubble,
    Color? incomingBubbleText,
    Color? outgoingBubble,
    Color? outgoingBubbleText,
    Color? online,
    Color? urgentBg,
    Color? urgentBorder,
    Color? urgentText,
    Color? projectAccent,
    Color? projectSoft,
    Color? warningAccent,
    Color? warningSoft,
    Color? infoAccent,
    Color? infoSoft,
  }) {
    return PcTokens(
      canvas: canvas ?? this.canvas,
      surface: surface ?? this.surface,
      surfaceSubtle: surfaceSubtle ?? this.surfaceSubtle,
      sidebarBg: sidebarBg ?? this.sidebarBg,
      railBg: railBg ?? this.railBg,
      border: border ?? this.border,
      borderStrong: borderStrong ?? this.borderStrong,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textMuted: textMuted ?? this.textMuted,
      primary: primary ?? this.primary,
      onPrimary: onPrimary ?? this.onPrimary,
      primarySoft: primarySoft ?? this.primarySoft,
      primaryBorder: primaryBorder ?? this.primaryBorder,
      incomingBubble: incomingBubble ?? this.incomingBubble,
      incomingBubbleText: incomingBubbleText ?? this.incomingBubbleText,
      outgoingBubble: outgoingBubble ?? this.outgoingBubble,
      outgoingBubbleText: outgoingBubbleText ?? this.outgoingBubbleText,
      online: online ?? this.online,
      urgentBg: urgentBg ?? this.urgentBg,
      urgentBorder: urgentBorder ?? this.urgentBorder,
      urgentText: urgentText ?? this.urgentText,
      projectAccent: projectAccent ?? this.projectAccent,
      projectSoft: projectSoft ?? this.projectSoft,
      warningAccent: warningAccent ?? this.warningAccent,
      warningSoft: warningSoft ?? this.warningSoft,
      infoAccent: infoAccent ?? this.infoAccent,
      infoSoft: infoSoft ?? this.infoSoft,
    );
  }

  @override
  PcTokens lerp(ThemeExtension<PcTokens>? other, double t) {
    if (other is! PcTokens) return this;
    return PcTokens(
      canvas: Color.lerp(canvas, other.canvas, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceSubtle: Color.lerp(surfaceSubtle, other.surfaceSubtle, t)!,
      sidebarBg: Color.lerp(sidebarBg, other.sidebarBg, t)!,
      railBg: Color.lerp(railBg, other.railBg, t)!,
      border: Color.lerp(border, other.border, t)!,
      borderStrong: Color.lerp(borderStrong, other.borderStrong, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      primary: Color.lerp(primary, other.primary, t)!,
      onPrimary: Color.lerp(onPrimary, other.onPrimary, t)!,
      primarySoft: Color.lerp(primarySoft, other.primarySoft, t)!,
      primaryBorder: Color.lerp(primaryBorder, other.primaryBorder, t)!,
      incomingBubble: Color.lerp(incomingBubble, other.incomingBubble, t)!,
      incomingBubbleText: Color.lerp(incomingBubbleText, other.incomingBubbleText, t)!,
      outgoingBubble: Color.lerp(outgoingBubble, other.outgoingBubble, t)!,
      outgoingBubbleText: Color.lerp(outgoingBubbleText, other.outgoingBubbleText, t)!,
      online: Color.lerp(online, other.online, t)!,
      urgentBg: Color.lerp(urgentBg, other.urgentBg, t)!,
      urgentBorder: Color.lerp(urgentBorder, other.urgentBorder, t)!,
      urgentText: Color.lerp(urgentText, other.urgentText, t)!,
      projectAccent: Color.lerp(projectAccent, other.projectAccent, t)!,
      projectSoft: Color.lerp(projectSoft, other.projectSoft, t)!,
      warningAccent: Color.lerp(warningAccent, other.warningAccent, t)!,
      warningSoft: Color.lerp(warningSoft, other.warningSoft, t)!,
      infoAccent: Color.lerp(infoAccent, other.infoAccent, t)!,
      infoSoft: Color.lerp(infoSoft, other.infoSoft, t)!,
    );
  }
}

extension PcThemeContext on BuildContext {
  /// Returns active [PcTokens] or falls back to clean light tokens derived from Theme primary.
  PcTokens get pcTokens {
    final theme = Theme.of(this);
    return theme.extension<PcTokens>() ??
        PcTokens.light(primaryColor: theme.colorScheme.primary);
  }
}

class PcThemeBuilder {
  const PcThemeBuilder._();

  static ThemeData buildLightTheme({
    Color primaryColor = PcTokens.defaultBrandBlue,
    Color? secondaryColor,
  }) {
    final tokens = PcTokens.light(primaryColor: primaryColor);
    final secondary = secondaryColor != null
        ? PcTokens.readableAccentOnLight(secondaryColor)
        : tokens.primary;

    final colorScheme = ColorScheme.light(
      primary: tokens.primary,
      onPrimary: tokens.onPrimary,
      primaryContainer: tokens.primarySoft,
      onPrimaryContainer: tokens.primary,
      secondary: secondary,
      onSecondary: PcTokens.contrastOn(secondary),
      surface: tokens.surface,
      onSurface: tokens.textPrimary,
      surfaceContainerHighest: tokens.surfaceSubtle,
      outline: tokens.border,
      outlineVariant: tokens.borderStrong,
      error: tokens.urgentText,
      onError: Colors.white,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: tokens.canvas,
      canvasColor: tokens.surface,
      cardColor: tokens.surface,
      dividerColor: tokens.border,
      extensions: [tokens],
      appBarTheme: AppBarTheme(
        backgroundColor: tokens.surface,
        foregroundColor: tokens.textPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        centerTitle: false,
        iconTheme: IconThemeData(color: tokens.textSecondary),
        titleTextStyle: TextStyle(
          color: tokens.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
        ),
      ),
      cardTheme: CardThemeData(
        color: tokens.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: tokens.border),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: tokens.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        titleTextStyle: TextStyle(
          color: tokens.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
        contentTextStyle: TextStyle(
          color: tokens.textSecondary,
          fontSize: 14,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: tokens.surface,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: tokens.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: tokens.border,
        thickness: 1,
        space: 1,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: tokens.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: tokens.primarySoft,
        elevation: 0,
        height: 64,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 11.5,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? tokens.primary : tokens.textMuted,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            size: 22,
            color: selected ? tokens.primary : tokens.textMuted,
          );
        }),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: tokens.railBg,
        indicatorColor: tokens.primarySoft,
        selectedIconTheme: IconThemeData(color: tokens.primary, size: 22),
        unselectedIconTheme: IconThemeData(color: tokens.textSecondary, size: 22),
        selectedLabelTextStyle: TextStyle(
          color: tokens.primary,
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelTextStyle: TextStyle(
          color: tokens.textSecondary,
          fontSize: 11.5,
          fontWeight: FontWeight.w500,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: tokens.surfaceSubtle,
        hintStyle: TextStyle(color: tokens.textMuted, fontSize: 13.5),
        labelStyle: TextStyle(color: tokens.textSecondary, fontSize: 13.5),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: tokens.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: tokens.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: tokens.primary, width: 1.5),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: tokens.primary,
          foregroundColor: tokens.onPrimary,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: tokens.textPrimary,
          side: BorderSide(color: tokens.borderStrong),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: tokens.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: tokens.border),
        ),
        textStyle: TextStyle(color: tokens.textPrimary, fontSize: 13.5),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: const Color(0xFF0F172A),
        contentTextStyle: const TextStyle(color: Colors.white, fontSize: 13.5),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}
