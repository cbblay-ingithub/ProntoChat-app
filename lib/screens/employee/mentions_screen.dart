import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../models/mention_inbox_item.dart';
import '../../services/db_service.dart';
import 'channel_chat_screen.dart';
import 'firm_chat_screen.dart';

class MentionsScreen extends StatelessWidget {
  final String firmId;
  final String uid;
  final String userName;

  const MentionsScreen({
    super.key,
    required this.firmId,
    required this.uid,
    required this.userName,
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
    // 1. Mark mention read
    DBService.instance.markMentionItemRead(
      firmId: firmId,
      uid: uid,
      messageId: item.messageId,
    );

    // 2. Open channel / chat based on conversationId
    final convId = item.conversationId;
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
      // General channel or department or project
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
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;

    return Scaffold(
      backgroundColor: const Color.fromRGBO(18, 17, 18, 1),
      appBar: AppBar(
        backgroundColor: const Color.fromRGBO(24, 23, 24, 1),
        title: const Row(
          children: [
            Icon(Icons.alternate_email, color: Colors.lightBlueAccent, size: 20),
            SizedBox(width: 8),
            Text('Mentions Inbox', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: DBService.instance.streamMentionsInbox(firmId: firmId, uid: uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: Colors.lightBlueAccent.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.alternate_email, size: 36, color: Colors.lightBlueAccent),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No mentions yet',
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'When teammates mention you with @$userName,\nyou\'ll see them here.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey[400], fontSize: 13),
                  ),
                ],
              ),
            );
          }

          final items = docs.map((d) => MentionInboxItem.fromMap(d.id, d.data())).toList();

          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: items.length,
            separatorBuilder: (_, __) => const Divider(color: Colors.white10, height: 1),
            itemBuilder: (ctx, index) {
              final item = items[index];
              final isUnread = !item.read;

              return ListTile(
                tileColor: isUnread ? Colors.lightBlueAccent.withOpacity(0.06) : Colors.transparent,
                leading: Stack(
                  children: [
                    CircleAvatar(
                      backgroundColor: isUnread ? Colors.lightBlueAccent.withOpacity(0.2) : Colors.white12,
                      child: Text(
                        item.senderName.isNotEmpty ? item.senderName[0].toUpperCase() : '?',
                        style: TextStyle(
                          color: isUnread ? Colors.lightBlueAccent : Colors.white70,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                          color: Colors.black,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.alternate_email,
                          size: 11,
                          color: isUnread ? Colors.lightBlueAccent : Colors.grey,
                        ),
                      ),
                    ),
                  ],
                ),
                title: Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.senderName,
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: isUnread ? FontWeight.bold : FontWeight.w500,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    Text(
                      _formatTime(item.createdAt),
                      style: TextStyle(
                        color: isUnread ? Colors.lightBlueAccent : Colors.grey[500],
                        fontSize: 11,
                        fontWeight: isUnread ? FontWeight.bold : FontWeight.normal,
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
                      color: isUnread ? Colors.white : Colors.grey[400],
                      fontSize: 13,
                    ),
                  ),
                ),
                trailing: isUnread
                    ? Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Colors.lightBlueAccent,
                          shape: BoxShape.circle,
                        ),
                      )
                    : null,
                onTap: () => _openMentionedMessage(context, item),
              );
            },
          );
        },
      ),
    );
  }
}
