import 'dart:math' as math;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import '../../models/chat_message.dart';
import '../../models/chat_polish_models.dart';
import '../../theme/pc_tokens.dart';
import 'image_bubble.dart';
import 'poll_bubble_widget.dart';

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
  final String currentUid;
  final String? firmId;
  final String? conversationId;
  final String currentUserRole;
  final List<Map<String, String>> participants;
  final bool isHighlighted;

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
    this.currentUid = '',
    this.firmId,
    this.conversationId,
    this.currentUserRole = 'employee',
    this.participants = const [],
    this.isHighlighted = false,
  });

  String _formatTime(DateTime dt) {
    final local = dt.toLocal();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  void _showPinDurationDialog(BuildContext context) {
    final tokens = context.pcTokens;
    showModalBottomSheet(
      context: context,
      backgroundColor: tokens.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    Icon(
                      Icons.push_pin_rounded,
                      color: tokens.warningAccent,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Choose Pin Duration',
                      style: TextStyle(
                        color: tokens.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
                child: Text(
                  'Messages cannot be pinned indefinitely. Newly pinned messages take precedence.',
                  style: TextStyle(color: tokens.textMuted, fontSize: 12),
                ),
              ),
              Divider(color: tokens.border, height: 1),
              ListTile(
                leading: Icon(Icons.timer_outlined, color: tokens.infoAccent),
                title: Text(
                  '3 Hours',
                  style: TextStyle(color: tokens.textPrimary),
                ),
                subtitle: Text(
                  'Keep pinned for a few hours',
                  style: TextStyle(color: tokens.textMuted, fontSize: 11),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  onPin(message, const Duration(hours: 3));
                },
              ),
              ListTile(
                leading: Icon(Icons.today_rounded, color: tokens.warningAccent),
                title: Text(
                  '24 Hours (1 Day)',
                  style: TextStyle(color: tokens.textPrimary),
                ),
                subtitle: Text(
                  'Keep pinned until tomorrow',
                  style: TextStyle(color: tokens.textMuted, fontSize: 11),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  onPin(message, const Duration(hours: 24));
                },
              ),
              ListTile(
                leading: Icon(Icons.date_range_rounded, color: tokens.projectAccent),
                title: Text(
                  '7 Days (1 Week)',
                  style: TextStyle(color: tokens.textPrimary),
                ),
                subtitle: Text(
                  'Keep pinned for the entire week',
                  style: TextStyle(color: tokens.textMuted, fontSize: 11),
                ),
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
    final tokens = context.pcTokens;

    showModalBottomSheet(
      context: context,
      backgroundColor: tokens.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: Icon(Icons.reply_rounded, color: tokens.primary),
              title: Text('Reply', style: TextStyle(color: tokens.textPrimary)),
              onTap: () {
                Navigator.pop(ctx);
                onReply(message);
              },
            ),
            if (isPinned && canPin)
              ListTile(
                leading: Icon(Icons.push_pin_rounded, color: tokens.warningAccent),
                title: Text(
                  'Unpin Message',
                  style: TextStyle(color: tokens.textPrimary),
                ),
                subtitle: Text(
                  'Remove from pinned messages banner',
                  style: TextStyle(color: tokens.textMuted, fontSize: 11),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  onUnpin?.call(message);
                },
              )
            else if (canPin)
              ListTile(
                leading: Icon(
                  Icons.push_pin_outlined,
                  color: tokens.warningAccent,
                ),
                title: Text(
                  'Pin Message',
                  style: TextStyle(color: tokens.textPrimary),
                ),
                subtitle: Text(
                  'Select a duration (hours, day, or week)',
                  style: TextStyle(color: tokens.textMuted, fontSize: 11),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _showPinDurationDialog(context);
                },
              ),
            if (isMine && !message.deleted) ...[
              ListTile(
                leading: Icon(Icons.edit_outlined, color: tokens.online),
                title: Text(
                  'Edit Message',
                  style: TextStyle(color: tokens.textPrimary),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  onEdit(message);
                },
              ),
              ListTile(
                leading: Icon(Icons.delete_outline_rounded, color: tokens.urgentText),
                title: Text(
                  'Delete Message',
                  style: TextStyle(color: tokens.urgentText),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  onDelete(message);
                },
              ),
            ],
            if (message.isFailed && onRetry != null)
              ListTile(
                leading: Icon(Icons.refresh_rounded, color: tokens.warningAccent),
                title: Text(
                  'Retry Sending',
                  style: TextStyle(color: tokens.textPrimary),
                ),
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
    final tokens = context.pcTokens;

    final seenBy = groupReadPointers!.entries.where((e) {
      return e.key != message.senderId &&
          !e.value.lastReadAt.isBefore(message.timestamp);
    }).toList();

    showModalBottomSheet(
      context: context,
      backgroundColor: tokens.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
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
                style: TextStyle(
                  color: tokens.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              if (seenBy.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Text(
                    'No participants have viewed this message yet.',
                    style: TextStyle(color: tokens.textMuted),
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
                      leading: CircleAvatar(
                        radius: 14,
                        backgroundColor: tokens.primarySoft,
                        child: Icon(
                          Icons.check_rounded,
                          size: 14,
                          color: tokens.primary,
                        ),
                      ),
                      title: Text(
                        item.key,
                        style: TextStyle(color: tokens.textPrimary),
                      ),
                      trailing: Text(
                        _formatTime(item.value.lastReadAt),
                        style: TextStyle(color: tokens.textMuted, fontSize: 11),
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

  Widget _buildReadStatusIcon(BuildContext context, Color fgText) {
    if (!isMine) return const SizedBox.shrink();

    if (message.isPending || message.hasPendingWrites) {
      return Padding(
        padding: const EdgeInsets.only(left: 6),
        child: SizedBox(
          width: 9,
          height: 9,
          child: CircularProgressIndicator(
            strokeWidth: 1.2,
            color: fgText.withValues(alpha: 0.7),
          ),
        ),
      );
    }

    if (message.isFailed) {
      return const Padding(
        padding: EdgeInsets.only(left: 4),
        child: Icon(
          Icons.error_outline_rounded,
          size: 12,
          color: Color(0xFFFCA5A5),
        ),
      );
    }

    if (isDirectChat) {
      if (!showReadReceipts || otherReadPointer == null) {
        return Padding(
          padding: const EdgeInsets.only(left: 6),
          child: _StatusCrystal(
            isFilled: true,
            isGlow: false,
            color: fgText.withValues(alpha: 0.65),
            size: 6.2,
          ),
        );
      }

      final isSeen = !otherReadPointer!.lastReadAt.isBefore(message.timestamp);
      return Padding(
        padding: const EdgeInsets.only(left: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _StatusCrystal(
              isFilled: true,
              isGlow: isSeen,
              color: isSeen
                  ? const Color(0xFF7DD3FC)
                  : fgText.withValues(alpha: 0.7),
              size: 6.2,
            ),
            const SizedBox(width: 3.5),
            _StatusCrystal(
              isFilled: isSeen,
              isGlow: isSeen,
              color: isSeen
                  ? const Color(0xFF7DD3FC)
                  : fgText.withValues(alpha: 0.45),
              size: 6.2,
            ),
          ],
        ),
      );
    }

    if (groupReadPointers == null ||
        groupReadPointers!.isEmpty ||
        !showReadReceipts) {
      return Padding(
        padding: const EdgeInsets.only(left: 6),
        child: _StatusCrystal(
          isFilled: true,
          isGlow: false,
          color: fgText.withValues(alpha: 0.65),
          size: 6.2,
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
        message: hasAnySeen
            ? 'Seen by $seenCount (tap to view)'
            : 'Sent (tap to view)',
        child: Padding(
          padding: const EdgeInsets.only(left: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _StatusCrystal(
                isFilled: true,
                isGlow: hasAnySeen,
                color: hasAnySeen
                    ? const Color(0xFF7DD3FC)
                    : fgText.withValues(alpha: 0.7),
                size: 6.2,
              ),
              const SizedBox(width: 3.5),
              _StatusCrystal(
                isFilled: hasAnySeen,
                isGlow: hasAnySeen,
                color: hasAnySeen
                    ? const Color(0xFF7DD3FC)
                    : fgText.withValues(alpha: 0.45),
                size: 6.2,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextSpans(BuildContext context, PcTokens tokens, Color fgText) {
    if (message.deleted) {
      return Text(
        'Message deleted',
        style: TextStyle(
          color: isMine ? fgText.withValues(alpha: 0.7) : tokens.textMuted,
          fontSize: 14,
          fontStyle: FontStyle.italic,
        ),
      );
    }

    final text = message.text;
    if (message.mentions.isEmpty && !text.contains('@')) {
      return Text(
        text,
        style: TextStyle(color: fgText, fontSize: 14.5, height: 1.35),
      );
    }

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
        spans.add(
          TextSpan(
            text: text.substring(lastEnd, match.start),
            style: TextStyle(color: fgText, fontSize: 14.5, height: 1.35),
          ),
        );
      }

      final mentionText = match.group(0)!;
      final isAll = mentionText.toLowerCase() == '@all';

      spans.add(
        TextSpan(
          text: mentionText,
          style: TextStyle(
            color: isMine
                ? (isAll ? const Color(0xFFFDE68A) : Colors.white)
                : (isAll ? tokens.warningAccent : tokens.primary),
            decoration: isMine ? TextDecoration.underline : null,
            fontWeight: FontWeight.w700,
            fontSize: 14.5,
            height: 1.35,
          ),
        ),
      );

      lastEnd = match.end;
    }

    if (lastEnd < text.length) {
      spans.add(
        TextSpan(
          text: text.substring(lastEnd),
          style: TextStyle(color: fgText, fontSize: 14.5, height: 1.35),
        ),
      );
    }

    return RichText(text: TextSpan(children: spans));
  }

  Widget _buildQuotedReply(PcTokens tokens, Color fgText) {
    final reply = message.replyTo;
    if (reply == null) return const SizedBox.shrink();

    return GestureDetector(
      onTap: () => onJumpToQuoted(reply.messageId),
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isMine
              ? Colors.black.withValues(alpha: 0.16)
              : tokens.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border(
            left: BorderSide(
              color: isMine ? fgText : primaryColor,
              width: 3,
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              reply.senderName.isNotEmpty ? reply.senderName : 'Colleague',
              style: TextStyle(
                color: isMine ? fgText : primaryColor,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              reply.snippet.isNotEmpty ? reply.snippet : 'Message',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: isMine
                    ? fgText.withValues(alpha: 0.85)
                    : tokens.textSecondary,
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
    final tokens = context.pcTokens;
    final effectiveOutgoing = PcTokens.readableAccentOnLight(primaryColor);
    final bubbleColor = isMine ? effectiveOutgoing : tokens.surface;
    final fgText =
        isMine ? PcTokens.contrastOn(effectiveOutgoing) : tokens.textPrimary;

    final bool mentionsMe = !isMine &&
        currentUid.isNotEmpty &&
        message.mentions.any((m) => m.uid == currentUid || m.uid == 'all');

    final double maxBubbleWidth =
        math.min(MediaQuery.sizeOf(context).width * 0.76, 620.0);

    Widget bubble = Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        crossAxisAlignment:
            isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!isMine && !isConsecutive)
            Padding(
              padding: const EdgeInsets.only(left: 10, bottom: 3, top: 6),
              child: Text(
                message.senderName.isNotEmpty ? message.senderName : 'Colleague',
                style: TextStyle(
                  color: tokens.textSecondary,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          GestureDetector(
            onTap: isDirectChat ? null : () => _showSeenBySheet(context),
            onLongPress: () => _showMessageActions(context),
            onSecondaryTap: () => _showMessageActions(context),
            child: Container(
              constraints: BoxConstraints(maxWidth: maxBubbleWidth),
              margin: EdgeInsets.only(
                top: isConsecutive ? 2 : 3,
                bottom: 2,
                left: isMine ? 48 : 0,
                right: isMine ? 0 : 48,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                color: bubbleColor,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isMine ? 16 : 4),
                  bottomRight: Radius.circular(isMine ? 4 : 16),
                ),
                border: isHighlighted
                    ? Border.all(color: tokens.warningAccent, width: 2)
                    : mentionsMe
                        ? Border.all(color: tokens.primary, width: 1.4)
                        : (!isMine ? Border.all(color: tokens.border) : null),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (mentionsMe)
                    Container(
                      margin: const EdgeInsets.only(bottom: 5),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: tokens.primarySoft,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.alternate_email_rounded,
                            size: 10,
                            color: tokens.primary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Mentioned you',
                            style: TextStyle(
                              color: tokens.primary,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (isPinned)
                    Container(
                      margin: const EdgeInsets.only(bottom: 5),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: isMine
                            ? Colors.black.withValues(alpha: 0.16)
                            : tokens.warningSoft,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.push_pin_rounded,
                            size: 11,
                            color: isMine
                                ? const Color(0xFFFDE68A)
                                : tokens.warningAccent,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Pinned',
                            style: TextStyle(
                              color: isMine
                                  ? const Color(0xFFFDE68A)
                                  : tokens.warningAccent,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  _buildQuotedReply(tokens, fgText),
                  if (message.type == 'poll' && message.poll != null)
                    PollBubbleWidget(
                      message: message,
                      firmId: firmId,
                      conversationId: conversationId ?? '',
                      currentUid: currentUid,
                      currentUserRole: currentUserRole,
                      primaryColor: effectiveOutgoing,
                      isMine: isMine,
                      participants: participants,
                    )
                  else if (message.type == 'image' && message.media != null)
                    ImageBubbleWidget(
                      message: message,
                      isMine: isMine,
                      primaryColor: effectiveOutgoing,
                      captionWidget: message.text.isNotEmpty
                          ? _buildTextSpans(context, tokens, fgText)
                          : null,
                    )
                  else
                    _buildTextSpans(context, tokens, fgText),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (message.editedAt != null && !message.deleted)
                        Text(
                          'edited ',
                          style: TextStyle(
                            color: isMine
                                ? fgText.withValues(alpha: 0.72)
                                : tokens.textMuted,
                            fontSize: 10,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      Text(
                        _formatTime(message.timestamp),
                        style: TextStyle(
                          color: isMine
                              ? fgText.withValues(alpha: 0.78)
                              : tokens.textMuted,
                          fontSize: 10,
                        ),
                      ),
                      _buildReadStatusIcon(context, fgText),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );

    if (!kIsWeb && !message.deleted) {
      return Dismissible(
        key: Key('reply_${message.messageId}'),
        direction: DismissDirection.startToEnd,
        confirmDismiss: (direction) async {
          onReply(message);
          return false;
        },
        background: Container(
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.only(left: 16),
          child: Icon(Icons.reply_rounded, color: tokens.primary, size: 22),
        ),
        child: bubble,
      );
    }

    return bubble;
  }
}

class _StatusCrystal extends StatelessWidget {
  final bool isFilled;
  final bool isGlow;
  final Color color;
  final double size;

  const _StatusCrystal({
    required this.isFilled,
    required this.isGlow,
    required this.color,
    this.size = 6.2,
  });

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: 0.785398,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: isFilled ? color : Colors.transparent,
          borderRadius: BorderRadius.circular(1.2),
          border: Border.all(
            color: isGlow ? Colors.white : color,
            width: 1.0,
          ),
          boxShadow: isGlow
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.8),
                    blurRadius: 4,
                    spreadRadius: 0.5,
                  ),
                ]
              : null,
        ),
      ),
    );
  }
}
