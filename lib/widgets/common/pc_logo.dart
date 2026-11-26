import 'package:flutter/material.dart';
import '../../models/media_ref.dart';
import '../../services/media_service.dart';
import '../../theme/pc_tokens.dart';
import '../../theme/pronto_tokens.dart';
export '../../models/media_ref.dart' show MediaRef, MediaVariant;

/// Reusable logo widget for ProntoChat firms.
/// Dual-read support: checks new [logo] (MediaRef) first,
/// falls back to [legacyUrl] (full URL), and finally generates
/// clean firm icon/initials on failure or absence.
///
/// Token-driven: when rendered inside Admin Web (`maybeProntoTokens != null`),
/// uses the active theme's `ColorScheme.primary` (which adapts across Light & Dark
/// harmony themes). On Mobile (`maybeProntoTokens == null`), falls back identically
/// to its existing `PcTokens` appearance.
class PcLogo extends StatelessWidget {
  final MediaRef? logo;
  final String? legacyUrl;
  final String firmName;
  final double? size;
  final double? width;
  final double? height;
  final double borderRadius;
  final MediaVariant variant;
  final BoxFit fit;
  final Color? fallbackColor;
  final Color? primaryColor;
  final VoidCallback? onTap;

  const PcLogo({
    super.key,
    this.logo,
    this.legacyUrl,
    this.firmName = '',
    this.size,
    this.width,
    this.height,
    this.borderRadius = 8,
    this.variant = MediaVariant.logoSm,
    this.fit = BoxFit.contain,
    this.fallbackColor,
    this.primaryColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveWidth = width ?? size ?? 48;
    final effectiveHeight = height ?? size ?? 48;
    final adminTokens = context.maybeProntoTokens;

    final Color brandColor;
    if (adminTokens != null) {
      brandColor =
          primaryColor ?? fallbackColor ?? Theme.of(context).colorScheme.primary;
    } else {
      final rawBrand =
          primaryColor ?? fallbackColor ?? PcTokens.defaultBrandBlue;
      brandColor = PcTokens.readableAccentOnLight(rawBrand);
    }

    final resolvedUrl = MediaService.instance.resolveUrl(
      mediaRef: logo,
      legacyUrl: legacyUrl,
      variant: variant,
    );

    final fallbackWidget = Container(
      width: effectiveWidth,
      height: effectiveHeight,
      decoration: BoxDecoration(
        color: brandColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: brandColor.withValues(alpha: 0.28),
          width: 1,
        ),
      ),
      child: Center(
        child: firmName.trim().isNotEmpty
            ? Text(
                firmName.trim()[0].toUpperCase(),
                style: TextStyle(
                  color: brandColor,
                  fontWeight: FontWeight.w800,
                  fontSize: effectiveHeight * 0.45,
                ),
              )
            : Icon(
                Icons.business_rounded,
                color: brandColor,
                size: effectiveHeight * 0.5,
              ),
      ),
    );

    Widget content;

    if (resolvedUrl != null && resolvedUrl.isNotEmpty) {
      content = SizedBox(
        width: effectiveWidth,
        height: effectiveHeight,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(borderRadius),
          child: Image.network(
            resolvedUrl,
            width: effectiveWidth,
            height: effectiveHeight,
            fit: fit,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return Container(
                width: effectiveWidth,
                height: effectiveHeight,
                color: brandColor.withValues(alpha: 0.08),
                child: Center(
                  child: SizedBox(
                    width: effectiveWidth * 0.4,
                    height: effectiveHeight * 0.4,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      value: loadingProgress.expectedTotalBytes != null
                          ? loadingProgress.cumulativeBytesLoaded /
                              loadingProgress.expectedTotalBytes!
                          : null,
                      color: brandColor.withValues(alpha: 0.75),
                    ),
                  ),
                ),
              );
            },
            errorBuilder: (context, error, stackTrace) => fallbackWidget,
          ),
        ),
      );
    } else {
      content = fallbackWidget;
    }

    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        child: content,
      );
    }

    return content;
  }
}
