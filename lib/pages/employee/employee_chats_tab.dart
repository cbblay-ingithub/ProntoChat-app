import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../models/firm.dart';
import '../../services/db_service.dart';
import '../../screens/employee/firm_chat_screen.dart';
import '../convo_page.dart';
import '../search_page.dart';

class EmployeeChatsTab extends StatelessWidget {
  final String uid;
  final String userName;
  final Firm firm;

  const EmployeeChatsTab({
    super.key,
    required this.uid,
    required this.userName,
    required this.firm,
  });

  String _formatTimestamp(Timestamp? ts) {
    if (ts == null) return '';
    final dt = ts.toDate();
    final now = DateTime.now();
    final isToday = dt.year == now.year && dt.month == now.month && dt.day == now.day;
    if (isToday) {
      final hour = dt.hour.toString().padLeft(2, '0');
      final minute = dt.minute.toString().padLeft(2, '0');
      return '$hour:$minute';
    }
    return '${dt.day}/${dt.month}';
  }

  String _otherUid(String conversationId, String myUid) {
    final parts = conversationId.split('_');
    if (parts.length != 2) return '';
    return parts[0] == myUid ? parts[1] : parts[0];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;

    return Scaffold(
      backgroundColor: const Color.fromRGBO(28, 27, 27, 1),
      appBar: AppBar(
        backgroundColor: const Color.fromRGBO(28, 27, 27, 1),
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Conversations',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              firm.name,
              style: TextStyle(color: Colors.grey[400], fontSize: 12),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: Colors.white),
            tooltip: 'Search messages or people',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const UserSearchPage()),
              );
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        tooltip: 'New conversation',
        child: const Icon(Icons.chat),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const UserSearchPage()),
          );
        },
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: DBService.instance.streamConversations(uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data?.docs ?? [];

          return ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            children: [
              // ── Pinned Workspace Channel ─────────────────────────────────
              _buildPinnedTile(context, primaryColor),

              const Padding(
                padding: EdgeInsets.only(top: 18, bottom: 8, left: 4),
                child: Text(
                  'Direct Messages',
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
              ),

              // ── Direct Conversations List or Empty State ─────────────────
              if (docs.isEmpty)
                _buildEmptyState(context, primaryColor)
              else
                ...docs.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final String otherName = data['name'] as String? ?? 'Colleague';
                  final String otherImage = data['image'] as String? ?? '';
                  final String lastMessage = data['lastMessage'] as String? ?? '';
                  final int unseenCount = (data['unseenCount'] as num?)?.toInt() ?? 0;
                  final Timestamp? ts = data['timestamp'] as Timestamp?;
                  final String chatId = data['chatId'] as String? ?? doc.id;
                  final String otherUserId = _otherUid(chatId, uid);

                  return _buildConversationTile(
                    context: context,
                    chatId: chatId,
                    otherUserId: otherUserId,
                    name: otherName,
                    image: otherImage,
                    lastMessage: lastMessage,
                    unseenCount: unseenCount,
                    ts: ts,
                    primaryColor: primaryColor,
                  );
                }),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPinnedTile(BuildContext context, Color primaryColor) {
    return Container(
      decoration: BoxDecoration(
        color: const Color.fromRGBO(36, 35, 35, 1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: primaryColor.withValues(alpha: 0.25), width: 1.2),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: CircleAvatar(
          radius: 22,
          backgroundColor: primaryColor.withValues(alpha: 0.2),
          child: Icon(Icons.tag, color: primaryColor, size: 22),
        ),
        title: Row(
          children: [
            const Text(
              'General Team Chat',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: primaryColor.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'PINNED',
                style: TextStyle(
                  color: primaryColor,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        subtitle: const Text(
          'Company-wide discussions & announcements',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: Colors.grey, fontSize: 12),
        ),
        trailing: const Icon(Icons.chevron_right, color: Colors.grey),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => FirmChatScreen(
                firmId: firm.firmId,
                uid: uid,
                name: userName,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildConversationTile({
    required BuildContext context,
    required String chatId,
    required String otherUserId,
    required String name,
    required String image,
    required String lastMessage,
    required int unseenCount,
    required Timestamp? ts,
    required Color primaryColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Container(
        decoration: BoxDecoration(
          color: const Color.fromRGBO(34, 33, 33, 1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
          leading: CircleAvatar(
            radius: 22,
            backgroundColor: primaryColor.withValues(alpha: 0.25),
            backgroundImage: image.isNotEmpty ? NetworkImage(image) : null,
            child: image.isEmpty
                ? Text(
                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: TextStyle(
                      color: primaryColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  )
                : null,
          ),
          title: Text(
            name,
            style: TextStyle(
              color: Colors.white,
              fontWeight: unseenCount > 0 ? FontWeight.w700 : FontWeight.w500,
              fontSize: 15,
            ),
          ),
          subtitle: Text(
            lastMessage.isNotEmpty ? lastMessage : 'No messages yet',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: unseenCount > 0 ? Colors.white70 : Colors.grey[500],
              fontWeight: unseenCount > 0 ? FontWeight.w600 : FontWeight.normal,
              fontSize: 13,
            ),
          ),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _formatTimestamp(ts),
                style: TextStyle(
                  color: unseenCount > 0 ? primaryColor : Colors.grey[600],
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 4),
              if (unseenCount > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: primaryColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    unseenCount > 99 ? '99+' : '$unseenCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                )
              else
                const SizedBox(height: 16),
            ],
          ),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ChatPage(
                  conversationId: chatId,
                  otherUserId: otherUserId,
                  otherUserName: name,
                  otherUserImage: image,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, Color primaryColor) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
      margin: const EdgeInsets.only(top: 12),
      decoration: BoxDecoration(
        color: const Color.fromRGBO(34, 33, 33, 1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: primaryColor.withValues(alpha: 0.15),
            child: Icon(Icons.people_outline, color: primaryColor, size: 28),
          ),
          const SizedBox(height: 16),
          const Text(
            'No Direct Chats Yet',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Message a colleague from your firm or reach out on the General Team Chat.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[400], fontSize: 13),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.add_comment, size: 18),
            label: const Text('Start New Conversation'),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const UserSearchPage()),
              );
            },
          ),
        ],
      ),
    );
  }
}
