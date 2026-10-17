import 'package:flutter/material.dart';
import '../../models/notice_model.dart';
import '../../models/media_ref.dart';
import '../../services/media_service.dart';
import '../common/pc_avatar.dart';

/// Feed card for displaying a notice preview on the Home tab.
class NoticeCard extends StatelessWidget {
  final NoticeModel notice;
  final DateTime? lastSeenAt;
  final Color primaryColor;
  final VoidCallback onTap;

  const NoticeCard({
    super.key,
    required this.notice,
    this.lastSeenAt,
    required this.primaryColor,
    required this.onTap,
  });

  String _formatRelativeTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final isNew = notice.isNewFor(lastSeenAt);
    final isUrgent = notice.isUrgent;
    final isPolicy = notice.isPolicy;

    final borderColor = isUrgent
        ? Colors.redAccent.withOpacity(0.5)
        : isPolicy
            ? Colors.indigoAccent.withOpacity(0.4)
            : Colors.white.withOpacity(0.07);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: const Color.fromRGBO(34, 33, 33, 1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor, width: isUrgent ? 1.4 : 1.0),
          boxShadow: isUrgent
              ? [
                  BoxShadow(
                    color: Colors.redAccent.withOpacity(0.08),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hero Image (if media present)
            if (notice.media.isNotEmpty)
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
                child: SizedBox(
                  height: 160,
                  width: double.infinity,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.network(
                        MediaService.instance.urlFor(
                          notice.media.first,
                          MediaVariant.noticeCard,
                        ),
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, progress) {
                          if (progress == null) return child;
                          return Container(
                            color: const Color.fromRGBO(24, 24, 24, 1),
                            child: const Center(
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white54),
                            ),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: const Color.fromRGBO(24, 24, 24, 1),
                            child: const Center(
                              child: Icon(Icons.broken_image_outlined, color: Colors.grey, size: 32),
                            ),
                          );
                        },
                      ),
                      if (notice.media.length > 1)
                        Positioned(
                          top: 10,
                          right: 10,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.65),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.photo_library_outlined, color: Colors.white, size: 12),
                                const SizedBox(width: 4),
                                Text(
                                  '+${notice.media.length - 1}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),

            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Badges Row: Type Badge, Pinned, Audience Chip, New Marker
                  Row(
                    children: [
                      if (isUrgent)
                        Container(
                          margin: const EdgeInsets.only(right: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.redAccent.withOpacity(0.18),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.redAccent.withOpacity(0.5)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 12),
                              SizedBox(width: 4),
                              Text(
                                'URGENT',
                                style: TextStyle(
                                  color: Colors.redAccent,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        )
                      else if (isPolicy)
                        Container(
                          margin: const EdgeInsets.only(right: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.indigoAccent.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.indigoAccent.withOpacity(0.4)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.gavel, color: Colors.indigoAccent, size: 12),
                              SizedBox(width: 4),
                              Text(
                                'POLICY',
                                style: TextStyle(
                                  color: Colors.indigoAccent,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),

                      if (notice.pinned)
                        Container(
                          margin: const EdgeInsets.only(right: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.amber.withOpacity(0.18),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.push_pin, color: Colors.amberAccent, size: 11),
                              SizedBox(width: 3),
                              Text(
                                'PINNED',
                                style: TextStyle(
                                  color: Colors.amberAccent,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),

                      // Audience chip
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          notice.audienceSummary,
                          style: TextStyle(
                            color: Colors.grey[300],
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),

                      const Spacer(),

                      // Relative Time
                      Text(
                        _formatRelativeTime(notice.createdAt),
                        style: TextStyle(color: Colors.grey[500], fontSize: 11),
                      ),

                      // New indicator dot
                      if (isNew) ...[
                        const SizedBox(width: 6),
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: primaryColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ],
                  ),

                  const SizedBox(height: 10),

                  // Notice Title
                  Text(
                    notice.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      height: 1.25,
                    ),
                  ),

                  const SizedBox(height: 5),

                  // Body snippet
                  Text(
                    notice.body,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 13,
                      height: 1.35,
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Author Row & Details
                  Row(
                    children: [
                      PcAvatar(
                        name: notice.authorName,
                        radius: 12,
                        backgroundColor: primaryColor.withOpacity(0.2),
                        foregroundColor: primaryColor,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          notice.authorLabel.isNotEmpty
                              ? '${notice.authorName} • ${notice.authorLabel}'
                              : notice.authorName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.grey[300],
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      if (notice.isEdited)
                        Container(
                          margin: const EdgeInsets.only(left: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.06),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Edited',
                            style: TextStyle(color: Colors.grey[500], fontSize: 9),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
