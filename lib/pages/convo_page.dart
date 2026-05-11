import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/db_service.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({
    super.key,
    required this.conversationId,
    required this.otherUserId,
    required this.otherUserName,
    required this.otherUserImage,
  });

  final String conversationId;
  final String otherUserId;
  final String otherUserName;
  final String otherUserImage;

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController      _scrollController = ScrollController();

  bool _isSending = false;

  // ── Lifecycle ────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    // Reset unseen counter and stamp seenBy on all unread messages as soon
    // as the chat screen opens.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final uid = context.read<AuthProvider>().currentUserId!;
      DBService.instance.markConversationAsSeen(
        conversationId: widget.conversationId,
        uid: uid,
      );
    });
  }

  // ── Send ─────────────────────────────────────────────────────────────────

  Future<void> _sendMessage() async {
    final text = _inputController.text.trim();
    if (text.isEmpty || _isSending) return;

    final auth = context.read<AuthProvider>();
    _inputController.clear();
    setState(() => _isSending = true);

    try {
      await DBService.instance.sendMessage(
        conversationId: widget.conversationId,
        senderId:        auth.currentUserId!,
        receiverId:      widget.otherUserId,
        type:            'text',
        content:         text,
      );
      _scrollToBottom();
    } catch (_) {
      // Re-populate the field so the user doesn't lose their message
      _inputController.text = text;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Message failed. Please try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ── UI ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final currentUid = context.read<AuthProvider>().currentUserId!;

    return Scaffold(
      backgroundColor: const Color.fromRGBO(28, 27, 27, 1),
      appBar: _buildAppBar(),
      body: Column(
        children: [
          Expanded(child: _buildMessageList(currentUid)),
          _buildInputRow(),
        ],
      ),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: const Color.fromRGBO(28, 27, 27, 1),
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      titleSpacing: 0,
      title: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: const Color.fromRGBO(41, 116, 188, 0.3),
            backgroundImage: widget.otherUserImage.isNotEmpty
                ? NetworkImage(widget.otherUserImage)
                : null,
            child: widget.otherUserImage.isEmpty
                ? Text(
                    widget.otherUserName.isNotEmpty
                        ? widget.otherUserName[0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                      color: Color.fromRGBO(41, 116, 188, 1),
                      fontWeight: FontWeight.bold,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 10),
          Text(
            widget.otherUserName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageList(String currentUid) {
    return StreamBuilder<QuerySnapshot>(
      stream: DBService.instance.streamMessages(widget.conversationId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
                color: Color.fromRGBO(41, 116, 188, 1)),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Could not load messages.',
              style: TextStyle(color: Colors.grey[500]),
            ),
          );
        }

        final docs = snapshot.data?.docs ?? [];

        if (docs.isEmpty) {
          return Center(
            child: Text(
              'No messages yet.\nSay hello 👋',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600], fontSize: 15),
            ),
          );
        }

        // Scroll to the bottom whenever new messages arrive
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

        return ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data     = docs[index].data() as Map<String, dynamic>;
            final isMine   = data['senderId'] == currentUid;
            final ts       = data['timestamp'] as Timestamp?;
            final content  = data['content']   as String? ?? '';

            return _MessageBubble(
              content:  content,
              isMine:   isMine,
              timestamp: ts,
            );
          },
        );
      },
    );
  }

  Widget _buildInputRow() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color.fromRGBO(28, 27, 27, 1),
        border: Border(
          top: BorderSide(color: Colors.grey[850]!, width: 0.5),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _inputController,
                style: const TextStyle(color: Colors.white),
                maxLines: null,    // grows with content
                keyboardType: TextInputType.multiline,
                textCapitalization: TextCapitalization.sentences,
                onSubmitted: (_) => _sendMessage(),
                decoration: InputDecoration(
                  hintText: 'Message…',
                  hintStyle: TextStyle(color: Colors.grey[600]),
                  filled: true,
                  fillColor: const Color.fromRGBO(45, 45, 45, 1),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            _isSending
                ? const SizedBox(
                    width: 44,
                    height: 44,
                    child: Padding(
                      padding: EdgeInsets.all(10),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color.fromRGBO(41, 116, 188, 1),
                      ),
                    ),
                  )
                : IconButton(
                    onPressed: _sendMessage,
                    icon: const Icon(Icons.send_rounded),
                    color: const Color.fromRGBO(41, 116, 188, 1),
                    iconSize: 26,
                    tooltip: 'Send',
                  ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Message bubble
// ─────────────────────────────────────────────────────────────────────────────

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.content,
    required this.isMine,
    required this.timestamp,
  });

  final String     content;
  final bool       isMine;
  final Timestamp? timestamp;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.72,
        ),
        margin: const EdgeInsets.symmetric(vertical: 3),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: isMine
              ? const Color.fromRGBO(41, 116, 188, 1)
              : const Color.fromRGBO(50, 50, 50, 1),
          borderRadius: BorderRadius.only(
            topLeft:     const Radius.circular(16),
            topRight:    const Radius.circular(16),
            bottomLeft:  Radius.circular(isMine ? 16 : 4),
            bottomRight: Radius.circular(isMine ? 4  : 16),
          ),
        ),
        child: Column(
          crossAxisAlignment:
              isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              content,
              style: const TextStyle(color: Colors.white, fontSize: 15),
            ),
            const SizedBox(height: 3),
            Text(
              _formatTime(timestamp),
              style: TextStyle(
                color: isMine ? Colors.white60 : Colors.grey[500],
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(Timestamp? ts) {
    if (ts == null) return '';
    final dt = ts.toDate();
    return '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}';
  }
}