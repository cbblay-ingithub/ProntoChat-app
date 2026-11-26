import 'package:flutter/material.dart';
import '../../models/chat_message.dart';
import '../../models/media_ref.dart';
import '../../services/media_service.dart';
import '../../theme/pc_tokens.dart';
import 'fullscreen_image_viewer.dart';

class ImageBubbleWidget extends StatelessWidget {
  final ChatMessage message;
  final bool isMine;
  final Color primaryColor;
  final Widget? captionWidget;

  const ImageBubbleWidget({
    super.key,
    required this.message,
    required this.isMine,
    required this.primaryColor,
    this.captionWidget,
  });

  @override
  Widget build(BuildContext context) {
    final media = message.media;
    if (media == null) {
      return const SizedBox.shrink();
    }

    final tokens = context.pcTokens;
    final thumbUrl =
        MediaService.instance.urlFor(media, MediaVariant.chatThumb);
    final aspectRatio = media.aspectRatio;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: () {
            FullscreenImageViewer.open(
              context: context,
              media: media,
              caption: message.text.isNotEmpty ? message.text : null,
              senderName: message.senderName,
              timestamp: message.timestamp,
            );
          },
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              constraints: const BoxConstraints(
                maxHeight: 340,
                maxWidth: 280,
                minWidth: 140,
              ),
              color: tokens.surfaceSubtle,
              child: AspectRatio(
                aspectRatio: aspectRatio,
                child: Image.network(
                  thumbUrl,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Container(
                      color: tokens.surfaceSubtle,
                      child: Center(
                        child: SizedBox(
                          width: 26,
                          height: 26,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            value: loadingProgress.expectedTotalBytes != null
                                ? loadingProgress.cumulativeBytesLoaded /
                                    loadingProgress.expectedTotalBytes!
                                : null,
                            color: primaryColor,
                          ),
                        ),
                      ),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: tokens.surfaceSubtle,
                      padding: const EdgeInsets.all(16),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.broken_image_outlined,
                              color: tokens.textMuted,
                              size: 34,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Failed to load image',
                              style: TextStyle(
                                color: tokens.textMuted,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
        if (message.text.trim().isNotEmpty) ...[
          const SizedBox(height: 6),
          if (captionWidget != null)
            captionWidget!
          else
            Text(
              message.text,
              style: TextStyle(
                color: isMine
                    ? PcTokens.contrastOn(primaryColor)
                    : tokens.textPrimary,
                fontSize: 14,
                height: 1.3,
              ),
            ),
        ],
      ],
    );
  }
}
