import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../models/chat_message.dart';
import '../../models/user.dart';
import '../../services/db_service.dart';
import '../../services/snackbar_service.dart';

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
  });

  @override
  State<ChannelChatScreen> createState() => _ChannelChatScreenState();
}

class _ChannelChatScreenState extends State<ChannelChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isSending = false;

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  bool _canPost(String? userRole) {
    if (widget.channelType == ChannelType.allStaff) {
      final role = userRole?.toLowerCase();
      return role == 'admin' || role == 'super_admin' || role == 'lead';
    }
    return true;
  }

  Future<void> _handleSendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isSending) return;

    setState(() => _isSending = true);
    _messageController.clear();

    try {
      if (widget.channelType == ChannelType.allStaff) {
        await DBService.instance.sendAllStaffMessage(
          firmId: widget.firmId,
          senderId: widget.uid,
          senderName: widget.userName,
          text: text,
        );
      } else if (widget.channelType == ChannelType.department) {
        await DBService.instance.sendDepartmentMessage(
          firmId: widget.firmId,
          conversationId: widget.conversationId,
          senderId: widget.uid,
          senderName: widget.userName,
          text: text,
        );
      } else if (widget.channelType == ChannelType.project) {
        await DBService.instance.sendProjectMessage(
          firmId: widget.firmId,
          conversationId: widget.conversationId,
          senderId: widget.uid,
          senderName: widget.userName,
          text: text,
        );
      }
      _scrollToBottom();
    } catch (e) {
      _messageController.text = text;
      SnackbarService().showSnackbar('Failed to send message: ${e.toString()}', isError: true);
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0.0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
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
                            SnackbarService().showSnackbar('Added $mName to project.');
                          },
                        );
                      },
                    ),
                  ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close', style: TextStyle(color: Colors.grey))),
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

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: DBService.instance.streamMember(widget.firmId, widget.uid),
      builder: (context, memberSnap) {
        final memberData = memberSnap.data?.data();
        final userRole = memberData?['role'] as String? ?? 'employee';
        final canPost = _canPost(userRole);

        return Scaffold(
          backgroundColor: const Color.fromRGBO(28, 27, 27, 1),
          appBar: AppBar(
            backgroundColor: const Color.fromRGBO(28, 27, 27, 1),
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: widget.channelType == ChannelType.project
                      ? Colors.purple.withOpacity(0.2)
                      : primaryColor.withOpacity(0.2),
                  child: Icon(
                    widget.channelType == ChannelType.project
                        ? Icons.work_outline
                        : (widget.channelType == ChannelType.department ? Icons.folder_shared : Icons.tag),
                    color: widget.channelType == ChannelType.project ? Colors.purpleAccent : primaryColor,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        widget.subtitle ??
                            (widget.channelType == ChannelType.allStaff
                                ? 'Announcement Channel'
                                : (widget.channelType == ChannelType.department ? 'Department Chat' : 'Project Group')),
                        style: TextStyle(color: Colors.grey[400], fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              if (widget.channelType == ChannelType.project)
                IconButton(
                  icon: const Icon(Icons.people_alt_outlined, color: Colors.white),
                  tooltip: 'Project Participants',
                  onPressed: _showProjectParticipantsDialog,
                ),
            ],
          ),
          body: Column(
            children: [
              // Notice banner if user cannot post in allStaff
              if (widget.channelType == ChannelType.allStaff && !canPost)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  color: Colors.amber.withOpacity(0.12),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, color: Colors.amberAccent, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Only Admins and Leads can post announcements in #all-staff.',
                          style: TextStyle(color: Colors.amber[200], fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),

              // Messages list stream
              Expanded(
                child: StreamBuilder<List<ChatMessage>>(
                  stream: widget.channelType == ChannelType.allStaff
                      ? DBService.instance.streamAllStaffMessages(widget.firmId)
                      : (widget.channelType == ChannelType.department
                          ? DBService.instance.streamDepartmentMessages(widget.firmId, widget.conversationId)
                          : DBService.instance.streamProjectMessages(widget.firmId, widget.conversationId)),
                  builder: (context, msgSnapshot) {
                    if (msgSnapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (msgSnapshot.hasError) {
                      return Center(
                        child: Text(
                          'Error loading messages: ${msgSnapshot.error}',
                          style: const TextStyle(color: Colors.red),
                        ),
                      );
                    }

                    final messages = msgSnapshot.data ?? [];
                    if (messages.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.forum_outlined, size: 48, color: Colors.grey[600]),
                            const SizedBox(height: 12),
                            Text(
                              'No messages yet in ${widget.title}.\nStart the discussion!',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey[500]),
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.builder(
                      controller: _scrollController,
                      reverse: true,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final msg = messages[index];
                        final isMine = msg.senderId == widget.uid;
                        return _buildMessageRow(msg, isMine, primaryColor);
                      },
                    );
                  },
                ),
              ),

              // Message Input composer area
              _buildInputArea(canPost, primaryColor),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMessageRow(ChatMessage msg, bool isMine, Color primaryColor) {
    final bubbleColor = isMine
        ? (widget.channelType == ChannelType.project ? Colors.purple[700]! : primaryColor)
        : Colors.grey[850]!;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (!isMine)
            Padding(
              padding: const EdgeInsets.only(left: 8, bottom: 2),
              child: Text(
                msg.senderName,
                style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          Row(
            mainAxisAlignment: isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
            children: [
              Container(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.75,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: bubbleColor,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(16),
                    topRight: const Radius.circular(16),
                    bottomLeft: isMine ? const Radius.circular(16) : Radius.zero,
                    bottomRight: isMine ? Radius.zero : const Radius.circular(16),
                  ),
                ),
                child: Text(
                  msg.text,
                  style: const TextStyle(color: Colors.white, fontSize: 15),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(top: 2, left: 4, right: 4),
            child: Text(
              _formatTime(msg.timestamp),
              style: TextStyle(color: Colors.grey[600], fontSize: 10),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputArea(bool canPost, Color primaryColor) {
    if (!canPost) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        color: const Color.fromRGBO(20, 20, 20, 1),
        child: const SafeArea(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock_outline, size: 16, color: Colors.grey),
              SizedBox(width: 8),
              Text(
                'Only Admins and Leads can post in this channel.',
                style: TextStyle(color: Colors.grey, fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: const Color.fromRGBO(20, 20, 20, 1),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _messageController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Type a message...',
                  hintStyle: TextStyle(color: Colors.grey[600]),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
                onSubmitted: (_) => _handleSendMessage(),
              ),
            ),
            IconButton(
              icon: Icon(
                Icons.send,
                color: widget.channelType == ChannelType.project ? Colors.purpleAccent : primaryColor,
              ),
              onPressed: _handleSendMessage,
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime dateTime) {
    final localTime = dateTime.toLocal();
    final hour = localTime.hour.toString().padLeft(2, '0');
    final minute = localTime.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}
