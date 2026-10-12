import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../models/firm.dart';
import '../../models/user.dart';
import '../../services/db_service.dart';
import '../../services/snackbar_service.dart';
import '../../widgets/chat/unified_chat_view.dart';

enum ChannelType { allStaff, department, project }

class ChannelChatScreen extends StatefulWidget {
  final ChannelType channelType;
  final String firmId;
  final String conversationId;
  final String title;
  final String? subtitle;
  final String uid;
  final String userName;
  final String? projectId;
  final String? projectOwnerUid;
  final String? departmentId;

  const ChannelChatScreen({
    super.key,
    required this.channelType,
    required this.firmId,
    required this.conversationId,
    required this.title,
    this.subtitle,
    required this.uid,
    required this.userName,
    this.projectId,
    this.projectOwnerUid,
    this.departmentId,
  });

  @override
  State<ChannelChatScreen> createState() => _ChannelChatScreenState();
}

class _ChannelChatScreenState extends State<ChannelChatScreen> {
  bool _canPost(String? userRole) {
    if (widget.channelType == ChannelType.allStaff) {
      final role = userRole?.toLowerCase();
      return role == 'admin' || role == 'super_admin' || role == 'lead';
    }
    return true;
  }

  void _showProjectParticipantsDialog() {
    if (widget.projectId == null) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color.fromRGBO(34, 33, 33, 1),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final isOwner = widget.projectOwnerUid == widget.uid;
        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('Firms')
              .doc(widget.firmId)
              .collection('projects')
              .doc(widget.projectId)
              .snapshots(),
          builder: (context, snapshot) {
            final data = snapshot.data?.data() ?? {};
            final participantIds = (data['participantIds'] as List<dynamic>?)
                    ?.map((e) => e.toString())
                    .toList() ??
                [];

            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Participants (${participantIds.length})',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (isOwner)
                          TextButton.icon(
                            icon: const Icon(Icons.person_add, size: 16),
                            label: const Text('Add Member'),
                            onPressed: () {
                              Navigator.pop(ctx);
                              _showAddParticipantDialog(participantIds);
                            },
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.of(context).size.height * 0.4,
                      ),
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: participantIds.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final pUid = participantIds[index];
                          final isProjectOwner = pUid == widget.projectOwnerUid;

                          return FutureBuilder<AppUser?>(
                            future: DBService.instance.getUserDetails(pUid),
                            builder: (context, userSnap) {
                              final name = userSnap.data?.name ?? pUid;
                              return ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: CircleAvatar(
                                  backgroundColor: Colors.purple.withOpacity(0.2),
                                  child: Text(
                                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                                    style: const TextStyle(color: Colors.purpleAccent),
                                  ),
                                ),
                                title: Row(
                                  children: [
                                    Text(name, style: const TextStyle(color: Colors.white)),
                                    if (isProjectOwner) ...[
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.purple.withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: const Text(
                                          'OWNER',
                                          style: TextStyle(
                                            color: Colors.purpleAccent,
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                trailing: (isOwner && !isProjectOwner)
                                    ? IconButton(
                                        icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent, size: 20),
                                        tooltip: 'Remove from project',
                                        onPressed: () async {
                                          final updated = List<String>.from(participantIds)..remove(pUid);
                                          await DBService.instance.updateProjectParticipants(
                                            firmId: widget.firmId,
                                            projectId: widget.projectId!,
                                            conversationId: widget.conversationId,
                                            participantIds: updated,
                                          );
                                          SnackbarService().showSnackbar('Removed $name from project.');
                                        },
                                      )
                                    : null,
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showAddParticipantDialog(List<String> currentParticipants) {
    showDialog(
      context: context,
      builder: (ctx) => StreamBuilder<List<Map<String, dynamic>>>(
        stream: DBService.instance.streamFirmMembers(widget.firmId),
        builder: (context, snapshot) {
          final allMembers = snapshot.data ?? [];
          final available = allMembers.where((m) => !currentParticipants.contains(m['uid'])).toList();

          return AlertDialog(
            backgroundColor: const Color.fromRGBO(34, 33, 33, 1),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text('Add Colleague to Project', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            content: available.isEmpty
                ? const Text('All active firm colleagues are already members of this project group.', style: TextStyle(color: Colors.grey))
                : SizedBox(
                    width: double.maxFinite,
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: available.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final m = available[index];
                        final mUid = m['uid'] as String;
                        final mName = m['name'] as String? ?? 'Colleague';

                        return ListTile(
                          title: Text(mName, style: const TextStyle(color: Colors.white)),
                          trailing: const Icon(Icons.add_circle_outline, color: Colors.purpleAccent),
                          onTap: () async {
                            Navigator.pop(ctx);
                            final updated = List<String>.from(currentParticipants)..add(mUid);
                            await DBService.instance.updateProjectParticipants(
                              firmId: widget.firmId,
                              projectId: widget.projectId!,
                              conversationId: widget.conversationId,
                              participantIds: updated,
                            );
                            SnackbarService().showSnackbar('Added $mName to project group.');
                          },
                        );
                      },
                    ),
                  ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Close', style: TextStyle(color: Colors.grey)),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;

    final UnifiedChatKind kind = switch (widget.channelType) {
      ChannelType.allStaff => UnifiedChatKind.allStaff,
      ChannelType.department => UnifiedChatKind.department,
      ChannelType.project => UnifiedChatKind.project,
    };

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: DBService.instance.streamMember(widget.firmId, widget.uid),
      builder: (context, memberSnap) {
        final memberData = memberSnap.data?.data() ?? {};
        final userRole = memberData['role'] as String? ?? 'employee';
        final canPost = _canPost(userRole);

        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance.collection('Firms').doc(widget.firmId).snapshots(),
          builder: (context, firmSnap) {
            Firm? firm;
            if (firmSnap.hasData && firmSnap.data!.exists) {
              firm = Firm.fromFirestore(firmSnap.data!);
            }

            return Stack(
              children: [
                UnifiedChatView(
                  kind: kind,
                  firmId: widget.firmId,
                  firm: firm,
                  conversationId: widget.conversationId,
                  title: widget.title,
                  subtitle: widget.subtitle,
                  currentUid: widget.uid,
                  currentUserName: widget.userName,
                  currentUserRole: userRole,
                  primaryColor: widget.channelType == ChannelType.project ? Colors.purpleAccent : primaryColor,
                  canPost: canPost,
                  projectOwnerUid: widget.projectOwnerUid,
                  departmentId: widget.departmentId,
                ),
                if (widget.channelType == ChannelType.project)
                  Positioned(
                    top: MediaQuery.of(context).padding.top + 4,
                    right: 8,
                    child: IconButton(
                      icon: const Icon(Icons.people_alt_outlined, color: Colors.white, size: 22),
                      tooltip: 'Project Participants',
                      onPressed: _showProjectParticipantsDialog,
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }
}
