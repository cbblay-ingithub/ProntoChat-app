import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show Uint8List;
import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../models/firm.dart';
import '../../../models/media_ref.dart' show MediaPurpose;
import '../../../providers/firm/providers.dart';
import '../../../services/audit_service.dart';
import '../../../services/chat_service.dart';
import '../../../services/media_service.dart';
import '../../../services/snackbar_service.dart';
import '../../../theme/admin_theme_provider.dart';
import '../../../theme/pronto_palette_engine.dart';
import '../../../theme/pronto_tokens.dart';
import '../../../widgets/common/pc_logo.dart';

class CustomizationTab extends ConsumerStatefulWidget {
  const CustomizationTab({super.key});

  @override
  ConsumerState<CustomizationTab> createState() => _CustomizationTabState();
}

class _CustomizationTabState extends ConsumerState<CustomizationTab> {
  // Non-theme firm settings staged locally (accentHex + themeId are staged in AdminThemeController for live re-theming)
  String? _stagedWelcomeText;
  bool? _stagedShowLastSeen;
  bool? _stagedShowReadReceipts;
  MediaRef? _stagedLogo;
  String? _stagedLogoUrl;
  bool _initializedNonThemeFields = false;

  final TextEditingController _welcomeTextController = TextEditingController();

  bool _isUploadingLogo = false;
  bool _isSaving = false;
  bool _isDraggingLogo = false;

  // Live preview mode: 0 = Admin Hub Mini, 1 = Join Screen, 2 = Chat Home
  int _previewMode = 0;

  @override
  void initState() {
    super.initState();
    final firm = ref.read(currentFirmProvider);
    if (firm != null) {
      _initNonThemeFields(firm);
    }
  }

  void _initNonThemeFields(Firm firm) {
    _stagedWelcomeText = firm.welcomeText ?? '';
    _welcomeTextController.text = _stagedWelcomeText!;
    _stagedShowLastSeen = firm.showLastSeen;
    _stagedShowReadReceipts = firm.showReadReceipts;
    _stagedLogo = firm.logo;
    _stagedLogoUrl = firm.logoUrl;
    _initializedNonThemeFields = true;
  }

  @override
  void dispose() {
    _welcomeTextController.dispose();
    super.dispose();
  }

  bool _hasNonThemeChanges(Firm firm) {
    if (!_initializedNonThemeFields) return false;
    if (_stagedWelcomeText != (firm.welcomeText ?? '')) return true;
    if (_stagedShowLastSeen != firm.showLastSeen) return true;
    if (_stagedShowReadReceipts != firm.showReadReceipts) return true;
    if (_stagedLogo != firm.logo) return true;
    if (_stagedLogoUrl != firm.logoUrl) return true;
    return false;
  }

  void _handleDiscard(Firm firm) {
    ref.read(adminThemeControllerProvider.notifier).discardStaged();
    setState(() => _initNonThemeFields(firm));
  }

  void _handleResetDefaults() {
    ref.read(adminThemeControllerProvider.notifier).stageDefaults();
  }

  @override
  Widget build(BuildContext context) {
    final spec = ref.watch(adminThemeSpecProvider);
    final themeState = ref.watch(adminThemeControllerProvider);
    final tokens = spec.tokens;
    final cs = spec.colorScheme;
    final firm = ref.watch(currentFirmProvider);

    if (firm == null) {
      return Center(child: CircularProgressIndicator(color: cs.primary));
    }

    if (!_initializedNonThemeFields) {
      _initNonThemeFields(firm);
    }

    final activeSeedColor =
        ProntoPaletteEngine.parseHex(themeState.effectiveAccentHex);
    final activeThemeId = themeState.effectiveThemeId;
    final hasChanges =
        themeState.hasStagedBrandingChanges || _hasNonThemeChanges(firm);
    final isAtDefaults = themeState.effectiveAccentHex.toUpperCase() ==
            ProntoPaletteEngine.defaultAccentHex &&
        activeThemeId == ProntoPaletteEngine.defaultThemeId;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompactPadding = constraints.maxWidth < 760;
        final isStackedColumns = constraints.maxWidth < 960;

        return SingleChildScrollView(
          padding: EdgeInsets.all(isCompactPadding ? 16 : 24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildHeaderBar(
                    context: context,
                    tokens: tokens,
                    cs: cs,
                    firm: firm,
                    themeState: themeState,
                    hasChanges: hasChanges,
                    isAtDefaults: isAtDefaults,
                    isCompact: isCompactPadding,
                  ),
                  const SizedBox(height: 20),

                  if (hasChanges) ...[
                    _buildUnsavedBanner(
                      context: context,
                      tokens: tokens,
                      cs: cs,
                      firm: firm,
                    ),
                    const SizedBox(height: 20),
                  ],

                  // Full-width Harmony Theme & Accent Studio (5 Theme Preview Cards + Accent Picker + Light/Dark)
                  _buildThemeHarmonyStudio(
                    context: context,
                    spec: spec,
                    themeState: themeState,
                    activeSeedColor: activeSeedColor,
                    activeThemeId: activeThemeId,
                  ),
                  const SizedBox(height: 24),

                  // Lower workspace settings + interactive mockup
                  if (isStackedColumns) ...[
                    _buildWorkspaceDetailsColumn(
                      context: context,
                      tokens: tokens,
                      cs: cs,
                      firm: firm,
                    ),
                    const SizedBox(height: 24),
                    _buildLivePreviewCard(
                      spec: spec,
                      firm: firm,
                    ),
                  ] else ...[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 6,
                          child: _buildWorkspaceDetailsColumn(
                            context: context,
                            tokens: tokens,
                            cs: cs,
                            firm: firm,
                          ),
                        ),
                        const SizedBox(width: 24),
                        Expanded(
                          flex: 5,
                          child: _buildLivePreviewCard(
                            spec: spec,
                            firm: firm,
                          ),
                        ),
                      ],
                    ),
                  ],

                  const SizedBox(height: 28),
                  _buildDangerZone(context, spec.themeData, tokens, firm),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // 1. HEADER BAR WITH LIGHT/DARK SWITCH, RESET, AND SAVE
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildHeaderBar({
    required BuildContext context,
    required ProntoTokens tokens,
    required ColorScheme cs,
    required Firm firm,
    required AdminThemeControllerState themeState,
    required bool hasChanges,
    required bool isAtDefaults,
    required bool isCompact,
  }) {
    final controls = Wrap(
      spacing: 10,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        // Light / Dark Mode Switch Pill
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: tokens.cardSubtleBg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: tokens.cardBorder),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                themeState.isDarkMode
                    ? Icons.dark_mode_rounded
                    : Icons.light_mode_rounded,
                size: 17,
                color: cs.primary,
              ),
              const SizedBox(width: 8),
              Text(
                themeState.isDarkMode ? 'Dark Mode' : 'Light Mode',
                style: TextStyle(
                  color: tokens.textPrimary,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 6),
              SizedBox(
                height: 28,
                child: Switch.adaptive(
                  value: themeState.isDarkMode,
                  onChanged: (val) => ref
                      .read(adminThemeControllerProvider.notifier)
                      .setDarkMode(val),
                ),
              ),
            ],
          ),
        ),

        OutlinedButton.icon(
          onPressed: isAtDefaults ? null : _handleResetDefaults,
          icon: const Icon(Icons.restart_alt_rounded, size: 17),
          label: const Text('Reset'),
        ),

        ElevatedButton.icon(
          onPressed: (!_isSaving && hasChanges)
              ? () => _saveCustomizations(context, firm)
              : null,
          icon: _isSaving
              ? SizedBox(
                  width: 15,
                  height: 15,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: cs.onPrimary,
                  ),
                )
              : const Icon(Icons.check_rounded, size: 17),
          label: Text(_isSaving ? 'Saving...' : 'Save Changes'),
        ),
      ],
    );

    return Container(
      decoration: BoxDecoration(
        color: tokens.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: tokens.cardBorder),
      ),
      padding: EdgeInsets.all(isCompact ? 16 : 22),
      child: isCompact
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeaderTitleBlock(tokens, cs),
                const SizedBox(height: 14),
                controls,
              ],
            )
          : Row(
              children: [
                Expanded(child: _buildHeaderTitleBlock(tokens, cs)),
                const SizedBox(width: 16),
                controls,
              ],
            ),
    );
  }

  Widget _buildHeaderTitleBlock(ProntoTokens tokens, ColorScheme cs) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: cs.primaryContainer,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            Icons.palette_outlined,
            color: cs.onPrimaryContainer,
            size: 22,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Workspace Customization & Theme Harmony',
                style: TextStyle(
                  color: tokens.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                'Choose a brand accent color and one of five HCT color harmonies. Admin Web updates live as you preview.',
                style: TextStyle(color: tokens.textSecondary, fontSize: 13),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildUnsavedBanner({
    required BuildContext context,
    required ProntoTokens tokens,
    required ColorScheme cs,
    required Firm firm,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: cs.primaryContainer.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.primary.withValues(alpha: 0.35)),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 10,
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.auto_awesome_outlined, color: cs.primary, size: 19),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  'Live preview active — save to persist your accent and harmony theme for all admins.',
                  style: TextStyle(
                    color: tokens.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextButton(
                onPressed: () => _handleDiscard(firm),
                child: Text(
                  'Discard',
                  style: TextStyle(color: tokens.textSecondary),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed:
                    _isSaving ? null : () => _saveCustomizations(context, firm),
                child: const Text('Save Changes'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // 2. ACCENT PICKER + 5 HARMONY THEME PREVIEW CARDS
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildThemeHarmonyStudio({
    required BuildContext context,
    required ProntoThemeSpec spec,
    required AdminThemeControllerState themeState,
    required Color activeSeedColor,
    required ProntoThemeId activeThemeId,
  }) {
    final tokens = spec.tokens;
    final cs = spec.colorScheme;
    final hexLabel = ProntoPaletteEngine.toHex(activeSeedColor);

    final bodyContrast =
        ProntoPaletteEngine.contrastRatio(tokens.textPrimary, tokens.cardBg);
    final labelContrast =
        ProntoPaletteEngine.contrastRatio(tokens.textMuted, tokens.pageBg);
    final buttonContrast =
        ProntoPaletteEngine.contrastRatio(cs.onPrimary, cs.primary);
    final chipContrast = ProntoPaletteEngine.contrastRatio(
      cs.onSecondaryContainer,
      cs.secondaryContainer,
    );

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: tokens.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: tokens.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Accent Row
          Wrap(
            spacing: 16,
            runSpacing: 12,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '1. Brand Accent Seed',
                    style: TextStyle(
                      color: tokens.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Drives your primary action color, harmony hue angles, and subtle neutral surface tint.',
                    style: TextStyle(color: tokens.textSecondary, fontSize: 12.5),
                  ),
                ],
              ),
              InkWell(
                onTap: () => _openColorPickerDialog(
                  context,
                  spec.themeData,
                  tokens,
                  activeSeedColor,
                ),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: tokens.cardSubtleBg,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: cs.outline),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          color: activeSeedColor,
                          shape: BoxShape.circle,
                          border: Border.all(color: tokens.cardBorder),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        hexLabel,
                        style: TextStyle(
                          color: tokens.textPrimary,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Icon(
                        Icons.colorize_rounded,
                        size: 15,
                        color: cs.primary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Custom',
                        style: TextStyle(
                          color: cs.primary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Preset Swatches
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: ProntoPaletteEngine.presetAccents.map((preset) {
              final isChosen =
                  ProntoPaletteEngine.toHex(preset) == hexLabel.toUpperCase();
              final checkColor = ProntoPaletteEngine.contrastRatio(
                        tokens.cardBg,
                        preset,
                      ) >=
                      4.5
                  ? tokens.cardBg
                  : tokens.textPrimary;
              return Tooltip(
                message: ProntoPaletteEngine.toHex(preset),
                child: InkWell(
                  onTap: () => ref
                      .read(adminThemeControllerProvider.notifier)
                      .stageAccentColor(preset),
                  borderRadius: BorderRadius.circular(20),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: preset,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isChosen ? tokens.textPrimary : tokens.cardBorder,
                        width: isChosen ? 2.5 : 1.0,
                      ),
                    ),
                    child: isChosen
                        ? Icon(Icons.check_rounded, size: 18, color: checkColor)
                        : null,
                  ),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 20),
          Divider(color: tokens.cardBorder, height: 1),
          const SizedBox(height: 20),

          // 5 Harmony Theme Preview Cards Header
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '2. Color Harmony Theme',
                      style: TextStyle(
                        color: tokens.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Select a harmony model to preview how primary actions, secondary chips, tertiary badges, and tinted surfaces coordinate.',
                      style:
                          TextStyle(color: tokens.textSecondary, fontSize: 12.5),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Responsive Grid of 5 Theme Preview Cards
          LayoutBuilder(
            builder: (context, gridConstraints) {
              final maxW = gridConstraints.maxWidth;
              final int columns;
              if (maxW >= 1120) {
                columns = 5;
              } else if (maxW >= 780) {
                columns = 3;
              } else if (maxW >= 460) {
                columns = 2;
              } else {
                columns = 1;
              }
              const spacing = 12.0;
              final cardWidth =
                  (maxW - spacing * (columns - 1)) / columns;

              return Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: ProntoThemeId.values.map((option) {
                  final previewSpec = ProntoPaletteEngine.build(
                    seedColor: activeSeedColor,
                    themeId: option,
                    brightness: spec.brightness,
                  );
                  final isSelected = option == activeThemeId;

                  return SizedBox(
                    width: cardWidth,
                    child: _buildHarmonyPreviewCard(
                      option: option,
                      cardSpec: previewSpec,
                      hostTokens: tokens,
                      hostScheme: cs,
                      isSelected: isSelected,
                    ),
                  );
                }).toList(),
              );
            },
          ),

          const SizedBox(height: 18),
          Divider(color: tokens.cardBorder, height: 1),
          const SizedBox(height: 14),

          // Live WCAG AA Verification Strip
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Icon(
                Icons.verified_user_outlined,
                size: 17,
                color: tokens.success,
              ),
              Text(
                'WCAG AA Contrast (${activeThemeId.label} • ${themeState.isDarkMode ? 'Dark' : 'Light'}):',
                style: TextStyle(
                  color: tokens.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              _buildWcagBadge(tokens, 'Body Text', bodyContrast),
              _buildWcagBadge(tokens, 'Muted Labels', labelContrast),
              _buildWcagBadge(tokens, 'Primary Button', buttonContrast),
              _buildWcagBadge(tokens, 'Secondary Chip', chipContrast),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHarmonyPreviewCard({
    required ProntoThemeId option,
    required ProntoThemeSpec cardSpec,
    required ProntoTokens hostTokens,
    required ColorScheme hostScheme,
    required bool isSelected,
  }) {
    final pCs = cardSpec.colorScheme;
    final pT = cardSpec.tokens;

    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: () => ref
            .read(adminThemeControllerProvider.notifier)
            .stageThemeId(option),
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isSelected
                ? hostScheme.primaryContainer.withValues(alpha: 0.32)
                : hostTokens.cardSubtleBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? hostScheme.primary : hostTokens.cardBorder,
              width: isSelected ? 2.0 : 1.0,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Card Title + Selected Indicator
              Row(
                children: [
                  Expanded(
                    child: Text(
                      option.label,
                      style: TextStyle(
                        color: hostTokens.textPrimary,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (isSelected)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: hostScheme.primary,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Active',
                        style: TextStyle(
                          color: hostScheme.onPrimary,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    )
                  else
                    Icon(
                      Icons.radio_button_unchecked,
                      size: 16,
                      color: hostTokens.textMuted,
                    ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                option.ruleLabel,
                style: TextStyle(
                  color: hostTokens.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 10),

              // Miniature Admin Layout Preview
              Container(
                height: 88,
                decoration: BoxDecoration(
                  color: pT.pageBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: pT.cardBorder),
                ),
                clipBehavior: Clip.antiAlias,
                child: Row(
                  children: [
                    // Mini Sidebar
                    Container(
                      width: 42,
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: pT.sidebarBg,
                        border: Border(
                          right: BorderSide(color: pT.sidebarBorder),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: pCs.primary,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            height: 9,
                            decoration: BoxDecoration(
                              color: pT.sidebarActive,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                          const SizedBox(height: 5),
                          Container(
                            width: 22,
                            height: 5,
                            decoration: BoxDecoration(
                              color: pT.sidebarMuted.withValues(alpha: 0.45),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(height: 5),
                          Container(
                            width: 26,
                            height: 5,
                            decoration: BoxDecoration(
                              color: pT.sidebarMuted.withValues(alpha: 0.35),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Mini Content Area
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(7),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Top action + chip + badge row
                            Row(
                              children: [
                                Container(
                                  width: 34,
                                  height: 11,
                                  decoration: BoxDecoration(
                                    color: pCs.primary,
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Container(
                                  width: 24,
                                  height: 11,
                                  decoration: BoxDecoration(
                                    color: pCs.secondaryContainer,
                                    borderRadius: BorderRadius.circular(3),
                                    border: Border.all(
                                      color: pCs.secondary.withValues(
                                        alpha: 0.45,
                                      ),
                                    ),
                                  ),
                                ),
                                const Spacer(),
                                Container(
                                  width: 16,
                                  height: 11,
                                  decoration: BoxDecoration(
                                    color: pCs.tertiaryContainer,
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 7),

                            // Mini Card with 3 harmony series bars
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: pT.cardBg,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: pT.cardBorder),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Container(
                                            width: 42,
                                            height: 5,
                                            decoration: BoxDecoration(
                                              color: pT.textPrimary,
                                              borderRadius:
                                                  BorderRadius.circular(2),
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Container(
                                            width: 28,
                                            height: 4,
                                            decoration: BoxDecoration(
                                              color: pT.textMuted,
                                              borderRadius:
                                                  BorderRadius.circular(2),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    _buildMiniBar(pT.chartPalette[0], 24),
                                    const SizedBox(width: 3),
                                    _buildMiniBar(pT.chartPalette[1], 17),
                                    const SizedBox(width: 3),
                                    _buildMiniBar(pT.chartPalette[2], 21),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              // 4 Group Swatches: Primary, Secondary, Tertiary, Surface
              Row(
                children: [
                  _buildRoleSwatch(
                    color: pCs.primary,
                    borderColor: hostTokens.cardBorder,
                    label: 'Pri',
                    textColor: hostTokens.textMuted,
                  ),
                  const SizedBox(width: 6),
                  _buildRoleSwatch(
                    color: pCs.secondary,
                    borderColor: hostTokens.cardBorder,
                    label: 'Sec',
                    textColor: hostTokens.textMuted,
                  ),
                  const SizedBox(width: 6),
                  _buildRoleSwatch(
                    color: pCs.tertiary,
                    borderColor: hostTokens.cardBorder,
                    label: 'Ter',
                    textColor: hostTokens.textMuted,
                  ),
                  const SizedBox(width: 6),
                  _buildRoleSwatch(
                    color: pT.pageBg,
                    borderColor: hostTokens.cardBorder,
                    label: 'Srf',
                    textColor: hostTokens.textMuted,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMiniBar(Color color, double height) {
    return Container(
      width: 7,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  Widget _buildRoleSwatch({
    required Color color,
    required Color borderColor,
    required String label,
    required Color textColor,
  }) {
    return Expanded(
      child: Column(
        children: [
          Container(
            height: 16,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: borderColor),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: TextStyle(
              color: textColor,
              fontSize: 9.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWcagBadge(ProntoTokens tokens, String label, double ratio) {
    final passesAA = ratio >= 4.5;
    final passesAAA = ratio >= 7.0;
    final grade = passesAAA ? 'AAA' : (passesAA ? 'AA' : 'LOW');
    final bg = passesAA ? tokens.successContainer : tokens.dangerContainer;
    final fg = passesAA ? tokens.onSuccessContainer : tokens.onDangerContainer;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        '$label ${ratio.toStringAsFixed(1)}:1 ($grade)',
        style: TextStyle(
          color: fg,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // 3. LOGO, JOIN WELCOME MESSAGE & CHAT POLICIES
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildWorkspaceDetailsColumn({
    required BuildContext context,
    required ProntoTokens tokens,
    required ColorScheme cs,
    required Firm firm,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Logo Card
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: tokens.cardBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: tokens.cardBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Company Brand Logo',
                style: TextStyle(
                  color: tokens.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Upload your company icon or seal. Dual-write supports Cloudinary named transformations.',
                style: TextStyle(color: tokens.textSecondary, fontSize: 12.5),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  PcLogo(
                    logo: _stagedLogo,
                    legacyUrl: _stagedLogoUrl,
                    size: 56,
                    borderRadius: 12,
                    variant: MediaVariant.logoSm,
                    firmName: firm.name,
                    primaryColor: cs.primary,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: DropTarget(
                      onDragEntered: (_) =>
                          setState(() => _isDraggingLogo = true),
                      onDragExited: (_) =>
                          setState(() => _isDraggingLogo = false),
                      onDragDone: (details) async {
                        setState(() => _isDraggingLogo = false);
                        if (details.files.isNotEmpty) {
                          final file = details.files.first;
                          final bytes = await file.readAsBytes();
                          _uploadLogoBytes(bytes, file.name, firm);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: 14,
                          horizontal: 16,
                        ),
                        decoration: BoxDecoration(
                          color: _isDraggingLogo
                              ? cs.primaryContainer.withValues(alpha: 0.45)
                              : tokens.cardSubtleBg,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: _isDraggingLogo
                                ? cs.primary
                                : tokens.cardBorder,
                          ),
                        ),
                        child: Wrap(
                          alignment: WrapAlignment.center,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 6,
                          children: [
                            Icon(
                              Icons.file_upload_outlined,
                              size: 19,
                              color: tokens.textMuted,
                            ),
                            Text(
                              'Drop image or',
                              style: TextStyle(
                                color: tokens.textSecondary,
                                fontSize: 12.5,
                              ),
                            ),
                            InkWell(
                              onTap: _isUploadingLogo
                                  ? null
                                  : () => _pickAndUploadLogo(context, firm),
                              child: Text(
                                _isUploadingLogo ? 'Uploading...' : 'Browse',
                                style: TextStyle(
                                  color: cs.primary,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12.5,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 2. Employee Join Screen Welcome Message
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: tokens.cardBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: tokens.cardBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Join Screen Welcome Message',
                style: TextStyle(
                  color: tokens.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Displayed to employees when they scan the QR code or enter the Firm ID (max 200 characters).',
                style: TextStyle(color: tokens.textSecondary, fontSize: 12.5),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _welcomeTextController,
                maxLength: 200,
                maxLines: 2,
                style: TextStyle(color: tokens.textPrimary, fontSize: 13.5),
                decoration: InputDecoration(
                  hintText:
                      'e.g. Welcome to Acme Corp! Enter your staff code or request access.',
                  counterStyle:
                      TextStyle(color: tokens.textMuted, fontSize: 11.5),
                ),
                onChanged: (val) =>
                    setState(() => _stagedWelcomeText = val.trim()),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 3. Chat & Presence Policies
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: tokens.cardBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: tokens.cardBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Chat & Presence Policies',
                style: TextStyle(
                  color: tokens.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Firm-wide communication privacy toggles.',
                style: TextStyle(color: tokens.textSecondary, fontSize: 12.5),
              ),
              const SizedBox(height: 8),
              Material(
                type: MaterialType.transparency,
                child: Column(
                  children: [
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        'Show Last Seen & Online Presence',
                        style: TextStyle(
                          color: tokens.textPrimary,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        'Allow members to see when teammates were last active in chats.',
                        style: TextStyle(
                          color: tokens.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                      value: _stagedShowLastSeen ?? firm.showLastSeen,
                      onChanged: (val) =>
                          setState(() => _stagedShowLastSeen = val),
                    ),
                    Divider(color: tokens.cardBorder, height: 16),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        'Show Read Receipts',
                        style: TextStyle(
                          color: tokens.textPrimary,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        'Show double checkmarks in direct messages and participant counts in groups.',
                        style: TextStyle(
                          color: tokens.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                      value: _stagedShowReadReceipts ?? firm.showReadReceipts,
                      onChanged: (val) =>
                          setState(() => _stagedShowReadReceipts = val),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // 4. INTERACTIVE LIVE PREVIEW CARD (TOKEN-DRIVEN, ZERO HARDCODED COLORS)
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildLivePreviewCard({
    required ProntoThemeSpec spec,
    required Firm firm,
  }) {
    final tokens = spec.tokens;
    final cs = spec.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: tokens.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: tokens.cardBorder),
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 10,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.devices_rounded,
                    color: cs.primary,
                    size: 19,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Interactive Role Preview',
                    style: TextStyle(
                      color: tokens.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: tokens.cardSubtleBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: tokens.cardBorder),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildPreviewTabBtn(tokens, 0, 'Hub Roles'),
                    _buildPreviewTabBtn(tokens, 1, 'Join'),
                    _buildPreviewTabBtn(tokens, 2, 'Chat'),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          Container(
            constraints: const BoxConstraints(minHeight: 360),
            decoration: BoxDecoration(
              color: tokens.pageBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: tokens.cardBorder, width: 1.5),
            ),
            clipBehavior: Clip.antiAlias,
            child: _previewMode == 0
                ? _buildRoleBreakdownPreview(spec, firm)
                : (_previewMode == 1
                    ? _buildJoinPreview(spec, firm)
                    : _buildChatPreview(spec, firm)),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewTabBtn(ProntoTokens tokens, int mode, String label) {
    final isSelected = _previewMode == mode;
    return InkWell(
      onTap: () => setState(() => _previewMode = mode),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected
              ? tokens.cardBg
              : ProntoPaletteEngine.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? tokens.textPrimary : tokens.textSecondary,
            fontSize: 11.5,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildRoleBreakdownPreview(ProntoThemeSpec spec, Firm firm) {
    final tokens = spec.tokens;
    final cs = spec.colorScheme;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top strip showing Primary, Secondary Chip, Tertiary Badge
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: cs.primary,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Primary Action',
                  style: TextStyle(
                    color: cs.onPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: cs.secondaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Secondary Chip',
                  style: TextStyle(
                    color: cs.onSecondaryContainer,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: cs.tertiaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Tertiary Badge',
                  style: TextStyle(
                    color: cs.onTertiaryContainer,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 5-Series Chart Palette Preview Card
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: tokens.cardBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: tokens.cardBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '5-Series Chart Harmony (${spec.themeId.label})',
                  style: TextStyle(
                    color: tokens.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Drawn from primary, secondary, and tertiary tonal palettes.',
                  style: TextStyle(color: tokens.textMuted, fontSize: 11.5),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  height: 94,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: List.generate(5, (index) {
                      const heights = [68.0, 52.0, 60.0, 42.0, 48.0];
                      return Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(right: index < 4 ? 8 : 0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Container(
                                height: heights[index],
                                decoration: BoxDecoration(
                                  color: tokens.chartPalette[index],
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'S${index + 1}',
                                style: TextStyle(
                                  color: tokens.textMuted,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Fixed Semantic Status Pills
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildStatusPill(
                bg: tokens.successContainer,
                fg: tokens.onSuccessContainer,
                label: 'Active • Semantic Success',
              ),
              _buildStatusPill(
                bg: tokens.warningContainer,
                fg: tokens.onWarningContainer,
                label: 'Pending • Semantic Warning',
              ),
              _buildStatusPill(
                bg: tokens.dangerContainer,
                fg: tokens.onDangerContainer,
                label: 'Alert • Semantic Danger',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusPill({
    required Color bg,
    required Color fg,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4.5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: fg,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildJoinPreview(ProntoThemeSpec spec, Firm firm) {
    final tokens = spec.tokens;
    final cs = spec.colorScheme;
    final welcome = _stagedWelcomeText?.isNotEmpty == true
        ? _stagedWelcomeText!
        : (firm.welcomeText?.isNotEmpty == true
            ? firm.welcomeText!
            : 'Welcome to ${firm.name}');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          PcLogo(
            logo: _stagedLogo,
            legacyUrl: _stagedLogoUrl,
            size: 60,
            borderRadius: 14,
            variant: MediaVariant.logoSm,
            firmName: firm.name,
            primaryColor: cs.primary,
          ),
          const SizedBox(height: 14),
          Text(
            firm.name,
            style: TextStyle(
              color: tokens.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            welcome,
            textAlign: TextAlign.center,
            style: TextStyle(color: tokens.textSecondary, fontSize: 12),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 22),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: tokens.cardBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: tokens.cardBorder),
            ),
            child: Row(
              children: [
                Icon(Icons.key_rounded, size: 15, color: tokens.textMuted),
                const SizedBox(width: 8),
                Text(
                  'Enter 6-digit staff code',
                  style: TextStyle(color: tokens.textMuted, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 11),
            decoration: BoxDecoration(
              color: cs.primary,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(
                'Join Workspace',
                style: TextStyle(
                  color: cs.onPrimary,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatPreview(ProntoThemeSpec spec, Firm firm) {
    final tokens = spec.tokens;
    final cs = spec.colorScheme;
    final showLastSeen = _stagedShowLastSeen ?? firm.showLastSeen;
    final showReceipts = _stagedShowReadReceipts ?? firm.showReadReceipts;

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: tokens.cardBg,
            border: Border(bottom: BorderSide(color: tokens.cardBorder)),
          ),
          child: Row(
            children: [
              PcLogo(
                logo: _stagedLogo,
                legacyUrl: _stagedLogoUrl,
                size: 26,
                borderRadius: 7,
                variant: MediaVariant.logoSm,
                firmName: firm.name,
                primaryColor: cs.primary,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '#all-staff',
                      style: TextStyle(
                        color: tokens.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 12.5,
                      ),
                    ),
                    if (showLastSeen)
                      Text(
                        'Online • 5 active',
                        style: TextStyle(
                          color: tokens.success,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
              ),
              Icon(Icons.search_rounded, size: 17, color: tokens.textMuted),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: tokens.cardBg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: tokens.cardBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Sarah Lead',
                        style: TextStyle(
                          color: cs.secondary,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Welcome to our newly themed Admin Chat!',
                        style: TextStyle(
                          color: tokens.textPrimary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: cs.primaryContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Harmony roles keep every message readable.',
                        style: TextStyle(
                          color: cs.onPrimaryContainer,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '10:42 AM',
                            style: TextStyle(
                              color:
                                  cs.onPrimaryContainer.withValues(alpha: 0.78),
                              fontSize: 9.5,
                            ),
                          ),
                          if (showReceipts) ...[
                            const SizedBox(width: 4),
                            Icon(
                              Icons.done_all_rounded,
                              size: 12,
                              color: cs.primary,
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // 5. ACTIONS: SAVE, UPLOAD LOGO, COLOR PICKER, DANGER ZONE
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> _pickAndUploadLogo(BuildContext context, Firm firm) async {
    try {
      final result =
          await FilePicker.pickFiles(type: FileType.image, withData: true);
      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      if (file.bytes == null) {
        SnackbarService()
            .showSnackbar('Could not read image bytes.', isError: true);
        return;
      }
      await _uploadLogoBytes(file.bytes!, file.name, firm);
    } catch (e) {
      SnackbarService()
          .showSnackbar('Error selecting image: $e', isError: true);
    }
  }

  Future<void> _uploadLogoBytes(
    Uint8List bytes,
    String fileName,
    Firm firm,
  ) async {
    setState(() => _isUploadingLogo = true);
    SnackbarService().showSnackbar('Uploading brand logo...');

    try {
      final mediaRef = await MediaService.instance.uploadBytes(
        bytes: bytes,
        fileName: fileName,
        purpose: MediaPurpose.logo,
        firmId: firm.firmId,
      );
      final downloadUrl =
          MediaService.instance.urlFor(mediaRef, MediaVariant.logoLg);

      setState(() {
        _stagedLogo = mediaRef;
        _stagedLogoUrl = downloadUrl;
        _isUploadingLogo = false;
      });
      SnackbarService()
          .showSnackbar('Logo uploaded! Click "Save Changes" to apply.');
    } catch (e) {
      setState(() => _isUploadingLogo = false);
      SnackbarService().showSnackbar('Logo upload failed: $e', isError: true);
    }
  }

  void _openColorPickerDialog(
    BuildContext context,
    ThemeData adminTheme,
    ProntoTokens tokens,
    Color initialColor,
  ) {
    Color pickerColor = initialColor;

    showDialog(
      context: context,
      builder: (ctx) => Theme(
        data: adminTheme,
        child: AlertDialog(
          backgroundColor: tokens.cardBg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: tokens.cardBorder),
          ),
          title: Text(
            'Select Brand Accent Color',
            style: TextStyle(
              color: tokens.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          content: SingleChildScrollView(
            child: ColorPicker(
              pickerColor: pickerColor,
              onColorChanged: (c) => pickerColor = c,
              labelTypes: const [],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                'Cancel',
                style: TextStyle(color: tokens.textSecondary),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                ref
                    .read(adminThemeControllerProvider.notifier)
                    .stageAccentColor(pickerColor);
              },
              child: const Text('Preview Color'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveCustomizations(BuildContext context, Firm firm) async {
    setState(() => _isSaving = true);
    final themeState = ref.read(adminThemeControllerProvider);
    final hexString = ProntoPaletteEngine.toHex(
      ProntoPaletteEngine.parseHex(themeState.effectiveAccentHex),
    );
    final selectedTheme = themeState.effectiveThemeId;
    final welcome = _stagedWelcomeText ?? (firm.welcomeText ?? '');

    try {
      final updateData = <String, dynamic>{
        'primaryColor': hexString,
        'themeId': selectedTheme.id,
        'welcomeText': welcome,
        'showLastSeen': _stagedShowLastSeen ?? firm.showLastSeen,
        'showReadReceipts': _stagedShowReadReceipts ?? firm.showReadReceipts,
      };

      if (_stagedLogo != null) {
        updateData['logo'] = _stagedLogo!.toMap();
      }
      if (_stagedLogoUrl != null) {
        updateData['logoUrl'] = _stagedLogoUrl;
      }

      await FirebaseFirestore.instance
          .collection('Firms')
          .doc(firm.firmId)
          .update(updateData);

      ref.read(adminThemeControllerProvider.notifier).markSaved(
            accentHex: hexString,
            themeId: selectedTheme,
          );

      await AuditService.instance.logAction(
        firmId: firm.firmId,
        action: 'update_branding',
        targetType: 'firm',
        targetId: firm.firmId,
        targetLabel:
            'Brand settings updated ($hexString • ${selectedTheme.label})',
      );

      await ref.read(firmNotifierProvider.notifier).loadFirm(firm.firmId);
      SnackbarService().showSnackbar('Branding & theme saved successfully!');
    } catch (e) {
      SnackbarService()
          .showSnackbar('Error saving branding: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // 6. DANGER ZONE (COLLAPSIBLE)
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildDangerZone(
    BuildContext context,
    ThemeData adminTheme,
    ProntoTokens tokens,
    Firm firm,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: tokens.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: tokens.danger.withValues(alpha: 0.45)),
      ),
      child: ExpansionTile(
        shape: const Border(),
        collapsedShape: const Border(),
        iconColor: tokens.danger,
        collapsedIconColor: tokens.danger,
        title: Row(
          children: [
            Icon(
              Icons.warning_amber_rounded,
              color: tokens.danger,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              'Danger Zone: Delete Firm',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: tokens.danger,
                fontSize: 14,
              ),
            ),
          ],
        ),
        childrenPadding: const EdgeInsets.all(18),
        children: [
          Wrap(
            spacing: 16,
            runSpacing: 12,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 680),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Permanently Erase Firm Workspace',
                      style: TextStyle(
                        color: tokens.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'All memberships, department channels, project groups, notices, and data will be permanently removed. This action cannot be undone.',
                      style: TextStyle(
                        color: tokens.textSecondary,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
              ElevatedButton(
                onPressed: () =>
                    _deleteFirm(context, adminTheme, tokens, firm),
                style: ElevatedButton.styleFrom(
                  backgroundColor: tokens.danger,
                  foregroundColor: tokens.onDanger,
                ),
                child: const Text('Delete Firm'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _deleteFirm(
    BuildContext context,
    ThemeData adminTheme,
    ProntoTokens tokens,
    Firm firm,
  ) async {
    final firstConfirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => Theme(
        data: adminTheme,
        child: AlertDialog(
          backgroundColor: tokens.cardBg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: tokens.cardBorder),
          ),
          title: Text(
            'Delete Firm Workspace?',
            style: TextStyle(color: tokens.textPrimary),
          ),
          content: Text(
            'Are you sure you want to delete this firm? All staff memberships and data will be permanently erased. This is irreversible.',
            style: TextStyle(color: tokens.textSecondary, fontSize: 13),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(
                'Cancel',
                style: TextStyle(color: tokens.textSecondary),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: TextButton.styleFrom(foregroundColor: tokens.danger),
              child: const Text('Confirm Delete'),
            ),
          ],
        ),
      ),
    );

    if (firstConfirm != true) return;

    final nameController = TextEditingController();
    if (!context.mounted) return;

    final doubleConfirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => Theme(
        data: adminTheme,
        child: AlertDialog(
          backgroundColor: tokens.cardBg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: tokens.cardBorder),
          ),
          title: Text(
            'Double Confirmation Required',
            style: TextStyle(color: tokens.textPrimary),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'To confirm deletion, please type the exact firm name:',
                style: TextStyle(color: tokens.textSecondary),
              ),
              const SizedBox(height: 8),
              Text(
                firm.name,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: tokens.danger,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: nameController,
                style: TextStyle(color: tokens.textPrimary),
                decoration: const InputDecoration(
                  hintText: 'Enter firm name',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(
                'Cancel',
                style: TextStyle(color: tokens.textSecondary),
              ),
            ),
            TextButton(
              onPressed: () {
                if (nameController.text.trim() == firm.name) {
                  Navigator.pop(ctx, true);
                } else {
                  SnackbarService().showSnackbar(
                    'Firm name does not match!',
                    isError: true,
                  );
                }
              },
              style: TextButton.styleFrom(foregroundColor: tokens.danger),
              child: const Text('DELETE PERMANENTLY'),
            ),
          ],
        ),
      ),
    );

    if (doubleConfirm == true) {
      try {
        await FirebaseFirestore.instance
            .collection('Firms')
            .doc(firm.firmId)
            .delete();
        ChatService.instance.cancelAllSubscriptions();
        await FirebaseAuth.instance.signOut();
        if (mounted && context.mounted) context.go('/register-firm');
      } catch (e) {
        SnackbarService()
            .showSnackbar('Error deleting firm: $e', isError: true);
      }
    }
  }
}
