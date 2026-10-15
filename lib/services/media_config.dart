/// Configuration for Cloudinary media uploads and transformations.
/// Values can be configured via --dart-define or fallback to project defaults.
/// NOTE: Strictly UNSIGNED uploads only. No API key or secret is stored.
class MediaConfig {
  static const String defaultCloudName = 'dj4miyael';
  static const String defaultPresetAvatar = 'pc_avatar';
  static const String defaultPresetLogo = 'pc_logo';
  static const String defaultPresetChat = 'pc_chat';

  /// Cloudinary cloud name
  static const String cloudName = String.fromEnvironment(
    'CLOUDINARY_CLOUD_NAME',
    defaultValue: defaultCloudName,
  );

  /// Unsigned preset for user profile photos
  static const String presetAvatar = String.fromEnvironment(
    'CLOUDINARY_PRESET_AVATAR',
    defaultValue: defaultPresetAvatar,
  );

  /// Unsigned preset for firm logos
  static const String presetLogo = String.fromEnvironment(
    'CLOUDINARY_PRESET_LOGO',
    defaultValue: defaultPresetLogo,
  );

  /// Unsigned preset for chat images
  static const String presetChat = String.fromEnvironment(
    'CLOUDINARY_PRESET_CHAT',
    defaultValue: defaultPresetChat,
  );

  /// Maximum upload file size in bytes (10 Megabytes)
  static const int kMaxUploadBytes = 10 * 1024 * 1024; // 10,485,760 bytes
}
