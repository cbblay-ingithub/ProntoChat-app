import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../models/active_chat_selection.dart';
import '../../models/chat_polish_models.dart';
import '../../models/firm.dart';
import '../../screens/employee/channel_chat_screen.dart';
import '../../screens/employee/firm_chat_screen.dart';
import '../../screens/employee/mentions_screen.dart';
import '../../services/db_service.dart';
import '../../services/snackbar_service.dart';
import '../../theme/pc_tokens.dart';
import '../../widgets/chat/typing_indicator_widget.dart';
import '../../widgets/chat/unified_chat_view.dart';
import '../convo_page.dart';
import '../search_page.dart';

class EmployeeChatsTab extends StatefulWidget {
  final String uid;
  final String userName;
  final Firm firm;
  final bool isEmbeddedPane;
  final ActiveChatSelection? selectedChat;
  final ValueChanged<ActiveChatSelection>? onSelectChat;

  const EmployeeChatsTab({
    super.key,
    required this.uid,
    required this.userName,
    required this.firm,
    this.isEmbeddedPane = false,
    this.selectedChat,
    this.onSelectChat,
  });

  @override
  State<EmployeeChatsTab> createState() => _EmployeeChatsTabState();
}

class _EmployeeChatsTabState extends State<EmployeeChatsTab> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    DBService.instance.updatePresence(
      firmId: widget.firm.firmId,
      uid: widget.uid,
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _formatTimestamp(Timestamp? ts) {
    if (ts == null) return '';
    final dt = ts.toDate();
    final now = DateTime.now();
    final isToday =
        dt.year == now.year && dt.month == now.month && dt.day == now.day;
    final yesterday = now.subtract(const Duration(days: 1));
    final isYesterday = dt.year == yesterday.year &&
        dt.month == yesterday.month &&
        dt.day == yesterday.day;
    if (isToday) {
      final hour = dt.hour.toString().padLeft(2, '0');
      final minute = dt.minute.toString().padLeft(2, '0');
      return '$hour:$minute';
    } else if (isYesterday) {
      return 'Yesterday';
    } else {
      const months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      return '${dt.day} ${months[dt.month - 1]}';
    }
  }

  String _otherUid(String conversationId, String myUid) {
    final parts = conversationId.split('_');
    if (parts.length != 2) return '';
    return parts[0] == myUid ? parts[1] : parts[0];
  }

  bool _isSelected(UnifiedChatKind kind, String conversationId) {
    final sel = widget.selectedChat;
    if (sel == null) return false;
    return sel.kind == kind && sel.conversationId == conversationId;
  }

  Future<void> _showCreateProjectGroupDialog(BuildContext context) async {
    final tokens = context.pcTokens;
    final nameCtrl = TextEditingController();
    final Set<String> selectedUids = {widget.uid};

    await showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: tokens.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            'Create Project Group',
            style: TextStyle(
              color: tokens.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Leads can create project groups for cross-functional initiatives.',
                    style: TextStyle(color: tokens.textSecondary, fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: nameCtrl,
                    style: TextStyle(color: tokens.textPrimary),
                    decoration: InputDecoration(
                      labelText: 'Project Name',
                      hintText: 'e.g. Q4 Website Redesign',
                      hintStyle: TextStyle(color: tokens.textMuted),
                      labelStyle: TextStyle(color: tokens.textSecondary),
                      filled: true,
                      fillColor: tokens.surfaceSubtle,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: tokens.border),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Select Team Members:',
                    style: TextStyle(
                      color: tokens.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  StreamBuilder<List<Map<String, dynamic>>>(
                    stream: DBService.instance.streamFirmMembers(widget.firm.firmId),
                    builder: (context, snapshot) {
                      final members = snapshot.data ?? [];
                      if (members.isEmpty) {
                        return Text(
                          'No colleagues found.',
                          style: TextStyle(color: tokens.textMuted, fontSize: 12),
                        );
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
                              style: TextStyle(
                                color: tokens.textPrimary,
                                fontSize: 14,
                              ),
                            ),
                            value: isChecked,
                            activeColor: tokens.projectAccent,
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
              child: Text('Cancel', style: TextStyle(color: tokens.textSecondary)),
            ),
            ElevatedButton(
              onPressed: () async {
                final name = nameCtrl.text.trim();
                if (name.isEmpty) {
                  SnackbarService().showSnackbar(
                    'Please enter a project group name.',
                    isError: true,
                  );
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
                  SnackbarService().showSnackbar(
                    'Project group "$name" created successfully!',
                  );

                  if (widget.onSelectChat != null) {
                    widget.onSelectChat!(
                      ActiveChatSelection(
                        kind: UnifiedChatKind.project,
                        conversationId: convId,
                        title: name,
                        subtitle: 'Project Group',
                        projectId: convId,
                        projectOwnerUid: widget.uid,
                      ),
                    );
                  } else if (context.mounted) {
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
                  SnackbarService().showSnackbar(
                    'Error creating project: $e',
                    isError: true,
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: tokens.projectAccent,
                foregroundColor: Colors.white,
              ),
              child: const Text('Create Project Group'),
            ),
          ],
        ),
      ),
    );
  }

  void _openNewActionMenu(BuildContext context, bool isLeadOrAdmin, PcTokens tokens) {
    if (isLeadOrAdmin) {
      showModalBottomSheet(
        context: context,
        backgroundColor: tokens.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
        ),
        builder: (ctx) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Wrap(
              children: [
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: tokens.projectSoft,
                    child: Icon(
                      Icons.work_outline_rounded,
                      color: tokens.projectAccent,
                      size: 19,
                    ),
                  ),
                  title: Text(
                    'Create New Project Group',
                    style: TextStyle(
                      color: tokens.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    'Initiate a project channel for select colleagues',
                    style: TextStyle(color: tokens.textMuted, fontSize: 12),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _showCreateProjectGroupDialog(context);
                  },
                ),
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: tokens.primarySoft,
                    child: Icon(
                      Icons.chat_bubble_outline_rounded,
                      color: tokens.primary,
                      size: 19,
                    ),
                  ),
                  title: Text(
                    'Direct Message a Colleague',
                    style: TextStyle(
                      color: tokens.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
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
        ),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const UserSearchPage()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.pcTokens;
    final primaryColor = tokens.primary;
    final paneBg = widget.isEmbeddedPane ? tokens.sidebarBg : tokens.canvas;

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: DBService.instance.streamMember(widget.firm.firmId, widget.uid),
      builder: (context, memberSnapshot) {
        final memberData = memberSnapshot.data?.data() ?? {};
        final userRole = memberData['role'] as String? ?? 'employee';
        final departmentId = memberData['departmentId'] as String?;
        final isLeadOrAdmin = userRole == 'lead' ||
            userRole == 'admin' ||
            userRole == 'super_admin';

        return Scaffold(
          backgroundColor: paneBg,
          appBar: AppBar(
            backgroundColor: widget.isEmbeddedPane ? tokens.sidebarBg : tokens.surface,
            elevation: 0,
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(1),
              child: Divider(height: 1, color: tokens.border),
            ),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Conversations',
                  style: TextStyle(
                    color: tokens.textPrimary,
                    fontSize: widget.isEmbeddedPane ? 16.5 : 19,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  widget.firm.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: tokens.textMuted, fontSize: 11.5),
                ),
              ],
            ),
            actions: [
              if (!widget.isEmbeddedPane)
                StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: DBService.instance.streamUnreadMentions(
                    firmId: widget.firm.firmId,
                    uid: widget.uid,
                  ),
                  builder: (context, snap) {
                    final unreadCount = snap.data?.docs.length ?? 0;
                    return IconButton(
                      tooltip: 'Mentions Inbox',
                      icon: Badge(
                        isLabelVisible: unreadCount > 0,
                        label: Text(
                          '$unreadCount',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        backgroundColor: tokens.warningAccent,
                        textColor: Colors.white,
                        child: Icon(
                          Icons.alternate_email_rounded,
                          color: tokens.textSecondary,
                        ),
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => MentionsScreen(
                              firmId: widget.firm.firmId,
                              uid: widget.uid,
                              userName: widget.userName,
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              IconButton(
                icon: Icon(
                  widget.isEmbeddedPane ? Icons.edit_square : Icons.search_rounded,
                  color: tokens.textSecondary,
                  size: widget.isEmbeddedPane ? 20 : 22,
                ),
                tooltip: widget.isEmbeddedPane
                    ? 'New conversation or project'
                    : 'Search messages or people',
                onPressed: () {
                  if (widget.isEmbeddedPane) {
                    _openNewActionMenu(context, isLeadOrAdmin, tokens);
                  } else {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const UserSearchPage()),
                    );
                  }
                },
              ),
              const SizedBox(width: 4),
            ],
          ),
          floatingActionButton: widget.isEmbeddedPane
              ? null
              : FloatingActionButton(
                  backgroundColor: isLeadOrAdmin ? tokens.projectAccent : primaryColor,
                  foregroundColor: Colors.white,
                  elevation: 2,
                  tooltip: isLeadOrAdmin
                      ? 'New conversation or project'
                      : 'New conversation',
                  child: Icon(isLeadOrAdmin ? Icons.add_rounded : Icons.chat_rounded),
                  onPressed: () => _openNewActionMenu(context, isLeadOrAdmin, tokens),
                ),
          body: StreamBuilder<QuerySnapshot>(
            stream: DBService.instance.streamConversations(widget.uid),
            builder: (context, directSnapshot) {
              if (directSnapshot.connectionState == ConnectionState.waiting) {
                return Center(
                  child: CircularProgressIndicator(color: primaryColor),
                );
              }

              final directDocs = directSnapshot.data?.docs ?? [];
              final filteredDirect = _searchQuery.isEmpty
                  ? directDocs
                  : directDocs.where((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      final String otherName =
                          (data['name'] as String? ?? '').toLowerCase();
                      final String lastMessage =
                          (data['lastMessage'] as String? ?? '').toLowerCase();
                      return otherName.contains(_searchQuery) ||
                          lastMessage.contains(_searchQuery);
                    }).toList();

              final showAllStaff = _searchQuery.isEmpty ||
                  '#all-staff'.contains(_searchQuery) ||
                  'all staff'.contains(_searchQuery) ||
                  'official firm updates'.contains(_searchQuery);
              final showDept = _searchQuery.isEmpty ||
                  'department'.contains(_searchQuery) ||
                  (departmentId != null &&
                      departmentId.toLowerCase().contains(_searchQuery));
              final showGeneral = _searchQuery.isEmpty ||
                  'general team chat'.contains(_searchQuery) ||
                  'open discussion'.contains(_searchQuery);

              return ListView(
                padding: EdgeInsets.symmetric(
                  horizontal: widget.isEmbeddedPane ? 10 : 16,
                  vertical: 10,
                ),
                children: [
                  // Filter Input
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: tokens.surface,
                      borderRadius: BorderRadius.circular(11),
                      border: Border.all(color: tokens.border),
                    ),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (val) =>
                          setState(() => _searchQuery = val.trim().toLowerCase()),
                      style: TextStyle(color: tokens.textPrimary, fontSize: 13.5),
                      decoration: InputDecoration(
                        hintText: 'Filter conversations...',
                        hintStyle: TextStyle(color: tokens.textMuted, fontSize: 13),
                        prefixIcon: Icon(
                          Icons.search_rounded,
                          color: tokens.textMuted,
                          size: 18,
                        ),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: Icon(
                                  Icons.clear_rounded,
                                  color: tokens.textMuted,
                                  size: 16,
                                ),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _searchQuery = '');
                                },
                              )
                            : null,
                        filled: false,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                      ),
                    ),
                  ),

                  // Lead Role Banner
                  if (userRole == 'lead' &&
                      _searchQuery.isEmpty &&
                      !widget.isEmbeddedPane)
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: tokens.projectSoft,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: tokens.projectAccent.withValues(alpha: 0.25),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.star_rounded,
                            color: tokens.projectAccent,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Lead Role Active',
                                  style: TextStyle(
                                    color: tokens.textPrimary,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                  ),
                                ),
                                Text(
                                  'You can manage project groups and post in #all-staff.',
                                  style: TextStyle(
                                    color: tokens.textSecondary,
                                    fontSize: 11.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                  // CHANNELS SECTION
                  if (showAllStaff || showDept || showGeneral) ...[
                    _SectionHeader(
                      label: 'COMPANY CHANNELS',
                      tokens: tokens,
                    ),
                    if (showAllStaff) ...[
                      _buildAllStaffChannelTile(context, tokens),
                      const SizedBox(height: 6),
                    ],
                    if (showDept) ...[
                      _buildDepartmentChannelTile(context, tokens, departmentId),
                      const SizedBox(height: 6),
                    ],
                    if (showGeneral) _buildGeneralTile(context, tokens),
                  ],

                  // PROJECT GROUPS SECTION
                  Padding(
                    padding: const EdgeInsets.only(top: 16, bottom: 6, left: 4, right: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'PROJECT GROUPS',
                          style: TextStyle(
                            color: tokens.textMuted,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.6,
                          ),
                        ),
                        if (isLeadOrAdmin)
                          InkWell(
                            onTap: () => _showCreateProjectGroupDialog(context),
                            borderRadius: BorderRadius.circular(6),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                              child: Text(
                                '+ New',
                                style: TextStyle(
                                  color: tokens.projectAccent,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),

                  _buildProjectGroupsList(context, tokens, searchQuery: _searchQuery),

                  // DIRECT MESSAGES SECTION
                  Padding(
                    padding: const EdgeInsets.only(top: 16, bottom: 6),
                    child: _SectionHeader(
                      label: 'DIRECT MESSAGES',
                      tokens: tokens,
                    ),
                  ),

                  if (filteredDirect.isEmpty)
                    _searchQuery.isNotEmpty
                        ? Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: tokens.surface,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: tokens.border),
                            ),
                            child: Center(
                              child: Text(
                                'No direct conversations matching "$_searchQuery".',
                                style: TextStyle(
                                  color: tokens.textMuted,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          )
                        : _buildEmptyState(context, tokens)
                  else
                    ...filteredDirect.map((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      final String otherName =
                          data['name'] as String? ?? 'Colleague';
                      final String otherImage = data['image'] as String? ?? '';
                      final String lastMessage =
                          data['lastMessage'] as String? ?? '';
                      final int unseenCount =
                          (data['unseenCount'] as num?)?.toInt() ?? 0;
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
                        tokens: tokens,
                      );
                    }),
                  const SizedBox(height: 24),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildAllStaffChannelTile(BuildContext context, PcTokens tokens) {
    final selected = _isSelected(UnifiedChatKind.allStaff, 'all_staff');

    return _SidebarTileContainer(
      selected: selected,
      tokens: tokens,
      child: ListTile(
        dense: widget.isEmbeddedPane,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        leading: CircleAvatar(
          radius: 18,
          backgroundColor: tokens.infoSoft,
          child: Icon(Icons.campaign_rounded, color: tokens.infoAccent, size: 18),
        ),
        title: Row(
          children: [
            Flexible(
              child: Text(
                '#all-staff',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: selected ? tokens.primary : tokens.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
              decoration: BoxDecoration(
                color: tokens.infoSoft,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'COMPANY',
                style: TextStyle(
                  color: tokens.infoAccent,
                  fontSize: 8.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        subtitle: Text(
          'Official firm updates & notices',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: tokens.textMuted, fontSize: 11.5),
        ),
        onTap: () async {
          await DBService.instance.ensureAllStaffChannel(widget.firm.firmId);
          if (!context.mounted) return;
          if (widget.onSelectChat != null) {
            widget.onSelectChat!(ActiveChatSelection.allStaff());
            return;
          }
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
        },
      ),
    );
  }

  Widget _buildDepartmentChannelTile(
    BuildContext context,
    PcTokens tokens,
    String? departmentId,
  ) {
    if (departmentId == null || departmentId.isEmpty) {
      return _SidebarTileContainer(
        selected: false,
        tokens: tokens,
        child: ListTile(
          dense: widget.isEmbeddedPane,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          leading: CircleAvatar(
            radius: 18,
            backgroundColor: tokens.surfaceSubtle,
            child: Icon(
              Icons.corporate_fare_outlined,
              color: tokens.textMuted,
              size: 18,
            ),
          ),
          title: Text(
            'Department Chat',
            style: TextStyle(
              color: tokens.textSecondary,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          subtitle: Text(
            'No department assigned yet',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: tokens.textMuted, fontSize: 11.5),
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
        final data = snapshot.data?.data() ?? {};
        final name = data['name'] as String? ?? 'Department Chat';
        final convId = data['conversationId'] as String?;
        final selected =
            convId != null && _isSelected(UnifiedChatKind.department, convId);

        return _SidebarTileContainer(
          selected: selected,
          tokens: tokens,
          child: ListTile(
            dense: widget.isEmbeddedPane,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
            leading: CircleAvatar(
              radius: 18,
              backgroundColor: tokens.primarySoft,
              child: Icon(
                Icons.corporate_fare_rounded,
                color: tokens.primary,
                size: 18,
              ),
            ),
            title: Row(
              children: [
                Flexible(
                  child: Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: selected ? tokens.primary : tokens.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: tokens.primarySoft,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'DEPT',
                    style: TextStyle(
                      color: tokens.primary,
                      fontSize: 8.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            subtitle: Text(
              'Your team department channel',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: tokens.textMuted, fontSize: 11.5),
            ),
            onTap: (convId != null && convId.isNotEmpty)
                ? () {
                    if (widget.onSelectChat != null) {
                      widget.onSelectChat!(
                        ActiveChatSelection(
                          kind: UnifiedChatKind.department,
                          conversationId: convId,
                          title: name,
                          subtitle: 'Department Channel',
                          departmentId: departmentId,
                        ),
                      );
                      return;
                    }
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
                          departmentId: departmentId,
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

  Widget _buildGeneralTile(BuildContext context, PcTokens tokens) {
    final selected = _isSelected(UnifiedChatKind.general, widget.firm.firmId);

    return _SidebarTileContainer(
      selected: selected,
      tokens: tokens,
      child: ListTile(
        dense: widget.isEmbeddedPane,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        leading: CircleAvatar(
          radius: 18,
          backgroundColor: tokens.primarySoft,
          child: Icon(Icons.tag_rounded, color: tokens.primary, size: 18),
        ),
        title: Row(
          children: [
            Flexible(
              child: Text(
                'General Team Chat',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: selected ? tokens.primary : tokens.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
              decoration: BoxDecoration(
                color: tokens.primarySoft,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'OPEN',
                style: TextStyle(
                  color: tokens.primary,
                  fontSize: 8.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        subtitle: Text(
          'Workspace-wide open discussion',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: tokens.textMuted, fontSize: 11.5),
        ),
        onTap: () {
          if (widget.onSelectChat != null) {
            widget.onSelectChat!(
              ActiveChatSelection.general(widget.firm.firmId, widget.firm.name),
            );
            return;
          }
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

  Widget _buildProjectGroupsList(
    BuildContext context,
    PcTokens tokens, {
    String searchQuery = '',
  }) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: DBService.instance
          .streamProjectConversationsForUser(widget.firm.firmId, widget.uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Center(
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: tokens.projectAccent,
                ),
              ),
            ),
          );
        }

        var projects = snapshot.data ?? [];
        if (searchQuery.isNotEmpty) {
          projects = projects.where((proj) {
            final name = (proj['name'] as String? ?? '').toLowerCase();
            final lastMsg = (proj['lastMessage'] as String? ?? '').toLowerCase();
            return name.contains(searchQuery) || lastMsg.contains(searchQuery);
          }).toList();
        }

        if (projects.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: tokens.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: tokens.border),
            ),
            child: Center(
              child: Text(
                searchQuery.isNotEmpty
                    ? 'No project groups matching "$searchQuery".'
                    : 'No active project groups yet.',
                style: TextStyle(color: tokens.textMuted, fontSize: 12),
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
            final selected = _isSelected(UnifiedChatKind.project, convId);

            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: _SidebarTileContainer(
                selected: selected,
                tokens: tokens,
                child: ListTile(
                  dense: widget.isEmbeddedPane,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                  leading: CircleAvatar(
                    radius: 18,
                    backgroundColor: tokens.projectSoft,
                    child: Icon(
                      Icons.work_outline_rounded,
                      color: tokens.projectAccent,
                      size: 18,
                    ),
                  ),
                  title: Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: selected ? tokens.projectAccent : tokens.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  subtitle: Text(
                    lastMsg.isNotEmpty ? lastMsg : 'No messages yet',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: tokens.textMuted, fontSize: 11.5),
                  ),
                  onTap: () {
                    if (widget.onSelectChat != null) {
                      widget.onSelectChat!(
                        ActiveChatSelection(
                          kind: UnifiedChatKind.project,
                          conversationId: convId,
                          title: name,
                          subtitle: 'Project Group',
                          projectId: convId,
                          projectOwnerUid: ownerUid,
                        ),
                      );
                      return;
                    }
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

  Widget _buildConversationTile({
    required BuildContext context,
    required String chatId,
    required String otherUserId,
    required String name,
    required String image,
    required String lastMessage,
    required int unseenCount,
    bool hasMention = false,
    required Timestamp? ts,
    required PcTokens tokens,
  }) {
    final selected = _isSelected(UnifiedChatKind.direct, chatId);

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: _SidebarTileContainer(
        selected: selected,
        tokens: tokens,
        child: ListTile(
          dense: widget.isEmbeddedPane,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          leading: Stack(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: tokens.primarySoft,
                backgroundImage: image.isNotEmpty ? NetworkImage(image) : null,
                child: image.isEmpty
                    ? Text(
                        name.isNotEmpty ? name[0].toUpperCase() : '?',
                        style: TextStyle(
                          color: tokens.primary,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      )
                    : null,
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: StreamBuilder<UserPresence?>(
                  stream: DBService.instance
                      .streamPresence(widget.firm.firmId, otherUserId),
                  builder: (context, presSnap) {
                    final isOnline = presSnap.data?.isOnline == true;
                    if (!isOnline) return const SizedBox.shrink();
                    return Container(
                      width: 11,
                      height: 11,
                      decoration: BoxDecoration(
                        color: tokens.online,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: tokens.surface,
                          width: 2.0,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
          title: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: selected ? tokens.primary : tokens.textPrimary,
              fontWeight:
                  unseenCount > 0 || selected ? FontWeight.w700 : FontWeight.w600,
              fontSize: 14,
            ),
          ),
          subtitle: StreamBuilder<List<TypingIndicatorStatus>>(
            stream: DBService.instance.streamTyping(conversationId: chatId),
            builder: (context, typeSnap) {
              final isTyping = (typeSnap.data ?? [])
                  .any((t) => t.uid != widget.uid && t.isActive);
              if (isTyping) {
                return Row(
                  children: [
                    BouncingDots(color: tokens.primary, dotSize: 3.5),
                    const SizedBox(width: 5),
                    Text(
                      'typing...',
                      style: TextStyle(
                        color: tokens.primary,
                        fontWeight: FontWeight.w600,
                        fontStyle: FontStyle.italic,
                        fontSize: 12,
                      ),
                    ),
                  ],
                );
              }
              return Text(
                lastMessage.isNotEmpty ? lastMessage : 'No messages yet',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: unseenCount > 0 ? tokens.textPrimary : tokens.textMuted,
                  fontWeight:
                      unseenCount > 0 ? FontWeight.w600 : FontWeight.normal,
                  fontSize: 12,
                ),
              );
            },
          ),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _formatTimestamp(ts),
                style: TextStyle(
                  color: unseenCount > 0 ? tokens.primary : tokens.textMuted,
                  fontSize: 10.5,
                  fontWeight:
                      unseenCount > 0 ? FontWeight.w700 : FontWeight.normal,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (hasMention)
                    Container(
                      margin: const EdgeInsets.only(right: 4),
                      padding:
                          const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: tokens.warningSoft,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '@',
                        style: TextStyle(
                          color: tokens.warningAccent,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  if (unseenCount > 0)
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 6.5, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: tokens.primary,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        unseenCount > 99 ? '99+' : '$unseenCount',
                        style: TextStyle(
                          color: tokens.onPrimary,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    )
                  else if (!hasMention)
                    const SizedBox(height: 15),
                ],
              ),
            ],
          ),
          onTap: () {
            if (widget.onSelectChat != null) {
              widget.onSelectChat!(
                ActiveChatSelection(
                  kind: UnifiedChatKind.direct,
                  conversationId: chatId,
                  title: name,
                  otherUserId: otherUserId,
                  otherUserImage: image,
                ),
              );
              return;
            }
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ChatPage(
                  conversationId: chatId,
                  otherUserId: otherUserId,
                  otherUserName: name,
                  otherUserImage: image,
                  firmId: widget.firm.firmId,
                  firm: widget.firm,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, PcTokens tokens) {
    return Container(
      padding: EdgeInsets.symmetric(
        vertical: widget.isEmbeddedPane ? 24 : 34,
        horizontal: 16,
      ),
      margin: const EdgeInsets.only(top: 6),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: tokens.border),
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: tokens.primarySoft,
            child: Icon(Icons.people_outline_rounded, color: tokens.primary, size: 24),
          ),
          const SizedBox(height: 12),
          Text(
            'No Direct Chats Yet',
            style: TextStyle(
              color: tokens.textPrimary,
              fontSize: 14.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Message a colleague from your firm or join #all-staff.',
            textAlign: TextAlign.center,
            style: TextStyle(color: tokens.textMuted, fontSize: 12),
          ),
          const SizedBox(height: 14),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: tokens.primary,
              foregroundColor: tokens.onPrimary,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            icon: const Icon(Icons.add_comment_rounded, size: 16),
            label: const Text(
              'Start Conversation',
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
            ),
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

class _SectionHeader extends StatelessWidget {
  final String label;
  final PcTokens tokens;

  const _SectionHeader({required this.label, required this.tokens});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 6, left: 4),
      child: Text(
        label,
        style: TextStyle(
          color: tokens.textMuted,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

class _SidebarTileContainer extends StatelessWidget {
  final bool selected;
  final PcTokens tokens;
  final Widget child;

  const _SidebarTileContainer({
    required this.selected,
    required this.tokens,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: selected ? tokens.primarySoft : tokens.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: selected ? tokens.primaryBorder : tokens.border,
          width: selected ? 1.2 : 1.0,
        ),
      ),
      child: child,
    );
  }
}
