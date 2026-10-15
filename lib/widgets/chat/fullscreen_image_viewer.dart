import 'package:flutter/material.dart';
import '../../models/media_ref.dart';
import '../../services/media_service.dart';

/// Full-screen image viewer with pinch-to-zoom (InteractiveViewer)
/// Loads the high-resolution `chat_full` variant.
class FullscreenImageViewer extends StatelessWidget {
  final MediaRef media;
  final String? caption;
  final String senderName;
  final DateTime? timestamp;

  const FullscreenImageViewer({
    super.key,
    required this.media,
    this.caption,
    this.senderName = '',
    this.timestamp,
  });

  static void open({
    required BuildContext context,
    required MediaRef media,
    String? caption,
    String senderName = '',
    DateTime? timestamp,
  }) {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black.withOpacity(0.95),
        pageBuilder: (context, _, __) => FullscreenImageViewer(
          media: media,
          caption: caption,
          senderName: senderName,
          timestamp: timestamp,
        ),
        transitionsBuilder: (context, animation, _, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  String _formatTime(DateTime? dt) {
    if (dt == null) return '';
    final local = dt.toLocal();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    final fullUrl = MediaService.instance.urlFor(media, MediaVariant.chatFull);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Pinch-to-zoom interactive viewer
          Center(
            child: InteractiveViewer(
              minScale: 0.8,
              maxScale: 4.0,
              child: Image.network(
                fullUrl,
                fit: BoxFit.contain,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Center(
                    child: CircularProgressIndicator(
                      value: loadingProgress.expectedTotalBytes != null
                          ? loadingProgress.cumulativeBytesLoaded /
                              loadingProgress.expectedTotalBytes!
                          : null,
                      color: Colors.white70,
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  return const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.broken_image_rounded, color: Colors.grey, size: 54),
                        SizedBox(height: 12),
                        Text(
                          'Unable to load high-resolution image.',
                          style: TextStyle(color: Colors.white70, fontSize: 14),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),

          // Top Header Bar
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 8,
                left: 12,
                right: 12,
                bottom: 12,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.8),
                    Colors.transparent,
                  ],
                ),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (senderName.isNotEmpty)
                          Text(
                            senderName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        if (timestamp != null)
                          Text(
                            _formatTime(timestamp),
                            style: TextStyle(
                              color: Colors.grey[400],
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Bottom Caption Bar (if present)
          if (caption != null && caption!.trim().isNotEmpty)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).padding.bottom + 16,
                  left: 20,
                  right: 20,
                  top: 16,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withOpacity(0.85),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Text(
                  caption!,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    height: 1.3,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
