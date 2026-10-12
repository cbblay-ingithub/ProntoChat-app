import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import '../../models/chat_message.dart';
import '../../models/chat_polish_models.dart';

class MessageBubbleWidget extends StatelessWidget {
  final ChatMessage message;
  final bool isMine;
  final bool isDirectChat;
  final bool showReadReceipts;
  final ReadPointer? otherReadPointer;
  final Map<String, ReadPointer>? groupReadPointers;
  final bool isConsecutive;
  final Color primaryColor;
  final bool canPin;
  final bool isPinned;
  final ValueChanged<ChatMessage> onReply;
  final void Function(ChatMessage message, Duration duration) onPin;
  final ValueChanged<ChatMessage>? onUnpin;
  final ValueChanged<ChatMessage> onEdit;
  final ValueChanged<ChatMessage> onDelete;
  final ValueChanged<ChatMessage>? onRetry;
  final ValueChanged<String> onJumpToQuoted;

  const MessageBubbleWidget({
    super.key,
    required this.message,
    required this.isMine,
    required this.isDirectChat,
    required this.showReadReceipts,
    this.otherReadPointer,
    this.groupReadPointers,
    required this.isConsecutive,
    required this.primaryColor,
    required this.canPin,
    this.isPinned = false,
    required this.onReply,
    required this.onPin,
    this.onUnpin,
    required this.onEdit,
    required this.onDelete,
    this.onRetry,
    required this.onJumpToQuoted,
  });

  String _formatTime(DateTime dt) {
    final local = dt.toLocal();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  void _showPinDurationDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color.fromRGBO(34, 33, 33, 1),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    Icon(Icons.push_pin, color: Colors.amberAccent, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Choose Pin Duration',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(left: 16, right: 16, bottom: 8),
                child: Text(
                  'Messages cannot be pinned indefinitely. Newly pinned messages take precedence.',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ),
              const Divider(color: Colors.white12, height: 1),
              ListTile(
                leading: const Icon(Icons.timer_outlined, color: Colors.lightBlueAccent),
                title: const Text('3 Hours', style: TextStyle(color: Colors.white)),
                subtitle: const Text('Keep pinned for a few hours', style: TextStyle(color: Colors.grey, fontSize: 11)),
                onTap: () {
                  Navigator.pop(ctx);
                  onPin(message, const Duration(hours: 3));
                },
              ),
              ListTile(
                leading: const Icon(Icons.today, color: Colors.amberAccent),
                title: const Text('24 Hours (1 Day)', style: TextStyle(color: Colors.white)),
                subtitle: const Text('Keep pinned until tomorrow', style: TextStyle(color: Colors.grey, fontSize: 11)),
                onTap: () {
                  Navigator.pop(ctx);
                  onPin(message, const Duration(hours: 24));
                },
              ),
              ListTile(
                leading: const Icon(Icons.date_range, color: Colors.purpleAccent),
                title: const Text('7 Days (1 Week)', style: TextStyle(color: Colors.white)),
                subtitle: const Text('Keep pinned for the entire week', style: TextStyle(color: Colors.grey, fontSize: 11)),
                onTap: () {
                  Navigator.pop(ctx);
                  onPin(message, const Duration(days: 7));
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showMessageActions(BuildContext context) {
    if (message.deleted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color.fromRGBO(34, 33, 33, 1),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.reply, color: Colors.blueAccent),
              title: const Text('Reply', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(ctx);
                onReply(message);
              },
            ),
            if (isPinned && canPin)
              ListTile(
                leading: const Icon(Icons.push_pin, color: Colors.amberAccent),
                title: const Text('Unpin Message', style: TextStyle(color: Colors.white)),
                subtitle: const Text('Remove from pinned messages banner', style: TextStyle(color: Colors.grey, fontSize: 11)),
                onTap: () {
                  Navigator.pop(ctx);
                  onUnpin?.call(message);
                },
              )
            else if (canPin)
              ListTile(
                leading: const Icon(Icons.push_pin_outlined, color: Colors.amberAccent),
                title: const Text('Pin Message', style: TextStyle(color: Colors.white)),
                subtitle: const Text('Select a duration (hours, day, or week)', style: TextStyle(color: Colors.grey, fontSize: 11)),
                onTap: () {
                  Navigator.pop(ctx);
                  _showPinDurationDialog(context);
                },
              ),
            if (isMine && !message.deleted) ...[
              ListTile(
                leading: const Icon(Icons.edit_outlined, color: Colors.greenAccent),
                title: const Text('Edit Message', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(ctx);
                  onEdit(message);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.redAccent),
                title: const Text('Delete Message', style: TextStyle(color: Colors.redAccent)),
                onTap: () {
                  Navigator.pop(ctx);
                  onDelete(message);
                },
              ),
            ],
            if (message.isFailed && onRetry != null)
              ListTile(
                leading: const Icon(Icons.refresh, color: Colors.orangeAccent),
                title: const Text('Retry Sending', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(ctx);
                  onRetry!(message);
                },
              ),
          ],
        ),
      ),
    );
  }

  void _showSeenBySheet(BuildContext context) {
    if (isDirectChat || groupReadPointers == null) return;

    final seenBy = groupReadPointers!.entries.where((e) {
      return e.key != message.senderId &&
          !e.value.lastReadAt.isBefore(message.timestamp);
    }).toList();

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color.fromRGBO(34, 33, 33, 1),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Seen by ${seenBy.length}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              if (seenBy.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8.0),
                  child: Text(
                    'No participants have viewed this message yet.',
                    style: TextStyle(color: Colors.grey),
                  ),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  itemCount: seenBy.length,
                  itemBuilder: (_, index) {
                    final item = seenBy[index];
                    return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: const CircleAvatar(
                        radius: 14,
                        backgroundColor: Colors.blueAccent,
                        child: Icon(Icons.check, size: 14, color: Colors.white),
                      ),
                      title: Text(item.key, style: const TextStyle(color: Colors.white)),
                      trailing: Text(
                        _formatTime(item.value.lastReadAt),
                        style: const TextStyle(color: Colors.grey, fontSize: 11),
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReadStatusIcon(BuildContext context) {
    if (!isMine) return const SizedBox.shrink();

    if (message.isPending || message.hasPendingWrites) {
      return const Padding(
        padding: EdgeInsets.only(left: 6),
        child: SizedBox(
          width: 9,
          height: 9,
          child: CircularProgressIndicator(strokeWidth: 1.2, color: Colors.white54),
        ),
      );
    }

    if (message.isFailed) {
      return const Padding(
        padding: EdgeInsets.only(left: 4),
        child: Icon(Icons.error_outline_rounded, size: 12, color: Colors.redAccent),
      );
    }

    // Direct Chat Receipts
    if (isDirectChat) {
      if (!showReadReceipts || otherReadPointer == null) {
        // Single Crystal: Sent
        return const Padding(
          padding: EdgeInsets.only(left: 6),
          child: _NeonCrystal(
            isFilled: true,
            isGlow: false,
            color: Colors.white54,
            size: 6.5,
          ),
        );
      }

      // Check if other user's pointer is at or past this message's timestamp
      final isSeen = !otherReadPointer!.lastReadAt.isBefore(message.timestamp);

      // Twin Crystals: Delivered (silver) vs Read (glowing electric-cyan neon crystals)
      return Padding(
        padding: const EdgeInsets.only(left: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _NeonCrystal(
              isFilled: true,
              isGlow: isSeen,
              color: isSeen ? const Color(0xFF00E5FF) : Colors.white60,
              glowColor: isSeen ? const Color(0xFF00E5FF) : null,
              size: 6.5,
            ),
            const SizedBox(width: 3.5),
            _NeonCrystal(
              isFilled: isSeen,
              isGlow: isSeen,
              color: isSeen ? const Color(0xFF00E5FF) : Colors.white38,
              glowColor: isSeen ? const Color(0xFF00B0FF) : null,
              size: 6.5,
            ),
          ],
        ),
      );
    }

    // Group / Department / General Chat Receipts
    if (groupReadPointers == null || groupReadPointers!.isEmpty || !showReadReceipts) {
      return const Padding(
        padding: EdgeInsets.only(left: 6),
        child: _NeonCrystal(
          isFilled: true,
          isGlow: false,
          color: Colors.white54,
          size: 6.5,
        ),
      );
    }

    final seenCount = groupReadPointers!.entries.where((e) {
      return e.key != message.senderId &&
          !e.value.lastReadAt.isBefore(message.timestamp);
    }).length;
    final hasAnySeen = seenCount > 0;

    return GestureDetector(
      onTap: () => _showSeenBySheet(context),
      child: Tooltip(
        message: hasAnySeen ? 'Seen by $seenCount (tap to view)' : 'Sent (tap to view)',
        child: Padding(
          padding: const EdgeInsets.only(left: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _NeonCrystal(
                isFilled: true,
                isGlow: hasAnySeen,
                color: hasAnySeen ? const Color(0xFF00E5FF) : Colors.white60,
                glowColor: hasAnySeen ? const Color(0xFF00E5FF) : null,
                size: 6.5,
              ),
              const SizedBox(width: 3.5),
              _NeonCrystal(
                isFilled: hasAnySeen,
                isGlow: hasAnySeen,
                color: hasAnySeen ? const Color(0xFF00E5FF) : Colors.white38,
                glowColor: hasAnySeen ? const Color(0xFF00B0FF) : null,
                size: 6.5,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextSpans(BuildContext context) {
    if (message.deleted) {
      return const Text(
        'Message deleted',
        style: TextStyle(
          color: Colors.grey,
          fontSize: 14,
          fontStyle: FontStyle.italic,
        ),
      );
    }

    final text = message.text;
    if (message.mentions.isEmpty && !text.contains('@')) {
      return Text(
        text,
        style: const TextStyle(color: Colors.white, fontSize: 15),
      );
    }

    // Parse @mentions spans
    final List<InlineSpan> spans = [];
    final List<String> patterns = ['@all'];
    for (final m in message.mentions) {
      if (m.name.isNotEmpty && m.name != 'all') {
        patterns.add('@${RegExp.escape(m.name)}');
      }
    }
    patterns.add(r'@[a-zA-Z0-9_\-\.]+');
    final regex = RegExp(patterns.join('|'), caseSensitive: false);
    int lastEnd = 0;

    for (final match in regex.allMatches(text)) {
      if (match.start > lastEnd) {
        spans.add(TextSpan(
          text: text.substring(lastEnd, match.start),
          style: const TextStyle(color: Colors.white, fontSize: 15),
        ));
      }

      final mentionText = match.group(0)!;
      final isAll = mentionText.toLowerCase() == '@all';

      spans.add(TextSpan(
        text: mentionText,
        style: TextStyle(
          color: isAll ? Colors.amberAccent : Colors.lightBlueAccent,
          fontWeight: FontWeight.bold,
          fontSize: 15,
        ),
      ));

      lastEnd = match.end;
    }

    if (lastEnd < text.length) {
      spans.add(TextSpan(
        text: text.substring(lastEnd),
        style: const TextStyle(color: Colors.white, fontSize: 15),
      ));
    }

    return RichText(text: TextSpan(children: spans));
  }

  Widget _buildQuotedReply() {
    final reply = message.replyTo;
    if (reply == null) return const SizedBox.shrink();

    return GestureDetector(
      onTap: () => onJumpToQuoted(reply.messageId),
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.25),
          borderRadius: BorderRadius.circular(8),
          border: Border(
            left: BorderSide(
              color: isMine ? Colors.white : primaryColor,
              width: 3.5,
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              reply.senderName.isNotEmpty ? reply.senderName : 'Colleague',
              style: TextStyle(
                color: isMine ? Colors.white : primaryColor,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              reply.snippet.isNotEmpty ? reply.snippet : 'Message',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.grey[300],
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bubbleColor = isMine
        ? primaryColor
        : const Color.fromRGBO(48, 48, 48, 1);

    Widget bubble = Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!isMine && !isConsecutive)
            Padding(
              padding: const EdgeInsets.only(left: 12, bottom: 3, top: 4),
              child: Text(
                message.senderName.isNotEmpty ? message.senderName : 'Colleague',
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          GestureDetector(
            onTap: isDirectChat ? null : () => _showSeenBySheet(context),
            onLongPress: () => _showMessageActions(context),
            onSecondaryTap: () => _showMessageActions(context),
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.76,
              ),
              margin: EdgeInsets.only(
                top: isConsecutive ? 2 : 4,
                bottom: 2,
                left: isMine ? 48 : 0,
                right: isMine ? 0 : 48,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: bubbleColor,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isMine ? 16 : (isConsecutive ? 4 : 4)),
                  bottomRight: Radius.circular(isMine ? (isConsecutive ? 4 : 4) : 16),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.12),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isPinned)
                    Container(
                      margin: const EdgeInsets.only(bottom: 5),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.push_pin, size: 11, color: Colors.amberAccent),
                          SizedBox(width: 4),
                          Text(
                            'Pinned',
                            style: TextStyle(
                              color: Colors.amberAccent,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  _buildQuotedReply(),
                  _buildTextSpans(context),
                  const SizedBox(height: 3),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (message.editedAt != null && !message.deleted) ...[
                        Text(
                          'edited ',
                          style: TextStyle(
                            color: isMine ? Colors.white60 : Colors.grey[400],
                            fontSize: 10,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                      Text(
                        _formatTime(message.timestamp),
                        style: TextStyle(
                          color: isMine ? Colors.white70 : Colors.grey[400],
                          fontSize: 10,
                        ),
                      ),
                      _buildReadStatusIcon(context),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );

    // On mobile, support swipe-to-reply gesture
    if (!kIsWeb && !message.deleted) {
      return Dismissible(
        key: Key('reply_${message.messageId}'),
        direction: DismissDirection.startToEnd,
        confirmDismiss: (direction) async {
          onReply(message);
          return false; // Don't dismiss the widget
        },
        background: Container(
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.only(left: 16),
          child: const Icon(Icons.reply, color: Colors.blueAccent, size: 24),
        ),
        child: bubble,
      );
    }

    return bubble;
  }
}

class _NeonCrystal extends StatelessWidget {
  final bool isFilled;
  final bool isGlow;
  final Color color;
  final Color? glowColor;
  final double size;

  const _NeonCrystal({
    required this.isFilled,
    required this.isGlow,
    required this.color,
    this.glowColor,
    this.size = 6.5,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveGlow = glowColor ?? color;
    return Transform.rotate(
      angle: 0.785398, // 45 degrees into diamond crystal
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: isFilled ? color : Colors.transparent,
          borderRadius: BorderRadius.circular(1.2),
          border: Border.all(
            color: isGlow ? Colors.white.withOpacity(0.9) : color,
            width: 1.1,
          ),
          gradient: isFilled
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isGlow
                      ? [
                          const Color(0xFFE0F7FA), // Specular light highlight
                          color,
                          color.withOpacity(0.85),
                        ]
                      : [
                          color,
                          color.withOpacity(0.7),
                        ],
                )
              : null,
          boxShadow: isGlow
              ? [
                  BoxShadow(
                    color: effectiveGlow.withOpacity(0.95),
                    blurRadius: 5.0,
                    spreadRadius: 1.0,
                  ),
                  BoxShadow(
                    color: effectiveGlow.withOpacity(0.45),
                    blurRadius: 10.0,
                    spreadRadius: 2.0,
                  ),
                ]
              : null,
        ),
      ),
    );
  }
}
