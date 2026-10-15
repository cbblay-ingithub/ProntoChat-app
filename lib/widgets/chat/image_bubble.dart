import 'package:flutter/material.dart';
import '../../models/chat_message.dart';
import '../../models/media_ref.dart';
import '../../services/media_service.dart';
import 'fullscreen_image_viewer.dart';

/// Bubble widget for rendering chat images.
/// Reserves aspect-ratio space using `media.aspectRatio` to prevent scroll jumps,
/// loads `chat_thumb` variant, and opens `FullscreenImageViewer` on tap.
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

    final thumbUrl = MediaService.instance.urlFor(media, MediaVariant.chatThumb);
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
              color: Colors.black26,
              child: AspectRatio(
                aspectRatio: aspectRatio,
                child: Image.network(
                  thumbUrl,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Container(
                      color: const Color(0xFF1E1E24),
                      child: Center(
                        child: SizedBox(
                          width: 28,
                          height: 28,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            value: loadingProgress.expectedTotalBytes != null
                                ? loadingProgress.cumulativeBytesLoaded /
                                    loadingProgress.expectedTotalBytes!
                                : null,
                            color: Colors.white70,
                          ),
                        ),
                      ),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: const Color(0xFF1E1E24),
                      padding: const EdgeInsets.all(16),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.broken_image_outlined,
                              color: Colors.grey,
                              size: 36,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Failed to load image',
                              style: TextStyle(
                                color: Colors.grey[400],
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

        // Caption text if provided
        if (message.text.trim().isNotEmpty) ...[
          const SizedBox(height: 6),
          if (captionWidget != null)
            captionWidget!
          else
            Text(
              message.text,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                height: 1.3,
              ),
            ),
        ],
      ],
    );
  }
}
