import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../models/active_chat_selection.dart';
import '../../models/firm.dart';
import '../../services/db_service.dart';
import '../../theme/pc_tokens.dart';
import '../../widgets/chat/unified_chat_view.dart';
import '../../widgets/common/pc_avatar.dart';
import '../convo_page.dart';

class EmployeeDirectoryTab extends StatefulWidget {
  final String uid;
  final String userName;
  final String? userImage;
  final Firm firm;
  final bool isWideLayout;
  final bool isCompactInspector;
  final ValueChanged<ActiveChatSelection>? onOpenDirectChat;

  const EmployeeDirectoryTab({
    super.key,
    required this.uid,
    required this.userName,
    this.userImage,
    required this.firm,
    this.isWideLayout = false,
    this.isCompactInspector = false,
    this.onOpenDirectChat,
  });

  @override
  State<EmployeeDirectoryTab> createState() => _EmployeeDirectoryTabState();
}

class _EmployeeDirectoryTabState extends State<EmployeeDirectoryTab> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String? _loadingUid;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _startDirectChat(Map<String, dynamic> colleague) async {
    final otherUid = colleague['uid'] as String? ?? '';
    final otherName = colleague['name'] as String? ?? 'Colleague';
    final otherImage =
        colleague['avatarUrl'] as String? ?? colleague['image'] as String? ?? '';

    if (otherUid.isEmpty) return;

    setState(() => _loadingUid = otherUid);

    try {
      final conversationId = await DBService.instance.createConversation(
        currentUid: widget.uid,
        otherUid: otherUid,
        currentUserName: widget.userName,
        currentUserImage: widget.userImage ?? '',
        otherUserName: otherName,
        otherUserImage: otherImage,
      );

      if (!mounted) return;

      if (widget.onOpenDirectChat != null) {
        widget.onOpenDirectChat!(
          ActiveChatSelection(
            kind: UnifiedChatKind.direct,
            conversationId: conversationId,
            title: otherName,
            otherUserId: otherUid,
            otherUserImage: otherImage,
          ),
        );
        return;
      }

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatPage(
            conversationId: conversationId,
            otherUserId: otherUid,
            otherUserName: otherName,
            otherUserImage: otherImage,
            firmId: widget.firm.firmId,
            firm: widget.firm,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not start conversation: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _loadingUid = null);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.pcTokens;
    final primaryColor = tokens.primary;
    final bgColor = widget.isCompactInspector ? tokens.sidebarBg : tokens.canvas;

    Widget content = Column(
      children: [
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: widget.isCompactInspector ? 12 : 16,
            vertical: 12,
          ),
          child: TextField(
            controller: _searchController,
            style: TextStyle(color: tokens.textPrimary, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Search colleagues by name or role...',
              hintStyle: TextStyle(color: tokens.textMuted, fontSize: 13.5),
              prefixIcon: Icon(
                Icons.search_rounded,
                color: tokens.textMuted,
                size: 20,
              ),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: Icon(
                        Icons.clear_rounded,
                        color: tokens.textMuted,
                        size: 18,
                      ),
                      onPressed: () => _searchController.clear(),
                    )
                  : null,
              filled: true,
              fillColor: tokens.surface,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: tokens.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: tokens.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: primaryColor, width: 1.5),
              ),
            ),
          ),
        ),
        Expanded(
          child: StreamBuilder<List<Map<String, dynamic>>>(
            stream: DBService.instance.streamFirmMembers(widget.firm.firmId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(
                  child: CircularProgressIndicator(color: primaryColor),
                );
              }

              var members = snapshot.data ?? [];
              members = members.where((m) => m['uid'] != widget.uid).toList();

              if (_searchQuery.isNotEmpty) {
                members = members.where((m) {
                  final name = (m['name'] as String? ?? '').toLowerCase();
                  final role = (m['role'] as String? ?? '').toLowerCase();
                  final title = (m['jobTitle'] as String? ?? '').toLowerCase();
                  return name.contains(_searchQuery) ||
                      role.contains(_searchQuery) ||
                      title.contains(_searchQuery);
                }).toList();
              }

              if (members.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.person_search_rounded,
                          size: 46,
                          color: tokens.textMuted,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _searchQuery.isNotEmpty
                              ? 'No colleagues found matching "$_searchQuery".'
                              : 'No other colleagues registered in this firm yet.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: tokens.textMuted, fontSize: 13.5),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return ListView.builder(
                padding: EdgeInsets.symmetric(
                  horizontal: widget.isCompactInspector ? 12 : 16,
                  vertical: 4,
                ),
                itemCount: members.length,
                itemBuilder: (context, index) {
                  final colleague = members[index];
                  final String name =
                      colleague['name'] as String? ?? 'Colleague';
                  final String role =
                      colleague['role'] as String? ?? 'employee';
                  final String jobTitle = colleague['jobTitle'] as String? ??
                      (role == 'admin' ? 'Firm Admin' : 'Employee');
                  final String avatarUrl =
                      colleague['avatarUrl'] as String? ??
                          colleague['image'] as String? ??
                          '';
                  final String colUid = colleague['uid'] as String? ?? '';
                  final bool isStarting = _loadingUid == colUid;

                  MediaRef? colAvatar;
                  if (colleague['avatar'] is Map) {
                    colAvatar = MediaRef.fromMap(
                      Map<String, dynamic>.from(colleague['avatar'] as Map),
                    );
                  }

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: EdgeInsets.symmetric(
                      horizontal: widget.isCompactInspector ? 10 : 14,
                      vertical: 11,
                    ),
                    decoration: BoxDecoration(
                      color: tokens.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: tokens.border),
                    ),
                    child: Row(
                      children: [
                        PcAvatar(
                          avatar: colAvatar,
                          legacyUrl: avatarUrl,
                          name: name,
                          radius: widget.isCompactInspector ? 18 : 21,
                          backgroundColor: tokens.primarySoft,
                          foregroundColor: primaryColor,
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
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: tokens.textPrimary,
                                        fontSize:
                                            widget.isCompactInspector ? 13.5 : 14.5,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  if (role == 'lead') ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 5,
                                        vertical: 1,
                                      ),
                                      decoration: BoxDecoration(
                                        color: tokens.projectSoft,
                                        borderRadius: BorderRadius.circular(5),
                                      ),
                                      child: Text(
                                        'LEAD',
                                        style: TextStyle(
                                          color: tokens.projectAccent,
                                          fontSize: 8.5,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                  ],
                                  if (role == 'admin' ||
                                      role == 'super_admin') ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 5,
                                        vertical: 1,
                                      ),
                                      decoration: BoxDecoration(
                                        color: tokens.warningSoft,
                                        borderRadius: BorderRadius.circular(5),
                                      ),
                                      child: Text(
                                        'ADMIN',
                                        style: TextStyle(
                                          color: tokens.warningAccent,
                                          fontSize: 8.5,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      jobTitle,
                                      style: TextStyle(
                                        color: tokens.textMuted,
                                        fontSize: 12,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (colleague['departmentId'] != null &&
                                      (colleague['departmentId'] as String)
                                          .isNotEmpty)
                                    StreamBuilder<
                                        DocumentSnapshot<Map<String, dynamic>>>(
                                      stream: FirebaseFirestore.instance
                                          .collection('Firms')
                                          .doc(widget.firm.firmId)
                                          .collection('departments')
                                          .doc(colleague['departmentId'] as String)
                                          .snapshots(),
                                      builder: (ctx, dSnap) {
                                        final dName =
                                            dSnap.data?.data()?['name'] as String?;
                                        if (dName == null || dName.isEmpty) {
                                          return const SizedBox.shrink();
                                        }
                                        return Text(
                                          ' • $dName',
                                          style: TextStyle(
                                            color: primaryColor,
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        );
                                      },
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        widget.isCompactInspector
                            ? IconButton(
                                tooltip: 'Message $name',
                                icon: isStarting
                                    ? SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: primaryColor,
                                        ),
                                      )
                                    : Icon(
                                        Icons.chat_bubble_outline_rounded,
                                        size: 18,
                                        color: primaryColor,
                                      ),
                                onPressed: isStarting
                                    ? null
                                    : () => _startDirectChat(colleague),
                              )
                            : ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: tokens.primarySoft,
                                  foregroundColor: primaryColor,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 13,
                                    vertical: 8,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    side: BorderSide(color: tokens.primaryBorder),
                                  ),
                                ),
                                onPressed: isStarting
                                    ? null
                                    : () => _startDirectChat(colleague),
                                child: isStarting
                                    ? SizedBox(
                                        width: 14,
                                        height: 14,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: primaryColor,
                                        ),
                                      )
                                    : const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.chat_bubble_outline_rounded,
                                            size: 14,
                                          ),
                                          SizedBox(width: 5),
                                          Text(
                                            'Message',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                              ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );

    if (widget.isWideLayout && !widget.isCompactInspector) {
      content = Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 880),
          child: content,
        ),
      );
    }

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: widget.isCompactInspector ? tokens.sidebarBg : tokens.surface,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: tokens.border),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Staff Directory',
              style: TextStyle(
                color: tokens.textPrimary,
                fontSize: widget.isCompactInspector ? 15.5 : 19,
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
      ),
      body: content,
    );
  }
}
