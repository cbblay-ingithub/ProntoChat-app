import 'package:flutter/material.dart';
import '../../services/notices_service.dart';
import '../../models/notice_model.dart';
import '../../theme/pc_tokens.dart';

/// Interactive reaction bar supporting exactly 5 specified emojis:
/// 👍, ✅, ❤️, 🎉, 👀.
/// Displays live reaction counts aggregated via Firestore count() queries.
/// Tapping an emoji toggles it or switches the caller's reaction.
class NoticeReactionsWidget extends StatefulWidget {
  final String firmId;
  final String noticeId;
  final String currentUid;
  final Color primaryColor;

  const NoticeReactionsWidget({
    super.key,
    required this.firmId,
    required this.noticeId,
    required this.currentUid,
    required this.primaryColor,
  });

  @override
  State<NoticeReactionsWidget> createState() => _NoticeReactionsWidgetState();
}

class _NoticeReactionsWidgetState extends State<NoticeReactionsWidget> {
  Map<String, int> _counts = {
    '👍': 0,
    '✅': 0,
    '❤️': 0,
    '🎉': 0,
    '👀': 0,
  };
  String? _userEmoji;
  bool _isLoadingCounts = true;
  bool _isToggling = false;

  @override
  void initState() {
    super.initState();
    _loadCounts();
  }

  Future<void> _loadCounts() async {
    try {
      final counts = await NoticesService.instance.getReactionCounts(
        widget.firmId,
        widget.noticeId,
      );
      if (mounted) {
        setState(() {
          _counts = counts;
          _isLoadingCounts = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingCounts = false);
      }
    }
  }

  Future<void> _handleEmojiTap(String emoji) async {
    if (_isToggling) return;
    setState(() => _isToggling = true);

    final previousEmoji = _userEmoji;
    final isRemoving = previousEmoji == emoji;

    // Optimistic UI update
    setState(() {
      if (isRemoving) {
        _userEmoji = null;
        _counts[emoji] = (_counts[emoji] ?? 1) - 1;
        if (_counts[emoji]! < 0) _counts[emoji] = 0;
      } else {
        if (previousEmoji != null) {
          _counts[previousEmoji] = (_counts[previousEmoji] ?? 1) - 1;
          if (_counts[previousEmoji]! < 0) _counts[previousEmoji] = 0;
        }
        _userEmoji = emoji;
        _counts[emoji] = (_counts[emoji] ?? 0) + 1;
      }
    });

    try {
      await NoticesService.instance.toggleReaction(
        firmId: widget.firmId,
        noticeId: widget.noticeId,
        uid: widget.currentUid,
        emoji: emoji,
        currentEmoji: previousEmoji,
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _userEmoji = previousEmoji;
        });
        _loadCounts();
      }
    } finally {
      if (mounted) {
        setState(() => _isToggling = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.pcTokens;
    final accent = PcTokens.readableAccentOnLight(widget.primaryColor);

    return StreamBuilder<NoticeReaction?>(
      stream: NoticesService.instance.streamUserReaction(
        widget.firmId,
        widget.noticeId,
        widget.currentUid,
      ),
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data != null) {
          _userEmoji = snapshot.data!.emoji;
        } else if (snapshot.connectionState == ConnectionState.active &&
            snapshot.data == null) {
          _userEmoji = null;
        }

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: tokens.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: tokens.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Reactions',
                    style: TextStyle(
                      color: tokens.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (_isLoadingCounts)
                    SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.5,
                        color: tokens.textMuted,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: NoticesService.allowedEmojis.map((emoji) {
                  final isSelected = _userEmoji == emoji;
                  final count = _counts[emoji] ?? 0;

                  return InkWell(
                    onTap: () => _handleEmojiTap(emoji),
                    borderRadius: BorderRadius.circular(20),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? accent.withValues(alpha: 0.12)
                            : tokens.surfaceSubtle,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected
                              ? accent.withValues(alpha: 0.45)
                              : tokens.border,
                          width: isSelected ? 1.4 : 1.0,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            emoji,
                            style: const TextStyle(fontSize: 18),
                          ),
                          if (count > 0) ...[
                            const SizedBox(width: 6),
                            Text(
                              '$count',
                              style: TextStyle(
                                color:
                                    isSelected ? accent : tokens.textSecondary,
                                fontSize: 13,
                                fontWeight: isSelected
                                    ? FontWeight.w700
                                    : FontWeight.w600,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        );
      },
    );
  }
}
