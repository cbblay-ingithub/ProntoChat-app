import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/firm.dart';
import '../providers/firm/providers.dart';
import 'admin_theme_storage.dart';
import 'pronto_palette_engine.dart';
import 'pronto_tokens.dart';

/// Holds live-preview overrides (accent + themeId) and per-admin on-device Light/Dark mode.
@immutable
class AdminThemeControllerState {
  /// Cached or persisted firm accent (`#RRGGBB`) from local storage / Firestore.
  final String persistedAccentHex;

  /// Cached or persisted firm harmony theme id.
  final ProntoThemeId persistedThemeId;

  /// Optional live-staged accent chosen in Customization before clicking Save.
  final String? stagedAccentHex;

  /// Optional live-staged themeId chosen in Customization before clicking Save.
  final ProntoThemeId? stagedThemeId;

  /// Per-admin on-device Light/Dark mode preference.
  final bool isDarkMode;

  const AdminThemeControllerState({
    required this.persistedAccentHex,
    required this.persistedThemeId,
    this.stagedAccentHex,
    this.stagedThemeId,
    required this.isDarkMode,
  });

  String get effectiveAccentHex => stagedAccentHex ?? persistedAccentHex;
  ProntoThemeId get effectiveThemeId => stagedThemeId ?? persistedThemeId;

  bool get hasStagedBrandingChanges =>
      (stagedAccentHex != null &&
          stagedAccentHex!.toUpperCase() != persistedAccentHex.toUpperCase()) ||
      (stagedThemeId != null && stagedThemeId != persistedThemeId);

  AdminThemeControllerState copyWith({
    String? persistedAccentHex,
    ProntoThemeId? persistedThemeId,
    String? stagedAccentHex,
    bool clearStagedAccent = false,
    ProntoThemeId? stagedThemeId,
    bool clearStagedTheme = false,
    bool? isDarkMode,
  }) {
    return AdminThemeControllerState(
      persistedAccentHex: persistedAccentHex ?? this.persistedAccentHex,
      persistedThemeId: persistedThemeId ?? this.persistedThemeId,
      stagedAccentHex:
          clearStagedAccent ? null : (stagedAccentHex ?? this.stagedAccentHex),
      stagedThemeId:
          clearStagedTheme ? null : (stagedThemeId ?? this.stagedThemeId),
      isDarkMode: isDarkMode ?? this.isDarkMode,
    );
  }
}

class AdminThemeController extends StateNotifier<AdminThemeControllerState> {
  AdminThemeController({String? adminUid})
      : _adminUid = adminUid,
        super(
          AdminThemeControllerState(
            persistedAccentHex: AdminThemeStorage.readCachedAccentHex() ??
                ProntoPaletteEngine.defaultAccentHex,
            persistedThemeId: ProntoThemeId.fromId(
              AdminThemeStorage.readCachedThemeId(),
            ),
            isDarkMode: AdminThemeStorage.readDarkMode(adminUid: adminUid),
          ),
        );

  String? _adminUid;

  /// Synchronizes with the active [Firm] emitted by the existing firm stream
  /// (no extra Firestore listener) and caches values locally for Frame 1 on restart.
  void syncFromFirm(Firm firm, {String? adminUid}) {
    final normalizedHex = ProntoPaletteEngine.toHex(
      ProntoPaletteEngine.parseHex(firm.primaryColor),
    );
    final firmTheme = ProntoThemeId.fromId(firm.themeId);

    AdminThemeStorage.writeCachedAccentHex(normalizedHex);
    AdminThemeStorage.writeCachedThemeId(firmTheme.id);

    bool darkMode = state.isDarkMode;
    if (adminUid != null && adminUid != _adminUid) {
      _adminUid = adminUid;
      darkMode = AdminThemeStorage.readDarkMode(adminUid: adminUid);
    }

    // Clear staged overrides if they now match persisted values.
    final clearAccent = state.stagedAccentHex != null &&
        state.stagedAccentHex!.toUpperCase() == normalizedHex;
    final clearTheme =
        state.stagedThemeId != null && state.stagedThemeId == firmTheme;

    if (state.persistedAccentHex != normalizedHex ||
        state.persistedThemeId != firmTheme ||
        state.isDarkMode != darkMode ||
        clearAccent ||
        clearTheme) {
      state = state.copyWith(
        persistedAccentHex: normalizedHex,
        persistedThemeId: firmTheme,
        clearStagedAccent: clearAccent,
        clearStagedTheme: clearTheme,
        isDarkMode: darkMode,
      );
    }
  }

  /// Live-previews an accent color across the entire Admin Web immediately.
  void stageAccentColor(Color color) {
    final hex = ProntoPaletteEngine.toHex(color);
    state = state.copyWith(stagedAccentHex: hex);
  }

  /// Live-previews one of the 5 harmony themes across the entire Admin Web immediately.
  void stageThemeId(ProntoThemeId themeId) {
    state = state.copyWith(stagedThemeId: themeId);
  }

  /// Toggles Light/Dark mode immediately and persists per-admin on-device.
  void setDarkMode(bool isDark) {
    AdminThemeStorage.writeDarkMode(isDark, adminUid: _adminUid);
    state = state.copyWith(isDarkMode: isDark);
  }

  /// Commits saved branding to the local Frame-1 cache and clears staged flags.
  void markSaved({required String accentHex, required ProntoThemeId themeId}) {
    final normalized = ProntoPaletteEngine.toHex(
      ProntoPaletteEngine.parseHex(accentHex),
    );
    AdminThemeStorage.writeCachedAccentHex(normalized);
    AdminThemeStorage.writeCachedThemeId(themeId.id);
    state = state.copyWith(
      persistedAccentHex: normalized,
      persistedThemeId: themeId,
      clearStagedAccent: true,
      clearStagedTheme: true,
    );
  }

  /// Discards unsaved staged changes, reverting live preview to the firm's saved state.
  void discardStaged() {
    state = state.copyWith(
      clearStagedAccent: true,
      clearStagedTheme: true,
    );
  }

  /// Stages the default ProntoChat accent and theme so the admin can preview & save.
  void stageDefaults() {
    state = state.copyWith(
      stagedAccentHex: ProntoPaletteEngine.defaultAccentHex,
      stagedThemeId: ProntoPaletteEngine.defaultThemeId,
    );
  }
}

/// Controller watched ONLY by Admin Web shell & Customization screen.
final adminThemeControllerProvider =
    StateNotifierProvider<AdminThemeController, AdminThemeControllerState>(
  (ref) {
    String? uid;
    try {
      uid = FirebaseAuth.instance.currentUser?.uid;
    } catch (_) {
      uid = null;
    }
    final controller = AdminThemeController(adminUid: uid);

    final initialFirm = ref.read(currentFirmProvider);
    if (initialFirm != null) {
      controller.syncFromFirm(initialFirm, adminUid: uid);
    }

    // Reuse the existing firm stream state in Riverpod — zero new Firestore listeners.
    ref.listen<Firm?>(currentFirmProvider, (prev, next) {
      if (next != null) {
        String? activeUid;
        try {
          activeUid = FirebaseAuth.instance.currentUser?.uid;
        } catch (_) {}
        controller.syncFromFirm(next, adminUid: activeUid);
      }
    });

    return controller;
  },
);

/// Resolved [ProntoThemeSpec] exposed strictly to Admin Web routes (`AdminShell` + Admin Chat).
final adminThemeSpecProvider = Provider<ProntoThemeSpec>((ref) {
  final state = ref.watch(adminThemeControllerProvider);
  final seedColor = ProntoPaletteEngine.parseHex(state.effectiveAccentHex);
  return ProntoPaletteEngine.build(
    seedColor: seedColor,
    themeId: state.effectiveThemeId,
    brightness: state.isDarkMode ? Brightness.dark : Brightness.light,
  );
});

/// Convenience provider returning the Admin Web [ThemeData].
final adminThemeProvider = Provider<ThemeData>((ref) {
  return ref.watch(adminThemeSpecProvider).themeData;
});
