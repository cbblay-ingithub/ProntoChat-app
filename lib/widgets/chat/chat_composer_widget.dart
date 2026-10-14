import 'dart:async';
import 'package:flutter/material.dart';
import '../../models/chat_message.dart';
import '../../models/poll_model.dart';
import 'chat_mention_picker.dart';
import 'create_poll_sheet.dart';

class ChatComposerWidget extends StatefulWidget {
  final bool canPost;
  final String cannotPostReason;
  final Color primaryColor;
  final List<Map<String, String>> participants;
  final bool canMentionAll;
  final ChatMessage? replyingTo;
  final ChatMessage? editingMessage;
  final VoidCallback onCancelReply;
  final VoidCallback onCancelEdit;
  final ValueChanged<String> onTyping;
  final String currentUid;
  final bool canCreatePoll;
  final ValueChanged<PollModel>? onCreatePoll;
  final Future<void> Function({
    required String text,
    List<MessageMention>? mentions,
    MessageReplyTo? replyTo,
    String? editMessageId,
  }) onSendMessage;

  const ChatComposerWidget({
    super.key,
    required this.canPost,
    this.cannotPostReason = 'You do not have permission to post in this channel.',
    required this.primaryColor,
    required this.participants,
    required this.canMentionAll,
    this.replyingTo,
    this.editingMessage,
    required this.onCancelReply,
    required this.onCancelEdit,
    required this.onTyping,
    this.currentUid = '',
    this.canCreatePoll = false,
    this.onCreatePoll,
    required this.onSendMessage,
  });

  @override
  State<ChatComposerWidget> createState() => _ChatComposerWidgetState();
}

class _ChatComposerWidgetState extends State<ChatComposerWidget> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  bool _isSending = false;
  bool _showMentionPicker = false;
  String _mentionQuery = '';
  int _mentionStartIndex = -1;
  bool _justSelectedMention = false;
  final List<MessageMention> _detectedMentions = [];

  Timer? _typingThrottleTimer;
  DateTime? _lastTypingEmit;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);
  }

  @override
  void didUpdateWidget(covariant ChatComposerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.editingMessage != null && widget.editingMessage != oldWidget.editingMessage) {
      _controller.text = widget.editingMessage!.text;
      _controller.selection = TextSelection.fromPosition(
        TextPosition(offset: _controller.text.length),
      );
      _focusNode.requestFocus();
    }
    if (widget.replyingTo != null && widget.replyingTo != oldWidget.replyingTo) {
      _focusNode.requestFocus();
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    _focusNode.dispose();
    _typingThrottleTimer?.cancel();
    super.dispose();
  }

  void _onTextChanged() {
    if (_justSelectedMention) {
      _justSelectedMention = false;
      return;
    }

    final text = _controller.text;
    final selection = _controller.selection;

    // Typing heartbeat: throttled to 3-4s
    final now = DateTime.now();
    if (_lastTypingEmit == null || now.difference(_lastTypingEmit!).inSeconds >= 3) {
      _lastTypingEmit = now;
      widget.onTyping(text);
    }

    // Check for @mention trigger
    if (selection.baseOffset > 0 && selection.baseOffset <= text.length) {
      final textBeforeCursor = text.substring(0, selection.baseOffset);
      final lastAt = textBeforeCursor.lastIndexOf('@');

      if (lastAt != -1 && (lastAt == 0 || textBeforeCursor[lastAt - 1] == ' ' || textBeforeCursor[lastAt - 1] == '\n')) {
        final query = textBeforeCursor.substring(lastAt + 1);
        final spaceCount = ' '.allMatches(query).length;
        if (query.length <= 30 && !query.contains('\n') && spaceCount <= 1) {
          setState(() {
            _showMentionPicker = true;
            _mentionQuery = query;
            _mentionStartIndex = lastAt;
          });
          return;
        }
      }
    }

    if (_showMentionPicker) {
      setState(() {
        _showMentionPicker = false;
      });
    }
  }

  void _handleSelectParticipant(Map<String, String> participant) {
    final uid = participant['uid'] ?? '';
    final name = participant['name'] ?? '';
    final text = _controller.text;

    if (_mentionStartIndex >= 0 && _mentionStartIndex <= text.length) {
      final before = text.substring(0, _mentionStartIndex);
      final currentOffset = _controller.selection.baseOffset;
      final safeOffset = (currentOffset >= _mentionStartIndex && currentOffset <= text.length)
          ? currentOffset
          : text.length;
      final after = text.substring(safeOffset);
      final insertText = '@$name ';
      final newText = '$before$insertText$after';

      _detectedMentions.add(MessageMention(
        uid: uid,
        name: name,
        start: _mentionStartIndex,
        end: _mentionStartIndex + insertText.length - 1,
      ));

      _justSelectedMention = true;
      _controller.text = newText;
      _controller.selection = TextSelection.fromPosition(
        TextPosition(offset: before.length + insertText.length),
      );
    }

    setState(() {
      _showMentionPicker = false;
    });
    _focusNode.requestFocus();
  }

  Future<void> _handleSend() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isSending) return;

    final String? editId = widget.editingMessage?.messageId;
    MessageReplyTo? replyTo;
    if (widget.replyingTo != null) {
      replyTo = MessageReplyTo(
        messageId: widget.replyingTo!.messageId,
        senderId: widget.replyingTo!.senderId,
        senderName: widget.replyingTo!.senderName,
        snippet: widget.replyingTo!.text,
        kind: widget.replyingTo!.type,
      );
    }

    final mentionsToSend = <MessageMention>[];
    final lowerText = text.toLowerCase();

    // 1. Add detected mentions whose tagged name is still present in text
    for (final dm in _detectedMentions) {
      final lowerDmTag = '@${dm.name.toLowerCase()}';
      if (lowerText.contains(lowerDmTag) && !mentionsToSend.any((m) => m.uid == dm.uid)) {
        mentionsToSend.add(dm);
      }
    }

    // 2. Also auto-detect any @[Name] or @[email/username] typed manually matching participants
    for (final p in widget.participants) {
      final pName = p['name'];
      final pUid = p['uid'];
      final pEmail = p['email'] ?? '';
      if (pUid != null && pUid.isNotEmpty && !mentionsToSend.any((m) => m.uid == pUid)) {
        final List<String> tagsToTry = [];
        if (pName != null && pName.isNotEmpty) {
          tagsToTry.add('@${pName.toLowerCase()}');
          final firstName = pName.split(' ').first.toLowerCase();
          if (firstName.length >= 2 && firstName != pName.toLowerCase()) {
            tagsToTry.add('@$firstName');
          }
        }
        if (pEmail.isNotEmpty) {
          final username = pEmail.split('@').first.toLowerCase();
          if (username.isNotEmpty) {
            tagsToTry.add('@$username');
          }
        }

        for (final tag in tagsToTry) {
          final matchIndex = lowerText.indexOf(tag);
          if (matchIndex != -1) {
            final nextCharIndex = matchIndex + tag.length;
            final isBoundary = nextCharIndex == lowerText.length ||
                lowerText[nextCharIndex] == ' ' ||
                lowerText[nextCharIndex] == '\n' ||
                lowerText[nextCharIndex] == ',' ||
                lowerText[nextCharIndex] == '.';
            if (isBoundary) {
              mentionsToSend.add(MessageMention(
                uid: pUid,
                name: pName ?? tag.substring(1),
                start: matchIndex,
                end: matchIndex + tag.length,
              ));
              break;
            }
          }
        }
      }
    }

    // 3. If @all is written in text and permitted, add mention for @all
    if (widget.canMentionAll && lowerText.contains('@all') && !mentionsToSend.any((m) => m.uid == 'all')) {
      final index = lowerText.indexOf('@all');
      mentionsToSend.add(MessageMention(uid: 'all', name: 'all', start: index, end: index + 4));
    }

    setState(() => _isSending = true);
    _controller.clear();
    _detectedMentions.clear();

    try {
      await widget.onSendMessage(
        text: text,
        mentions: mentionsToSend,
        replyTo: replyTo,
        editMessageId: editId,
      );
      if (widget.replyingTo != null) widget.onCancelReply();
      if (widget.editingMessage != null) widget.onCancelEdit();
    } catch (e) {
      // Restore on failure
      _controller.text = text;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Send failed: $e. Message preserved.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.canPost) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        color: const Color.fromRGBO(24, 24, 24, 1),
        child: SafeArea(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock_outline, size: 16, color: Colors.grey),
              const SizedBox(width: 8),
              Text(
                widget.cannotPostReason,
                style: const TextStyle(color: Colors.grey, fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_showMentionPicker)
          ChatMentionPicker(
            participants: widget.participants,
            query: _mentionQuery,
            canMentionAll: widget.canMentionAll,
            onSelectParticipant: _handleSelectParticipant,
          ),
        Container(
          decoration: BoxDecoration(
            color: const Color.fromRGBO(28, 27, 27, 1),
            border: Border(
              top: BorderSide(color: Colors.white.withOpacity(0.08), width: 0.5),
            ),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.replyingTo != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    color: Colors.blueAccent.withOpacity(0.1),
                    child: Row(
                      children: [
                        const Icon(Icons.reply, size: 16, color: Colors.blueAccent),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Replying to ${widget.replyingTo!.senderName}',
                                style: const TextStyle(
                                  color: Colors.blueAccent,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                widget.replyingTo!.text,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(color: Colors.grey[400], fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 18, color: Colors.grey),
                          onPressed: widget.onCancelReply,
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                    ),
                  ),
                if (widget.editingMessage != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    color: Colors.greenAccent.withOpacity(0.1),
                    child: Row(
                      children: [
                        const Icon(Icons.edit, size: 16, color: Colors.greenAccent),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Editing message',
                            style: TextStyle(
                              color: Colors.greenAccent,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 18, color: Colors.grey),
                          onPressed: widget.onCancelEdit,
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (widget.canCreatePoll && widget.onCreatePoll != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 2, right: 4),
                          child: IconButton(
                            icon: const Icon(Icons.add_circle_outline, color: Colors.grey, size: 24),
                            tooltip: 'Chat actions',
                            onPressed: () => _showActionsMenu(context),
                          ),
                        ),
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color.fromRGBO(44, 43, 46, 1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: TextField(
                            controller: _controller,
                            focusNode: _focusNode,
                            maxLines: 5,
                            minLines: 1,
                            style: const TextStyle(color: Colors.white, fontSize: 15),
                            decoration: InputDecoration(
                              hintText: widget.editingMessage != null
                                   ? 'Edit message...'
                                   : 'Type a message...',
                              hintStyle: TextStyle(color: Colors.grey[500]),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            ),
                            onSubmitted: (_) => _handleSend(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      _isSending
                          ? const Padding(
                              padding: EdgeInsets.all(8.0),
                              child: SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            )
                          : IconButton(
                              icon: Icon(
                                widget.editingMessage != null ? Icons.check_circle : Icons.send,
                                color: widget.editingMessage != null ? Colors.greenAccent : widget.primaryColor,
                              ),
                              onPressed: _handleSend,
                              tooltip: widget.editingMessage != null ? 'Save Edit' : 'Send',
                            ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showActionsMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color.fromRGBO(34, 33, 35, 1),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.purpleAccent.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.poll_rounded, color: Colors.purpleAccent, size: 20),
              ),
              title: const Text('Create Poll', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              subtitle: const Text('Ask a question and gather team votes', style: TextStyle(color: Colors.grey, fontSize: 12)),
              onTap: () {
                Navigator.pop(ctx);
                _openCreatePollSheet(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _openCreatePollSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CreatePollSheet(
        primaryColor: widget.primaryColor,
        currentUid: widget.currentUid,
        onPollCreated: (poll) {
          widget.onCreatePoll?.call(poll);
        },
      ),
    );
  }
}
