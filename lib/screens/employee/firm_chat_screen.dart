import 'package:flutter/material.dart';
import 'package:provider/provider.dart' as provider;
import '../../models/chat_message.dart';
import '../../models/firm.dart';
import '../../services/chat_service.dart';
import '../../services/db_service.dart';
import '../../services/snackbar_service.dart';
import '../../providers/auth_provider.dart';

class FirmChatScreen extends StatefulWidget {
  final String firmId;
  final String uid;
  final String name;

  const FirmChatScreen({
    super.key,
    required this.firmId,
    required this.uid,
    required this.name,
  });

  @override
  State<FirmChatScreen> createState() => _FirmChatScreenState();
}

class _FirmChatScreenState extends State<FirmChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isSending = false;

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _handleSendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isSending) return;

    setState(() => _isSending = true);
    _messageController.clear();

    try {
      await ChatService.instance.sendMessage(
        widget.firmId,
        widget.uid,
        widget.name,
        text,
      );
      _scrollToBottom();
    } catch (e) {
      _messageController.text = text; // Restore text in case of error
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
          0.0, // Scroll to bottom in a reversed list is 0.0 offset
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;

    return FutureBuilder<Firm>(
      future: DBService.instance.getFirm(widget.firmId),
      builder: (context, firmSnapshot) {
        final firmName = firmSnapshot.data?.name ?? 'Workspace';
        final logoUrl = firmSnapshot.data?.logoUrl;

        return Scaffold(
          backgroundColor: const Color.fromRGBO(28, 27, 27, 1),
          appBar: AppBar(
            backgroundColor: const Color.fromRGBO(28, 27, 27, 1),
            elevation: 0,
            titleSpacing: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () {
                final auth = provider.Provider.of<AuthProvider>(context, listen: false);
                auth.signOut();
              },
            ),
            title: Row(
              children: [
                if (logoUrl != null) ...[
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      image: DecorationImage(
                        image: NetworkImage(logoUrl),
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                ] else ...[
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: primaryColor.withOpacity(0.15),
                    child: Text(
                      firmName.isNotEmpty ? firmName[0].toUpperCase() : 'W',
                      style: TextStyle(
                        color: primaryColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      firmName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Text(
                      'General Team Chat',
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.logout, color: Colors.grey),
                tooltip: 'Sign out',
                onPressed: () {
                  final auth = provider.Provider.of<AuthProvider>(context, listen: false);
                  auth.signOut();
                },
              ),
            ],
          ),
          body: Column(
            children: [
              // Message list stream
              Expanded(
                child: StreamBuilder<List<ChatMessage>>(
                  stream: ChatService.instance.getFirmMessages(widget.firmId),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (snapshot.hasError) {
                      return Center(
                        child: Text(
                          'Error loading messages: ${snapshot.error}',
                          style: const TextStyle(color: Colors.red),
                        ),
                      );
                    }

                    final messages = snapshot.data ?? [];
                    if (messages.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.chat_bubble_outline, size: 48, color: Colors.grey[600]),
                            const SizedBox(height: 12),
                            Text(
                              'No messages yet in $firmName.\nStart the conversation!',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey[500]),
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      itemCount: messages.length,
                      reverse: true, // Show newest messages at bottom
                      itemBuilder: (context, index) {
                        final msg = messages[index];
                        final bool isMine = msg.senderId == widget.uid;

                        return _buildMessageRow(msg, isMine, primaryColor);
                      },
                    );
                  },
                ),
              ),

              // Message input block
              _buildInputArea(primaryColor),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMessageRow(ChatMessage msg, bool isMine, Color primaryColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          // Sender name for colleagues
          if (!isMine) ...[
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
          ],

          // Message bubble
          Row(
            mainAxisAlignment: isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
            children: [
              Container(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.75,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: isMine ? primaryColor : Colors.grey[850],
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

          // Message timestamp
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

  Widget _buildInputArea(Color primaryColor) {
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
              icon: Icon(Icons.send, color: primaryColor),
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
