import 'package:flutter/material.dart';
import '../../models/media_ref.dart';
import '../../services/media_service.dart';
export '../../models/media_ref.dart' show MediaRef, MediaVariant;

/// Reusable avatar widget for ProntoChat.
/// Dual-read support: checks new [avatar] (MediaRef) first,
/// falls back to [legacyUrl] (full URL), and finally generates
/// clean initials on failure or absence.
class PcAvatar extends StatelessWidget {
  final MediaRef? avatar;
  final String? legacyUrl;
  final String name;
  final double radius;
  final MediaVariant variant;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final VoidCallback? onTap;

  const PcAvatar({
    super.key,
    this.avatar,
    this.legacyUrl,
    this.name = '',
    this.radius = 20,
    this.variant = MediaVariant.avatarSm,
    this.backgroundColor,
    this.foregroundColor,
    this.onTap,
  });

  String get _initials {
    final clean = name.trim();
    if (clean.isEmpty) return '?';
    final parts = clean.split(RegExp(r'\s+'));
    if (parts.length >= 2 && parts[0].isNotEmpty && parts[1].isNotEmpty) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return clean[0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final resolvedUrl = MediaService.instance.resolveUrl(
      mediaRef: avatar,
      legacyUrl: legacyUrl,
      variant: variant,
    );

    final bg = backgroundColor ?? const Color(0xFF295CB4).withOpacity(0.25);
    final fg = foregroundColor ?? const Color(0xFF64B5F6);

    Widget avatarWidget;

    if (resolvedUrl != null && resolvedUrl.isNotEmpty) {
      avatarWidget = CircleAvatar(
        radius: radius,
        backgroundColor: bg,
        child: ClipOval(
          child: Image.network(
            resolvedUrl,
            width: radius * 2,
            height: radius * 2,
            fit: BoxFit.cover,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return Container(
                width: radius * 2,
                height: radius * 2,
                color: bg,
                child: Center(
                  child: SizedBox(
                    width: radius * 0.8,
                    height: radius * 0.8,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      value: loadingProgress.expectedTotalBytes != null
                          ? loadingProgress.cumulativeBytesLoaded /
                              loadingProgress.expectedTotalBytes!
                          : null,
                      color: fg.withOpacity(0.7),
                    ),
                  ),
                ),
              );
            },
            errorBuilder: (context, error, stackTrace) {
              return Container(
                width: radius * 2,
                height: radius * 2,
                color: bg,
                child: Center(
                  child: Text(
                    _initials,
                    style: TextStyle(
                      color: fg,
                      fontWeight: FontWeight.bold,
                      fontSize: radius * 0.85,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      );
    } else {
      avatarWidget = CircleAvatar(
        radius: radius,
        backgroundColor: bg,
        child: Text(
          _initials,
          style: TextStyle(
            color: fg,
            fontWeight: FontWeight.bold,
            fontSize: radius * 0.85,
          ),
        ),
      );
    }

    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        child: avatarWidget,
      );
    }

    return avatarWidget;
  }
}
