import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../models/firm.dart';
import '../../services/db_service.dart';
import '../../services/snackbar_service.dart';
import '../../screens/employee/firm_chat_screen.dart';
import '../../screens/employee/channel_chat_screen.dart';
import '../convo_page.dart';
import '../search_page.dart';

class EmployeeChatsTab extends StatefulWidget {
  final String uid;
  final String userName;
  final Firm firm;

  const EmployeeChatsTab({
    super.key,
    required this.uid,
    required this.userName,
    required this.firm,
  });

  @override
  State<EmployeeChatsTab> createState() => _EmployeeChatsTabState();
}

class _EmployeeChatsTabState extends State<EmployeeChatsTab> {
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

  Future<void> _showCreateProjectGroupDialog(BuildContext context) async {
    final nameCtrl = TextEditingController();
    final Set<String> selectedUids = {widget.uid};

    await showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: const Color.fromRGBO(34, 33, 33, 1),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Create Project Group', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Leads can create project groups for cross-functional initiatives.',
                    style: TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: nameCtrl,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Project Name',
                      hintText: 'e.g. Q4 Website Redesign',
                      hintStyle: TextStyle(color: Colors.grey[600]),
                      labelStyle: const TextStyle(color: Colors.grey),
                      filled: true,
                      fillColor: const Color.fromRGBO(24, 23, 23, 1),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Select Team Members:',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  StreamBuilder<List<Map<String, dynamic>>>(
                    stream: DBService.instance.streamFirmMembers(widget.firm.firmId),
                    builder: (context, snapshot) {
                      final members = snapshot.data ?? [];
                      if (members.isEmpty) {
                        return const Text('No colleagues found.', style: TextStyle(color: Colors.grey, fontSize: 12));
                      }

                      return ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: members.length,
                        itemBuilder: (context, index) {
                          final m = members[index];
                          final mUid = m['uid'] as String;
                          final isSelf = mUid == widget.uid;
                          final isChecked = selectedUids.contains(mUid);
                          final mName = m['name'] as String? ?? 'Colleague';

                          return CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              isSelf ? '$mName (You)' : mName,
                              style: const TextStyle(color: Colors.white, fontSize: 14),
                            ),
                            value: isChecked,
                            activeColor: Colors.purpleAccent,
                            onChanged: isSelf
                                ? null
                                : (val) {
                                    setDialogState(() {
                                      if (val == true) {
                                        selectedUids.add(mUid);
                                      } else {
                                        selectedUids.remove(mUid);
                                      }
                                    });
                                  },
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () async {
                final name = nameCtrl.text.trim();
                if (name.isEmpty) {
                  SnackbarService().showSnackbar('Please enter a project group name.', isError: true);
                  return;
                }
                Navigator.pop(dialogCtx);
                try {
                  final convId = await DBService.instance.createProjectGroup(
                    firmId: widget.firm.firmId,
                    name: name,
                    ownerUid: widget.uid,
                    participantIds: selectedUids.toList(),
                  );
                  SnackbarService().showSnackbar('Project group "$name" created successfully!');

                  if (context.mounted) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ChannelChatScreen(
                          channelType: ChannelType.project,
                          firmId: widget.firm.firmId,
                          conversationId: convId,
                          title: name,
                          uid: widget.uid,
                          userName: widget.userName,
                          projectId: convId,
                          projectOwnerUid: widget.uid,
                        ),
                      ),
                    );
                  }
                } catch (e) {
                  SnackbarService().showSnackbar('Error creating project: $e', isError: true);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple,
                foregroundColor: Colors.white,
              ),
              child: const Text('Create Project Group'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: DBService.instance.streamMember(widget.firm.firmId, widget.uid),
      builder: (context, memberSnapshot) {
        final memberData = memberSnapshot.data?.data() ?? {};
        final userRole = memberData['role'] as String? ?? 'employee';
        final departmentId = memberData['departmentId'] as String?;
        final isLeadOrAdmin = userRole == 'lead' || userRole == 'admin' || userRole == 'super_admin';

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
                  widget.firm.name,
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
            backgroundColor: isLeadOrAdmin ? Colors.purple : primaryColor,
            foregroundColor: Colors.white,
            tooltip: isLeadOrAdmin ? 'New conversation or project' : 'New conversation',
            child: Icon(isLeadOrAdmin ? Icons.add : Icons.chat),
            onPressed: () {
              if (isLeadOrAdmin) {
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
                          leading: const Icon(Icons.work_outline, color: Colors.purpleAccent),
                          title: const Text('Create New Project Group', style: TextStyle(color: Colors.white)),
                          subtitle: const Text('Initiate a project channel for select colleagues', style: TextStyle(color: Colors.grey, fontSize: 12)),
                          onTap: () {
                            Navigator.pop(ctx);
                            _showCreateProjectGroupDialog(context);
                          },
                        ),
                        ListTile(
                          leading: Icon(Icons.chat_bubble_outline, color: primaryColor),
                          title: const Text('Direct Message a Colleague', style: TextStyle(color: Colors.white)),
                          onTap: () {
                            Navigator.pop(ctx);
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const UserSearchPage()),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                );
              } else {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const UserSearchPage()),
                );
              }
            },
          ),
          body: StreamBuilder<QuerySnapshot>(
            stream: DBService.instance.streamConversations(widget.uid),
            builder: (context, directSnapshot) {
              if (directSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final directDocs = directSnapshot.data?.docs ?? [];

              return ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                children: [
                  // ── Role Upgrade Banner ───────────────────────────────────
                  if (userRole == 'lead')
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.purple.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.purpleAccent.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.star, color: Colors.purpleAccent, size: 20),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Lead Role Active',
                                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                                Text(
                                  'You can manage project groups and post in #all-staff. (Restart app if privileges newly granted)',
                                  style: TextStyle(color: Colors.grey, fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                  // ── CHANNELS SECTION ─────────────────────────────────────
                  const Padding(
                    padding: EdgeInsets.only(top: 4, bottom: 8, left: 4),
                    child: Text(
                      'Company Channels',
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),

                  // 1. #all-staff channel tile
                  _buildAllStaffChannelTile(context, primaryColor, userRole),
                  const SizedBox(height: 8),

                  // 2. Department Group Chat (Derived Access)
                  _buildDepartmentChannelTile(context, primaryColor, departmentId),
                  const SizedBox(height: 8),

                  // 3. General Team Chat (Legacy pinned channel)
                  _buildPinnedTile(context, primaryColor),

                  // ── PROJECT GROUPS SECTION ───────────────────────────────
                  Padding(
                    padding: const EdgeInsets.only(top: 18, bottom: 8, left: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Project Groups',
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ),
                        if (isLeadOrAdmin)
                          GestureDetector(
                            onTap: () => _showCreateProjectGroupDialog(context),
                            child: const Text(
                              '+ New Project',
                              style: TextStyle(
                                color: Colors.purpleAccent,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),

                  _buildProjectGroupsList(context, primaryColor),

                  // ── DIRECT MESSAGES SECTION ──────────────────────────────
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

                  if (directDocs.isEmpty)
                    _buildEmptyState(context, primaryColor)
                  else
                    ...directDocs.map((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      final String otherName = data['name'] as String? ?? 'Colleague';
                      final String otherImage = data['image'] as String? ?? '';
                      final String lastMessage = data['lastMessage'] as String? ?? '';
                      final int unseenCount = (data['unseenCount'] as num?)?.toInt() ?? 0;
                      final Timestamp? ts = data['timestamp'] as Timestamp?;
                      final String chatId = data['chatId'] as String? ?? doc.id;
                      final String otherUserId = _otherUid(chatId, widget.uid);

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
      },
    );
  }

  /// Pinned #all-staff Channel Tile
  Widget _buildAllStaffChannelTile(BuildContext context, Color primaryColor, String userRole) {
    return Container(
      decoration: BoxDecoration(
        color: const Color.fromRGBO(34, 33, 33, 1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.blueAccent.withOpacity(0.2)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
        leading: CircleAvatar(
          radius: 20,
          backgroundColor: Colors.blueAccent.withOpacity(0.2),
          child: const Icon(Icons.campaign, color: Colors.blueAccent, size: 20),
        ),
        title: Row(
          children: [
            const Text(
              '#all-staff',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.blueAccent.withOpacity(0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'COMPANY-WIDE',
                style: TextStyle(color: Colors.blueAccent, fontSize: 9, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        subtitle: const Text(
          'Official firm updates & notices (Admins & Leads post)',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: Colors.grey, fontSize: 12),
        ),
        trailing: const Icon(Icons.chevron_right, color: Colors.grey),
        onTap: () async {
          await DBService.instance.ensureAllStaffChannel(widget.firm.firmId);
          if (context.mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ChannelChatScreen(
                  channelType: ChannelType.allStaff,
                  firmId: widget.firm.firmId,
                  conversationId: 'all_staff',
                  title: '#all-staff',
                  subtitle: 'Official announcements',
                  uid: widget.uid,
                  userName: widget.userName,
                ),
              ),
            );
          }
        },
      ),
    );
  }

  /// Department Channel Tile (Derived access)
  Widget _buildDepartmentChannelTile(BuildContext context, Color primaryColor, String? departmentId) {
    if (departmentId == null || departmentId.isEmpty) {
      return Container(
        decoration: BoxDecoration(
          color: const Color.fromRGBO(34, 33, 33, 1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
          leading: CircleAvatar(
            radius: 20,
            backgroundColor: Colors.grey.withOpacity(0.15),
            child: const Icon(Icons.corporate_fare_outlined, color: Colors.grey, size: 20),
          ),
          title: const Text(
            'Department Chat',
            style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600, fontSize: 15),
          ),
          subtitle: const Text(
            'No department assigned yet by administrator',
            style: TextStyle(color: Colors.grey, fontSize: 12),
          ),
        ),
      );
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('Firms')
          .doc(widget.firm.firmId)
          .collection('departments')
          .doc(departmentId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return Container(
            margin: const EdgeInsets.symmetric(vertical: 2),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color.fromRGBO(34, 33, 33, 1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Center(
              child: SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }
        final data = snapshot.data?.data() ?? {};
        final name = data['name'] as String? ?? 'Department Chat';
        final convId = data['conversationId'] as String?;

        return Container(
          decoration: BoxDecoration(
            color: const Color.fromRGBO(34, 33, 33, 1),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: primaryColor.withOpacity(0.2)),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
            leading: CircleAvatar(
              radius: 20,
              backgroundColor: primaryColor.withOpacity(0.2),
              child: Icon(Icons.corporate_fare, color: primaryColor, size: 20),
            ),
            title: Row(
              children: [
                Flexible(
                  child: Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: primaryColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'DEPARTMENT',
                    style: TextStyle(color: primaryColor, fontSize: 9, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            subtitle: const Text(
              'Your team department channel',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
            trailing: const Icon(Icons.chevron_right, color: Colors.grey),
            onTap: (convId != null && convId.isNotEmpty)
                ? () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ChannelChatScreen(
                          channelType: ChannelType.department,
                          firmId: widget.firm.firmId,
                          conversationId: convId,
                          title: name,
                          subtitle: 'Department Channel',
                          uid: widget.uid,
                          userName: widget.userName,
                        ),
                      ),
                    );
                  }
                : null,
          ),
        );
      },
    );
  }

  /// Project Groups List
  Widget _buildProjectGroupsList(BuildContext context, Color primaryColor) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: DBService.instance.streamProjectConversationsForUser(widget.firm.firmId, widget.uid),
      builder: (context, snapshot) {
        final projects = snapshot.data ?? [];
        if (projects.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color.fromRGBO(34, 33, 33, 1),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withOpacity(0.04)),
            ),
            child: const Center(
              child: Text(
                'You are not a participant of any project groups yet.',
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ),
          );
        }

        return Column(
          children: projects.map((proj) {
            final convId = proj['conversationId'] as String;
            final name = proj['name'] as String? ?? 'Project';
            final lastMsg = proj['lastMessage'] as String? ?? '';
            final ownerUid = proj['ownerUid'] as String? ?? '';

            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color.fromRGBO(34, 33, 33, 1),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.purple.withOpacity(0.18)),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                  leading: CircleAvatar(
                    radius: 20,
                    backgroundColor: Colors.purple.withOpacity(0.2),
                    child: const Icon(Icons.work_outline, color: Colors.purpleAccent, size: 20),
                  ),
                  title: Row(
                    children: [
                      Flexible(
                        child: Text(
                          name,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.purple.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'PROJECT',
                          style: TextStyle(color: Colors.purpleAccent, fontSize: 9, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  subtitle: Text(
                    lastMsg.isNotEmpty ? lastMsg : 'No messages yet',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.grey[400], fontSize: 12),
                  ),
                  trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ChannelChatScreen(
                          channelType: ChannelType.project,
                          firmId: widget.firm.firmId,
                          conversationId: convId,
                          title: name,
                          subtitle: 'Project Group',
                          uid: widget.uid,
                          userName: widget.userName,
                          projectId: convId,
                          projectOwnerUid: ownerUid,
                        ),
                      ),
                    );
                  },
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildPinnedTile(BuildContext context, Color primaryColor) {
    return Container(
      decoration: BoxDecoration(
        color: const Color.fromRGBO(36, 35, 35, 1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: primaryColor.withOpacity(0.25), width: 1.2),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
        leading: CircleAvatar(
          radius: 20,
          backgroundColor: primaryColor.withOpacity(0.2),
          child: Icon(Icons.tag, color: primaryColor, size: 20),
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
                color: primaryColor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'OPEN',
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
          'Workspace-wide open discussion',
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
                firmId: widget.firm.firmId,
                uid: widget.uid,
                name: widget.userName,
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
          border: Border.all(color: Colors.white.withOpacity(0.04)),
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
          leading: CircleAvatar(
            radius: 22,
            backgroundColor: primaryColor.withOpacity(0.25),
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
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: primaryColor.withOpacity(0.15),
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
            'Message a colleague from your firm or reach out on #all-staff or Team Chat.',
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
