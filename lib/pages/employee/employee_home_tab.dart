import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../models/firm.dart';
import '../../services/db_service.dart';
import '../../screens/employee/firm_chat_screen.dart';
import '../../screens/employee/channel_chat_screen.dart';
import '../convo_page.dart';
import '../search_page.dart';

class EmployeeHomeTab extends StatelessWidget {
  final String uid;
  final String userName;
  final Firm firm;
  final void Function(int tabIndex) onNavigateToTab;

  const EmployeeHomeTab({
    super.key,
    required this.uid,
    required this.userName,
    required this.firm,
    required this.onNavigateToTab,
  });

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return 'Good morning';
    } else if (hour < 17) {
      return 'Good afternoon';
    } else {
      return 'Good evening';
    }
  }

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
        titleSpacing: 16,
        title: Row(
          children: [
            if (firm.logoUrl != null && firm.logoUrl!.isNotEmpty) ...[
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  image: DecorationImage(
                    image: NetworkImage(firm.logoUrl!),
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              const SizedBox(width: 10),
            ] else ...[
              CircleAvatar(
                radius: 17,
                backgroundColor: primaryColor.withValues(alpha: 0.18),
                child: Text(
                  firm.name.isNotEmpty ? firm.name[0].toUpperCase() : 'W',
                  style: TextStyle(
                    color: primaryColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    firm.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Text(
                    'Workspace Portal',
                    style: TextStyle(color: Colors.grey, fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: Colors.white),
            tooltip: 'Search colleagues',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const UserSearchPage()),
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: DBService.instance.streamMember(firm.firmId, uid),
        builder: (context, memberSnapshot) {
          final memberData = memberSnapshot.data?.data() ?? {};
          final userRole = memberData['role'] as String? ?? 'employee';
          final departmentId = memberData['departmentId'] as String?;

          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Lead Upgrade Notification Banner ─────────────────────────
                if (userRole == 'lead')
                  Container(
                    margin: const EdgeInsets.only(bottom: 14),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.purple.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.purpleAccent.withOpacity(0.3)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.star, color: Colors.purpleAccent, size: 20),
                        SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Lead Privileges Active',
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                              Text(
                                'You can create project groups and post in #all-staff. (Restart app if privileges newly applied)',
                                style: TextStyle(color: Colors.grey, fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                // ── Greeting Card ────────────────────────────────────────────
                _buildGreetingCard(context, primaryColor),

                const SizedBox(height: 20),

                // ── Quick Actions ────────────────────────────────────────────
                const Text(
                  'Quick Actions',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                _buildQuickActions(context, primaryColor, departmentId),

                const SizedBox(height: 24),

                // ── Company Channels & Recent Conversations ─────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Company Channels',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    TextButton(
                      onPressed: () => onNavigateToTab(1), // Switch to Chats tab
                      child: Text(
                        'View all',
                        style: TextStyle(
                          color: primaryColor,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // #all-staff Channel Tile
                _buildAllStaffTile(context, primaryColor),

                const SizedBox(height: 10),

                // Department Tile
                if (departmentId != null) ...[
                  _buildDepartmentTile(context, primaryColor, departmentId),
                  const SizedBox(height: 10),
                ],

                // Pinned General Team Chat Tile
                _buildPinnedTeamChatTile(context, primaryColor),

                const SizedBox(height: 18),

                const Text(
                  'Recent Direct Messages',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),

                // Direct Chats Overview Stream
                _buildRecentDirectChats(context, primaryColor),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildGreetingCard(BuildContext context, Color primaryColor) {
    final firstName = userName.split(' ').first;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            primaryColor.withValues(alpha: 0.25),
            const Color.fromRGBO(38, 37, 37, 1),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: primaryColor.withValues(alpha: 0.3),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(radius: 4, backgroundColor: primaryColor),
                    const SizedBox(width: 6),
                    Text(
                      firm.name,
                      style: TextStyle(
                        color: primaryColor,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              const Icon(Icons.verified, color: Colors.blueAccent, size: 18),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            '${_getGreeting()}, $firstName!',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Stay in sync with your colleagues and project channels.',
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context, Color primaryColor, String? departmentId) {
    return Row(
      children: [
        // Action 1: #all-staff
        Expanded(
          child: _QuickActionCard(
            title: '#all-staff',
            subtitle: 'Notices',
            icon: Icons.campaign,
            iconColor: Colors.blueAccent,
            onTap: () async {
              await DBService.instance.ensureAllStaffChannel(firm.firmId);
              if (context.mounted) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ChannelChatScreen(
                      channelType: ChannelType.allStaff,
                      firmId: firm.firmId,
                      conversationId: 'all_staff',
                      title: '#all-staff',
                      uid: uid,
                      userName: userName,
                    ),
                  ),
                );
              }
            },
          ),
        ),
        const SizedBox(width: 8),

        // Action 2: Team Chat
        Expanded(
          child: _QuickActionCard(
            title: 'Team Chat',
            subtitle: '#general',
            icon: Icons.tag,
            iconColor: primaryColor,
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
        ),
        const SizedBox(width: 8),

        // Action 3: Message
        Expanded(
          child: _QuickActionCard(
            title: 'Message',
            subtitle: 'Direct chat',
            icon: Icons.chat_bubble_outline,
            iconColor: Colors.tealAccent,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const UserSearchPage()),
              );
            },
          ),
        ),
        const SizedBox(width: 8),

        // Action 4: Directory
        Expanded(
          child: _QuickActionCard(
            title: 'Directory',
            subtitle: 'Colleagues',
            icon: Icons.people_outline,
            iconColor: Colors.purpleAccent,
            onTap: () => onNavigateToTab(2), // Switch to Directory tab
          ),
        ),
      ],
    );
  }

  Widget _buildAllStaffTile(BuildContext context, Color primaryColor) {
    return InkWell(
      onTap: () async {
        await DBService.instance.ensureAllStaffChannel(firm.firmId);
        if (context.mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ChannelChatScreen(
                channelType: ChannelType.allStaff,
                firmId: firm.firmId,
                conversationId: 'all_staff',
                title: '#all-staff',
                uid: uid,
                userName: userName,
              ),
            ),
          );
        }
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color.fromRGBO(36, 35, 35, 1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.blueAccent.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: Colors.blueAccent.withOpacity(0.2),
              child: const Icon(Icons.campaign, color: Colors.blueAccent, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        '#all-staff Channel',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.blueAccent.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'OFFICIAL',
                          style: TextStyle(
                            color: Colors.blueAccent,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Company-wide official announcements and updates',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.grey[400], fontSize: 12),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildDepartmentTile(BuildContext context, Color primaryColor, String departmentId) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('Firms')
          .doc(firm.firmId)
          .collection('departments')
          .doc(departmentId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return const SizedBox.shrink();
        }
        final data = snapshot.data?.data() ?? {};
        final name = data['name'] as String? ?? 'Department';
        final convId = data['conversationId'] as String?;
        if (convId == null || convId.isEmpty) {
          return const SizedBox.shrink();
        }

        return InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ChannelChatScreen(
                  channelType: ChannelType.department,
                  firmId: firm.firmId,
                  conversationId: convId,
                  title: name,
                  uid: uid,
                  userName: userName,
                ),
              ),
            );
          },
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: const Color.fromRGBO(36, 35, 35, 1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: primaryColor.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: primaryColor.withOpacity(0.2),
                  child: Icon(Icons.corporate_fare, color: primaryColor, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: primaryColor.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'DEPARTMENT',
                              style: TextStyle(
                                color: primaryColor,
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Your team department channel',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: Colors.grey[400], fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPinnedTeamChatTile(BuildContext context, Color primaryColor) {
    return InkWell(
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
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color.fromRGBO(36, 35, 35, 1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: primaryColor.withValues(alpha: 0.25),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: primaryColor.withValues(alpha: 0.2),
              child: Icon(Icons.tag, color: primaryColor, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'General Team Chat',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 6),
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
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Company-wide announcement & team messaging',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.grey[400], fontSize: 12),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentDirectChats(BuildContext context, Color primaryColor) {
    return StreamBuilder<QuerySnapshot>(
      stream: DBService.instance.streamConversations(uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: CircularProgressIndicator(),
            ),
          );
        }

        final docs = snapshot.data?.docs ?? [];

        if (docs.isEmpty) {
          return _buildEmptyState(context, primaryColor);
        }

        // Limit to 5 most recent for the Home tab
        final recentDocs = docs.take(5).toList();

        return Column(
          children: recentDocs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final String otherName = data['name'] as String? ?? 'Colleague';
            final String otherImage = data['image'] as String? ?? '';
            final String lastMessage = data['lastMessage'] as String? ?? '';
            final int unseenCount = (data['unseenCount'] as num?)?.toInt() ?? 0;
            final Timestamp? ts = data['timestamp'] as Timestamp?;
            final String chatId = data['chatId'] as String? ?? doc.id;
            final String otherUserId = _otherUid(chatId, uid);

            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChatPage(
                        conversationId: chatId,
                        otherUserId: otherUserId,
                        otherUserName: otherName,
                        otherUserImage: otherImage,
                      ),
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color.fromRGBO(34, 33, 33, 1),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: primaryColor.withValues(alpha: 0.25),
                        backgroundImage: otherImage.isNotEmpty ? NetworkImage(otherImage) : null,
                        child: otherImage.isEmpty
                            ? Text(
                                otherName.isNotEmpty ? otherName[0].toUpperCase() : '?',
                                style: TextStyle(
                                  color: primaryColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              otherName,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: unseenCount > 0 ? FontWeight.w700 : FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              lastMessage.isNotEmpty ? lastMessage : 'No messages yet',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: unseenCount > 0 ? Colors.white70 : Colors.grey[500],
                                fontSize: 12,
                                fontWeight: unseenCount > 0 ? FontWeight.w600 : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Column(
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
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: primaryColor,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '$unseenCount',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext context, Color primaryColor) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
      decoration: BoxDecoration(
        color: const Color.fromRGBO(34, 33, 33, 1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: primaryColor.withValues(alpha: 0.15),
            child: Icon(Icons.chat_bubble_outline, color: primaryColor, size: 28),
          ),
          const SizedBox(height: 14),
          const Text(
            'No direct messages yet',
            style: TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Start a conversation with a teammate or join the discussion in #general.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[400], fontSize: 12),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.person_search, size: 18),
            label: const Text('Find a Colleague to Message'),
            onPressed: () => onNavigateToTab(2), // Switch to Directory tab
          ),
        ],
      ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconColor;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        decoration: BoxDecoration(
          color: const Color.fromRGBO(36, 35, 35, 1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: Column(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: iconColor.withValues(alpha: 0.15),
              child: Icon(icon, color: iconColor, size: 18),
            ),
            const SizedBox(height: 10),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
