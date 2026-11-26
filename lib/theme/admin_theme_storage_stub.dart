/// In-memory fallback key-value store used in VM unit/widget tests.
class AdminThemeStorageImpl {
  static final Map<String, String> _memory = <String, String>{};

  static String? read(String key) => _memory[key];

  static void write(String key, String value) {
    _memory[key] = value;
  }

  static void remove(String key) {
    _memory.remove(key);
  }
}
