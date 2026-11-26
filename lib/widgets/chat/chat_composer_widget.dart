import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/chat_message.dart';
import '../../models/poll_model.dart';
import '../../theme/pc_tokens.dart';
import 'chat_mention_picker.dart';
import 'create_poll_sheet.dart';
import 'image_preview_sheet.dart';

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
  final Future<void> Function({
    required Uint8List bytes,
    required String fileName,
    required String caption,
    MessageReplyTo? replyTo,
  })? onSendImage;

  const ChatComposerWidget({
    super.key,
    required this.canPost,
    this.cannotPostReason =
        'You do not have permission to post in this channel.',
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
    this.onSendImage,
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
  final ImagePicker _imagePicker = ImagePicker();

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
    if (widget.editingMessage != null &&
        widget.editingMessage != oldWidget.editingMessage) {
      _controller.text = widget.editingMessage!.text;
      _controller.selection = TextSelection.fromPosition(
        TextPosition(offset: _controller.text.length),
      );
      _focusNode.requestFocus();
    }
    if (widget.replyingTo != null &&
        widget.replyingTo != oldWidget.replyingTo) {
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

    final now = DateTime.now();
    if (_lastTypingEmit == null ||
        now.difference(_lastTypingEmit!).inSeconds >= 3) {
      _lastTypingEmit = now;
      widget.onTyping(text);
    }

    if (selection.baseOffset > 0 && selection.baseOffset <= text.length) {
      final textBeforeCursor = text.substring(0, selection.baseOffset);
      final lastAt = textBeforeCursor.lastIndexOf('@');

      if (lastAt != -1 &&
          (lastAt == 0 ||
              textBeforeCursor[lastAt - 1] == ' ' ||
              textBeforeCursor[lastAt - 1] == '\n')) {
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
      final safeOffset = (currentOffset >= _mentionStartIndex &&
              currentOffset <= text.length)
          ? currentOffset
          : text.length;
      final after = text.substring(safeOffset);
      final insertText = '@$name ';
      final newText = '$before$insertText$after';

      _detectedMentions.add(
        MessageMention(
          uid: uid,
          name: name,
          start: _mentionStartIndex,
          end: _mentionStartIndex + insertText.length - 1,
        ),
      );

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

    for (final dm in _detectedMentions) {
      final lowerDmTag = '@${dm.name.toLowerCase()}';
      if (lowerText.contains(lowerDmTag) &&
          !mentionsToSend.any((m) => m.uid == dm.uid)) {
        mentionsToSend.add(dm);
      }
    }

    for (final p in widget.participants) {
      final pName = p['name'];
      final pUid = p['uid'];
      final pEmail = p['email'] ?? '';
      if (pUid != null &&
          pUid.isNotEmpty &&
          !mentionsToSend.any((m) => m.uid == pUid)) {
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
              mentionsToSend.add(
                MessageMention(
                  uid: pUid,
                  name: pName ?? tag.substring(1),
                  start: matchIndex,
                  end: matchIndex + tag.length,
                ),
              );
              break;
            }
          }
        }
      }
    }

    if (widget.canMentionAll &&
        lowerText.contains('@all') &&
        !mentionsToSend.any((m) => m.uid == 'all')) {
      final index = lowerText.indexOf('@all');
      mentionsToSend.add(
        MessageMention(
          uid: 'all',
          name: 'all',
          start: index,
          end: index + 4,
        ),
      );
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
    final tokens = context.pcTokens;

    if (!widget.canPost) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: tokens.surfaceSubtle,
          border: Border(top: BorderSide(color: tokens.border)),
        ),
        child: SafeArea(
          top: false,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock_outline_rounded, size: 16, color: tokens.textMuted),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  widget.cannotPostReason,
                  style: TextStyle(color: tokens.textMuted, fontSize: 13),
                ),
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
            color: tokens.surface,
            border: Border(
              top: BorderSide(color: tokens.border, width: 1),
            ),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.replyingTo != null)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    color: tokens.primarySoft,
                    child: Row(
                      children: [
                        Icon(
                          Icons.reply_rounded,
                          size: 16,
                          color: tokens.primary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Replying to ${widget.replyingTo!.senderName}',
                                style: TextStyle(
                                  color: tokens.primary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                widget.replyingTo!.text,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: tokens.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.close_rounded,
                            size: 18,
                            color: tokens.textMuted,
                          ),
                          onPressed: widget.onCancelReply,
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                    ),
                  ),
                if (widget.editingMessage != null)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    color: tokens.online.withValues(alpha: 0.12),
                    child: Row(
                      children: [
                        Icon(
                          Icons.edit_rounded,
                          size: 16,
                          color: tokens.online,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Editing message',
                            style: TextStyle(
                              color: tokens.online,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.close_rounded,
                            size: 18,
                            color: tokens.textMuted,
                          ),
                          onPressed: widget.onCancelEdit,
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                    ),
                  ),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(bottom: 2, right: 4),
                        child: IconButton(
                          icon: Icon(
                            Icons.add_circle_outline_rounded,
                            color: tokens.textSecondary,
                            size: 24,
                          ),
                          tooltip: 'Attach image or poll',
                          onPressed: () => _showActionsMenu(context, tokens),
                        ),
                      ),
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: tokens.surfaceSubtle,
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(color: tokens.border),
                          ),
                          child: TextField(
                            controller: _controller,
                            focusNode: _focusNode,
                            maxLines: 5,
                            minLines: 1,
                            style: TextStyle(
                              color: tokens.textPrimary,
                              fontSize: 14.5,
                            ),
                            decoration: InputDecoration(
                              hintText: widget.editingMessage != null
                                  ? 'Edit message...'
                                  : 'Type a message...',
                              hintStyle: TextStyle(color: tokens.textMuted),
                              filled: false,
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                            ),
                            onSubmitted: (_) => _handleSend(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      _isSending
                          ? Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: widget.primaryColor,
                                ),
                              ),
                            )
                          : IconButton(
                              icon: Icon(
                                widget.editingMessage != null
                                    ? Icons.check_circle
                                    : Icons.send,
                                color: widget.editingMessage != null
                                    ? tokens.online
                                    : widget.primaryColor,
                              ),
                              onPressed: _handleSend,
                              tooltip: widget.editingMessage != null
                                  ? 'Save Edit'
                                  : 'Send',
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

  Future<void> _pickAndPreviewImage(
    BuildContext context,
    ImageSource source,
  ) async {
    try {
      final XFile? file = await _imagePicker.pickImage(
        source: source,
        imageQuality: 90,
      );
      if (file == null) return;

      final bytes = await file.readAsBytes();
      if (!context.mounted) return;

      if (bytes.length > 10 * 1024 * 1024) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Selected image exceeds the 10 MB limit.'),
            backgroundColor: Colors.redAccent,
          ),
        );
        return;
      }

      await ImagePreviewSheet.show(
        context: context,
        imageBytes: bytes,
        fileName: file.name,
        primaryColor: widget.primaryColor,
        onSend: (imageBytes, fileName, caption) async {
          if (widget.onSendImage != null) {
            await widget.onSendImage!(
              bytes: imageBytes,
              fileName: fileName,
              caption: caption,
              replyTo: widget.replyingTo != null
                  ? MessageReplyTo(
                      messageId: widget.replyingTo!.messageId,
                      senderId: widget.replyingTo!.senderId,
                      senderName: widget.replyingTo!.senderName,
                      snippet: widget.replyingTo!.text,
                      kind: widget.replyingTo!.type,
                    )
                  : null,
            );
            if (widget.replyingTo != null) widget.onCancelReply();
          }
        },
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not load image: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  void _showActionsMenu(BuildContext context, PcTokens tokens) {
    showModalBottomSheet(
      context: context,
      backgroundColor: tokens.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: tokens.infoSoft,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.photo_library_rounded,
                    color: tokens.infoAccent,
                    size: 20,
                  ),
                ),
                title: Text(
                  'Photo Library',
                  style: TextStyle(
                    color: tokens.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                subtitle: Text(
                  'Send an image from your gallery',
                  style: TextStyle(color: tokens.textMuted, fontSize: 12),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickAndPreviewImage(context, ImageSource.gallery);
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: tokens.online.withValues(alpha: 0.14),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.camera_alt_rounded,
                    color: tokens.online,
                    size: 20,
                  ),
                ),
                title: Text(
                  'Take Photo',
                  style: TextStyle(
                    color: tokens.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                subtitle: Text(
                  'Capture and send a photo instantly',
                  style: TextStyle(color: tokens.textMuted, fontSize: 12),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickAndPreviewImage(context, ImageSource.camera);
                },
              ),
              if (widget.canCreatePoll && widget.onCreatePoll != null)
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: tokens.projectSoft,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.poll_rounded,
                      color: tokens.projectAccent,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    'Create Poll',
                    style: TextStyle(
                      color: tokens.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  subtitle: Text(
                    'Ask a question and gather team votes',
                    style: TextStyle(color: tokens.textMuted, fontSize: 12),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _openCreatePollSheet(context);
                  },
                ),
            ],
          ),
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
