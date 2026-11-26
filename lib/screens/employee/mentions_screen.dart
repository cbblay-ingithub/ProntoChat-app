import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../models/active_chat_selection.dart';
import '../../models/mention_inbox_item.dart';
import '../../services/db_service.dart';
import '../../theme/pc_tokens.dart';
import '../../widgets/chat/unified_chat_view.dart';
import 'channel_chat_screen.dart';
import 'firm_chat_screen.dart';

class MentionsScreen extends StatelessWidget {
  final String firmId;
  final String uid;
  final String userName;
  final bool isEmbeddedPane;
  final ValueChanged<ActiveChatSelection>? onOpenChat;

  const MentionsScreen({
    super.key,
    required this.firmId,
    required this.uid,
    required this.userName,
    this.isEmbeddedPane = false,
    this.onOpenChat,
  });

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.month}/${dt.day}';
  }

  void _openMentionedMessage(BuildContext context, MentionInboxItem item) {
    DBService.instance.markMentionItemRead(
      firmId: firmId,
      uid: uid,
      messageId: item.messageId,
    );

    final convId = item.conversationId;
    if (onOpenChat != null) {
      if (convId == firmId || convId == 'general') {
        onOpenChat!(ActiveChatSelection.general(firmId, 'Workspace'));
      } else if (convId == 'all_staff') {
        onOpenChat!(ActiveChatSelection.allStaff());
      } else {
        onOpenChat!(
          ActiveChatSelection(
            kind: UnifiedChatKind.department,
            conversationId: convId,
            title: 'Channel',
            subtitle: 'Conversation',
          ),
        );
      }
      return;
    }

    if (convId == firmId || convId == 'general') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => FirmChatScreen(
            firmId: firmId,
            uid: uid,
            name: userName,
          ),
        ),
      );
    } else if (convId == 'all_staff') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChannelChatScreen(
            channelType: ChannelType.allStaff,
            firmId: firmId,
            conversationId: 'all_staff',
            title: '#all-staff',
            subtitle: 'All Staff Announcements',
            uid: uid,
            userName: userName,
          ),
        ),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChannelChatScreen(
            channelType: ChannelType.department,
            firmId: firmId,
            conversationId: convId,
            title: 'Channel',
            subtitle: 'Conversation',
            uid: uid,
            userName: userName,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.pcTokens;

    Widget body = StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: DBService.instance.streamMentionsInbox(firmId: firmId, uid: uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(color: tokens.primary),
          );
        }

        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 68,
                  height: 68,
                  decoration: BoxDecoration(
                    color: tokens.primarySoft,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.alternate_email_rounded,
                    size: 32,
                    color: tokens.primary,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'No mentions yet',
                  style: TextStyle(
                    color: tokens.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'When teammates mention you with @$userName,\nyou\'ll see them here.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: tokens.textMuted, fontSize: 13),
                ),
              ],
            ),
          );
        }

        final items = docs
            .map((d) => MentionInboxItem.fromMap(d.id, d.data()))
            .toList();

        return ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          itemCount: items.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (ctx, index) {
            final item = items[index];
            final isUnread = !item.read;

            return Container(
              decoration: BoxDecoration(
                color: isUnread ? tokens.primarySoft : tokens.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isUnread ? tokens.primaryBorder : tokens.border,
                ),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 4,
                ),
                leading: CircleAvatar(
                  backgroundColor: isUnread
                      ? tokens.primary.withValues(alpha: 0.16)
                      : tokens.surfaceSubtle,
                  child: Text(
                    item.senderName.isNotEmpty
                        ? item.senderName[0].toUpperCase()
                        : '?',
                    style: TextStyle(
                      color: isUnread ? tokens.primary : tokens.textSecondary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                title: Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.senderName,
                        style: TextStyle(
                          color: tokens.textPrimary,
                          fontWeight:
                              isUnread ? FontWeight.w700 : FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    Text(
                      _formatTime(item.createdAt),
                      style: TextStyle(
                        color: isUnread ? tokens.primary : tokens.textMuted,
                        fontSize: 11,
                        fontWeight:
                            isUnread ? FontWeight.w700 : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Text(
                    item.snippet,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isUnread
                          ? tokens.textPrimary
                          : tokens.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ),
                trailing: isUnread
                    ? Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: tokens.primary,
                          shape: BoxShape.circle,
                        ),
                      )
                    : null,
                onTap: () => _openMentionedMessage(context, item),
              ),
            );
          },
        );
      },
    );

    if (isEmbeddedPane) {
      body = Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 840),
          child: body,
        ),
      );
    }

    return Scaffold(
      backgroundColor: tokens.canvas,
      appBar: AppBar(
        automaticallyImplyLeading: !isEmbeddedPane,
        backgroundColor: tokens.surface,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: tokens.border),
        ),
        title: Row(
          children: [
            Icon(Icons.alternate_email_rounded, color: tokens.primary, size: 20),
            const SizedBox(width: 8),
            Text(
              'Mentions Inbox',
              style: TextStyle(
                color: tokens.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
      body: body,
    );
  }
}
