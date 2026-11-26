// ignore: depend_on_referenced_packages
import 'package:web/web.dart' as web;

/// Browser localStorage implementation for synchronous first-frame theme hydration on Web.
class AdminThemeStorageImpl {
  static String? read(String key) {
    try {
      return web.window.localStorage.getItem(key);
    } catch (_) {
      return null;
    }
  }

  static void write(String key, String value) {
    try {
      web.window.localStorage.setItem(key, value);
    } catch (_) {}
  }

  static void remove(String key) {
    try {
      web.window.localStorage.removeItem(key);
    } catch (_) {}
  }
}
