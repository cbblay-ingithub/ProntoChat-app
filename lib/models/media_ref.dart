/// Represents a lightweight media reference stored in Firestore.
/// Firestore stores only this structured reference, while the actual binary
/// asset is stored in and served directly from Cloudinary.
class MediaRef {
  /// Cloud media provider (currently always 'cloudinary')
  final String provider;

  /// Public identifier in Cloudinary (e.g. 'prontochat/avatars/xyz' or 'main-sample')
  final String key;

  /// Media kind (currently always 'image')
  final String kind;

  /// Image width in pixels
  final int w;

  /// Image height in pixels
  final int h;

  /// Image file size in bytes
  final int bytes;

  /// File format extension (e.g. 'webp', 'png', 'jpg')
  final String format;

  const MediaRef({
    this.provider = 'cloudinary',
    required this.key,
    this.kind = 'image',
    required this.w,
    required this.h,
    required this.bytes,
    required this.format,
  });

  /// Factory to parse Firestore Map into MediaRef
  factory MediaRef.fromMap(Map<String, dynamic> map) {
    return MediaRef(
      provider: map['provider'] as String? ?? 'cloudinary',
      key: map['key'] as String? ?? '',
      kind: map['kind'] as String? ?? 'image',
      w: (map['w'] as num?)?.toInt() ?? 0,
      h: (map['h'] as num?)?.toInt() ?? 0,
      bytes: (map['bytes'] as num?)?.toInt() ?? 0,
      format: map['format'] as String? ?? 'webp',
    );
  }

  /// Converts MediaRef into Firestore-compatible Map
  Map<String, dynamic> toMap() {
    return {
      'provider': provider,
      'key': key,
      'kind': kind,
      'w': w,
      'h': h,
      'bytes': bytes,
      'format': format,
    };
  }

  /// Clamped aspect ratio (width / height) between 1:3 (0.33) and 3:1 (3.0)
  /// Prevents extreme layout shifts in chat message bubbles.
  double get aspectRatio {
    if (w <= 0 || h <= 0) return 1.0;
    final ratio = w / h;
    return ratio.clamp(0.33, 3.0);
  }

  @override
  String toString() => 'MediaRef(key: $key, w: $w, h: $h, bytes: $bytes, format: $format)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MediaRef &&
          runtimeType == other.runtimeType &&
          key == other.key &&
          provider == other.provider &&
          w == other.w &&
          h == other.h &&
          bytes == other.bytes &&
          format == other.format;

  @override
  int get hashCode =>
      provider.hashCode ^
      key.hashCode ^
      w.hashCode ^
      h.hashCode ^
      bytes.hashCode ^
      format.hashCode;
}

/// Purpose of the media upload, dictating upload preset and validation rules.
enum MediaPurpose {
  avatar,
  logo,
  chat,
}

/// Named transformations defined in Cloudinary.
/// Strict Transformations is ON, so ONLY these named transformations are allowed.
enum MediaVariant {
  avatarSm, // avatar_sm: 64px fill with face detection
  avatarLg, // avatar_lg: 256px fill with face detection
  logoSm,   // logo_sm: 128px fit
  logoLg,   // logo_lg: 512px fit
  chatThumb, // chat_thumb: 480px limit
  chatFull,  // chat_full: 1280px limit
}

extension MediaVariantExtension on MediaVariant {
  String get transformationName {
    switch (this) {
      case MediaVariant.avatarSm:
        return 'avatar_sm';
      case MediaVariant.avatarLg:
        return 'avatar_lg';
      case MediaVariant.logoSm:
        return 'logo_sm';
      case MediaVariant.logoLg:
        return 'logo_lg';
      case MediaVariant.chatThumb:
        return 'chat_thumb';
      case MediaVariant.chatFull:
        return 'chat_full';
    }
  }
}
