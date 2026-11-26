import 'admin_theme_storage_stub.dart'
    if (dart.library.js_interop) 'admin_theme_storage_web.dart';

/// Synchronous local preference cache for Admin Web theme state.
/// Uses `window.localStorage` on Web (zero extra packages, instant Frame-1 read)
/// and an in-memory map during VM unit/widget tests.
class AdminThemeStorage {
  const AdminThemeStorage._();

  static const String _accentKey = 'pronto_admin_accent_hex';
  static const String _themeIdKey = 'pronto_admin_theme_id';
  static const String _darkModePrefix = 'pronto_admin_dark_mode_';

  static String? readCachedAccentHex() => AdminThemeStorageImpl.read(_accentKey);

  static void writeCachedAccentHex(String hex) =>
      AdminThemeStorageImpl.write(_accentKey, hex);

  static String? readCachedThemeId() => AdminThemeStorageImpl.read(_themeIdKey);

  static void writeCachedThemeId(String themeId) =>
      AdminThemeStorageImpl.write(_themeIdKey, themeId);

  static bool readDarkMode({String? adminUid}) {
    final scopedKey = '$_darkModePrefix${adminUid ?? "default"}';
    final raw = AdminThemeStorageImpl.read(scopedKey) ??
        AdminThemeStorageImpl.read('${_darkModePrefix}default');
    return raw == 'true';
  }

  static void writeDarkMode(bool isDark, {String? adminUid}) {
    final scopedKey = '$_darkModePrefix${adminUid ?? "default"}';
    AdminThemeStorageImpl.write(scopedKey, isDark ? 'true' : 'false');
    AdminThemeStorageImpl.write(
      '${_darkModePrefix}default',
      isDark ? 'true' : 'false',
    );
  }
}
