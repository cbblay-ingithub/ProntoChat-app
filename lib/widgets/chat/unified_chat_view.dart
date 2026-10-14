import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../models/chat_message.dart';
import '../../models/chat_polish_models.dart';
import '../../models/firm.dart';
import '../../services/db_service.dart';
import '../../services/snackbar_service.dart';
import 'pinned_messages_banner.dart';
import 'typing_indicator_widget.dart';
import 'message_bubble_widget.dart';
import 'chat_composer_widget.dart';
import 'chat_date_divider.dart';
import 'chat_search_sheet.dart';
import '../../models/poll_model.dart';

enum UnifiedChatKind { direct, department, project, allStaff, general }

class UnifiedChatView extends StatefulWidget {
  final UnifiedChatKind kind;
  final String? firmId;
  final String conversationId;
  final String title;
  final String? subtitle;
  final String? otherUserId;
  final String? otherUserImage;
  final String currentUid;
  final String currentUserName;
  final String currentUserRole;
  final Color primaryColor;
  final Firm? firm;
  final String? departmentId;
  final String? projectOwnerUid;
  final bool canPost;

  const UnifiedChatView({
    super.key,
    required this.kind,
    this.firmId,
    required this.conversationId,
    required this.title,
    this.subtitle,
    this.otherUserId,
    this.otherUserImage,
    required this.currentUid,
    required this.currentUserName,
    required this.currentUserRole,
    required this.primaryColor,
    this.firm,
    this.departmentId,
    this.projectOwnerUid,
    this.canPost = true,
  });

  @override
  State<UnifiedChatView> createState() => _UnifiedChatViewState();
}

class _UnifiedChatViewState extends State<UnifiedChatView> with WidgetsBindingObserver {
  final ScrollController _scrollController = ScrollController();
  final Map<String, GlobalKey> _messageKeys = {};

  ChatMessage? _replyingTo;
  ChatMessage? _editingMessage;

  // Pagination state
  List<ChatMessage> _olderMessages = [];
  DocumentSnapshot? _lastVisibleDoc;
  bool _isLoadingMore = false;
  bool _hasMore = true;

  // Jump / scroll state
  bool _showScrollToBottom = false;
  String? _firstUnreadMessageId;

  // Participants for @mention
  List<Map<String, String>> _participants = [];
  bool _isLoadingParticipants = false;

  StreamSubscription? _readStreamSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scrollController.addListener(_onScroll);

    _loadParticipants();
    _markReadOnOpen();
  }

  @override
  void didUpdateWidget(covariant UnifiedChatView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.conversationId != widget.conversationId ||
        oldWidget.firmId != widget.firmId ||
        oldWidget.departmentId != widget.departmentId ||
        oldWidget.kind != widget.kind) {
      _loadParticipants();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (widget.firmId != null && widget.firmId!.isNotEmpty) {
      if (state == AppLifecycleState.resumed) {
        DBService.instance.updatePresence(
          firmId: widget.firmId!,
          uid: widget.currentUid,
          force: true,
        );
      } else if (state == AppLifecycleState.paused) {
        DBService.instance.updatePresence(
          firmId: widget.firmId!,
          uid: widget.currentUid,
          force: true,
        );
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scrollController.dispose();
    _readStreamSub?.cancel();
    _highlightTimer?.cancel();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;

    final offset = _scrollController.offset;
    final maxScroll = _scrollController.position.maxScrollExtent;

    // Show scroll to bottom button if user scrolled up
    if (offset > 300 && !_showScrollToBottom) {
      setState(() => _showScrollToBottom = true);
    } else if (offset <= 300 && _showScrollToBottom) {
      setState(() => _showScrollToBottom = false);
    }

    // Load more when reaching near the top of the chat (maxScrollExtent in reverse list)
    if (offset >= maxScroll - 200 && !_isLoadingMore && _hasMore && _lastVisibleDoc != null) {
      _loadOlderMessages();
    }
  }

  Future<void> _loadParticipants() async {
    if (_isLoadingParticipants) return;
    _isLoadingParticipants = true;
    try {
      final list = await DBService.instance.getConversationParticipants(
        firmId: widget.firmId,
        conversationId: widget.conversationId,
        conversationType: widget.kind.name,
        departmentId: widget.departmentId,
      );
      if (mounted) {
        setState(() => _participants = list);
      }
    } finally {
      _isLoadingParticipants = false;
    }
  }

  void _markReadOnOpen() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      DBService.instance.markReadPointer(
        firmId: widget.firmId,
        conversationId: widget.conversationId,
        uid: widget.currentUid,
        lastMessageId: 'opened_${DateTime.now().millisecondsSinceEpoch}',
      );
      if (widget.firmId != null && widget.firmId!.isNotEmpty) {
        DBService.instance.updatePresence(
          firmId: widget.firmId!,
          uid: widget.currentUid,
        );
      }
    });
  }

  Future<void> _loadOlderMessages() async {
    if (_lastVisibleDoc == null || _isLoadingMore) return;
    setState(() => _isLoadingMore = true);

    try {
      final docs = await DBService.instance.loadOlderMessagesQuery(
        firmId: widget.firmId,
        conversationId: widget.conversationId,
        lastVisibleDoc: _lastVisibleDoc!,
        limit: 30,
      );

      if (docs.isEmpty) {
        _hasMore = false;
      } else {
        _lastVisibleDoc = docs.last;
        final older = docs.map((d) => ChatMessage.fromMap(d.data(), d.id)).toList();
        setState(() {
          _olderMessages.addAll(older);
        });
      }
    } catch (e) {
      debugPrint('Notice: load older messages: $e');
    } finally {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0.0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  String? _highlightedMessageId;
  Timer? _highlightTimer;
  List<ChatMessage> _currentLoadedMessages = [];

  void _jumpToMessage(String messageId, {bool highlight = false}) {
    if (highlight) {
      _highlightTimer?.cancel();
      setState(() => _highlightedMessageId = messageId);
      _highlightTimer = Timer(const Duration(seconds: 3), () {
        if (mounted) setState(() => _highlightedMessageId = null);
      });
    }

    final key = _messageKeys[messageId];
    if (key != null && key.currentContext != null) {
      Scrollable.ensureVisible(
        key.currentContext!,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    } else {
      SnackbarService().showSnackbar('Message is in older history. Scroll up to load.');
    }
  }

  void _openSearchSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ChatSearchSheet(
        firmId: widget.firmId,
        conversationId: widget.conversationId,
        cachedMessages: _currentLoadedMessages,
        participants: _participants,
        primaryColor: widget.primaryColor,
        onSelectMessage: (msg) {
          _jumpToMessage(msg.messageId, highlight: true);
        },
      ),
    );
  }

  bool _canCreatePoll() {
    if (widget.kind == UnifiedChatKind.direct) return false;
    if (widget.kind == UnifiedChatKind.project) return true;
    if (widget.kind == UnifiedChatKind.general) return true;
    if (widget.kind == UnifiedChatKind.department ||
        widget.kind == UnifiedChatKind.allStaff) {
      final role = widget.currentUserRole.toLowerCase();
      return role == 'lead' || role == 'admin' || role == 'super_admin';
    }
    return false;
  }

  Future<void> _handleCreatePoll(PollModel poll) async {
    try {
      await DBService.instance.createPollMessage(
        firmId: widget.firmId,
        conversationId: widget.conversationId,
        senderId: widget.currentUid,
        senderName: widget.currentUserName,
        poll: poll,
      );
      _scrollToBottom();
    } catch (e) {
      debugPrint('Notice create poll: $e');
    }
  }

  bool _canUserPin() {
    if (widget.kind == UnifiedChatKind.direct) return true;
    if (widget.kind == UnifiedChatKind.general) return true;
    if (widget.kind == UnifiedChatKind.department ||
        widget.kind == UnifiedChatKind.allStaff) {
      final role = widget.currentUserRole.toLowerCase();
      return role == 'lead' || role == 'admin' || role == 'super_admin';
    }
    if (widget.kind == UnifiedChatKind.project) {
      return widget.projectOwnerUid == widget.currentUid;
    }
    return false;
  }

  void _handlePinMessage(ChatMessage m, Duration duration) {
    final now = DateTime.now();
    DBService.instance.pinMessage(
      firmId: widget.firmId,
      conversationId: widget.conversationId,
      pin: PinnedMessage(
        messageId: m.messageId,
        snippet: m.text,
        pinnedBy: widget.currentUserName,
        pinnedAt: now,
        pinnedUntil: now.add(duration),
      ),
    );
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Message pinned successfully.')),
    );
  }

  void _handleUnpinMessage(String msgId) {
    DBService.instance.unpinMessage(
      firmId: widget.firmId,
      conversationId: widget.conversationId,
      messageId: msgId,
    );
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Message unpinned.')),
    );
  }

  bool _canUserMentionAll() {
    final role = widget.currentUserRole.toLowerCase();
    return role == 'lead' || role == 'admin' || role == 'super_admin';
  }

  Future<void> _handleSendMessage({
    required String text,
    List<MessageMention>? mentions,
    MessageReplyTo? replyTo,
    String? editMessageId,
  }) async {
    if (editMessageId != null) {
      await DBService.instance.editMessage(
        firmId: widget.firmId,
        conversationId: widget.conversationId,
        messageId: editMessageId,
        newText: text,
      );
      return;
    }

    if (widget.kind == UnifiedChatKind.direct) {
      await DBService.instance.sendMessage(
        conversationId: widget.conversationId,
        senderId: widget.currentUid,
        senderName: widget.currentUserName,
        receiverId: widget.otherUserId ?? '',
        type: 'text',
        content: text,
        mentions: mentions,
        replyTo: replyTo,
      );
    } else if (widget.kind == UnifiedChatKind.department) {
      await DBService.instance.sendDepartmentMessage(
        firmId: widget.firmId!,
        conversationId: widget.conversationId,
        senderId: widget.currentUid,
        senderName: widget.currentUserName,
        text: text,
        mentions: mentions,
        replyTo: replyTo,
      );
    } else if (widget.kind == UnifiedChatKind.project) {
      await DBService.instance.sendProjectMessage(
        firmId: widget.firmId!,
        conversationId: widget.conversationId,
        senderId: widget.currentUid,
        senderName: widget.currentUserName,
        text: text,
        mentions: mentions,
        replyTo: replyTo,
      );
    } else if (widget.kind == UnifiedChatKind.allStaff || widget.kind == UnifiedChatKind.general) {
      await DBService.instance.sendAllStaffMessage(
        firmId: widget.firmId!,
        conversationId: widget.conversationId,
        senderId: widget.currentUid,
        senderName: widget.currentUserName,
        text: text,
        mentions: mentions,
        replyTo: replyTo,
      );
    }

    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    final showLastSeen = widget.firm?.showLastSeen ?? true;
    final showReadReceipts = widget.firm?.showReadReceipts ?? true;

    return StreamBuilder<List<PinnedMessage>>(
      stream: DBService.instance.streamPinnedMessages(
        firmId: widget.firmId,
        conversationId: widget.conversationId,
      ),
      builder: (context, pinSnap) {
        final pins = pinSnap.data ?? [];
        final activePins = pins.where((p) => !p.isExpired).toList();
        final activePinIds = activePins.map((p) => p.messageId).toSet();

        return Scaffold(
          backgroundColor: const Color.fromRGBO(24, 23, 26, 1),
          appBar: _buildAppBar(showLastSeen, activePins),
          body: Column(
            children: [
              // Pinned Messages Banner
              PinnedMessagesBanner(
                pins: activePins,
                canManagePins: _canUserPin(),
                onJumpToMessage: _jumpToMessage,
                onUnpinMessage: _handleUnpinMessage,
              ),

              // Messages stream + read pointers
              Expanded(
                child: StreamBuilder<Map<String, ReadPointer>>(
                  stream: DBService.instance.streamReadPointers(
                    firmId: widget.firmId,
                    conversationId: widget.conversationId,
                  ),
                  builder: (context, readSnap) {
                    final readPointers = readSnap.data ?? {};
                    final otherPointer = widget.otherUserId != null
                        ? readPointers[widget.otherUserId]
                        : null;

                    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: DBService.instance.streamMessagesQuery(
                        firmId: widget.firmId,
                        conversationId: widget.conversationId,
                        limit: 30,
                      ),
                      builder: (context, msgSnap) {
                        if (msgSnap.connectionState == ConnectionState.waiting && _olderMessages.isEmpty) {
                          return const Center(child: CircularProgressIndicator());
                        }

                        final streamDocs = msgSnap.data?.docs ?? [];
                        if (streamDocs.isNotEmpty && _lastVisibleDoc == null) {
                          _lastVisibleDoc = streamDocs.last;
                        }

                        // Combined messages list (newest first for reverse ListView)
                        final List<ChatMessage> allMessages = [];
                        for (final doc in streamDocs) {
                          allMessages.add(ChatMessage.fromMap(
                            doc.data(),
                            doc.id,
                            hasPendingWrites: doc.metadata.hasPendingWrites,
                          ));
                        }
                        allMessages.addAll(_olderMessages);

                        // De-duplicate in case older overlap
                        final seenIds = <String>{};
                        final uniqueMessages = allMessages.where((m) => seenIds.add(m.messageId)).toList();
                        _currentLoadedMessages = uniqueMessages;

                        if (uniqueMessages.isEmpty) {
                          return Center(
                            child: Text(
                              'No messages yet in ${widget.title}.\nSay hello! 👋',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey[500], fontSize: 14),
                            ),
                          );
                        }

                        // Compute first unread message for divider
                        final ownPointer = readPointers[widget.currentUid];
                        if (ownPointer != null) {
                          for (int i = uniqueMessages.length - 1; i >= 0; i--) {
                            if (uniqueMessages[i].timestamp.isAfter(ownPointer.lastReadAt)) {
                              _firstUnreadMessageId = uniqueMessages[i].messageId;
                              break;
                            }
                          }
                        }

                        return Stack(
                          children: [
                            ListView.builder(
                              controller: _scrollController,
                              reverse: true,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              itemCount: uniqueMessages.length + (_isLoadingMore ? 1 : 0),
                              itemBuilder: (context, index) {
                                if (_isLoadingMore && index == uniqueMessages.length) {
                                  return const Center(
                                    child: Padding(
                                      padding: EdgeInsets.all(8.0),
                                      child: SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      ),
                                    ),
                                  );
                                }

                                final msg = uniqueMessages[index];
                                final isMine = msg.senderId == widget.currentUid;
                                final key = _messageKeys.putIfAbsent(msg.messageId, () => GlobalKey());

                                // Consecutive test
                                bool isConsecutive = false;
                                if (index < uniqueMessages.length - 1) {
                                  final olderMsg = uniqueMessages[index + 1];
                                  isConsecutive = olderMsg.senderId == msg.senderId &&
                                      msg.timestamp.difference(olderMsg.timestamp).inMinutes < 3;
                                }

                                // Date separator test (older message has different day)
                                bool showDateDivider = false;
                                if (index == uniqueMessages.length - 1) {
                                  showDateDivider = true;
                                } else {
                                  final olderMsg = uniqueMessages[index + 1];
                                  final d1 = msg.timestamp.toLocal();
                                  final d2 = olderMsg.timestamp.toLocal();
                                  if (d1.year != d2.year || d1.month != d2.month || d1.day != d2.day) {
                                    showDateDivider = true;
                                  }
                                }

                                final isFirstUnread = msg.messageId == _firstUnreadMessageId;

                                return Column(
                                  key: key,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (showDateDivider) ChatDateDivider(date: msg.timestamp),
                                    if (isFirstUnread) const NewMessagesDivider(),
                                    MessageBubbleWidget(
                                      message: msg,
                                      isMine: isMine,
                                      isDirectChat: widget.kind == UnifiedChatKind.direct,
                                      showReadReceipts: showReadReceipts,
                                      otherReadPointer: otherPointer,
                                      groupReadPointers: readPointers,
                                      isConsecutive: isConsecutive,
                                      primaryColor: widget.primaryColor,
                                      canPin: _canUserPin(),
                                      isPinned: activePinIds.contains(msg.messageId),
                                      onReply: (m) => setState(() => _replyingTo = m),
                                      onPin: (m, duration) => _handlePinMessage(m, duration),
                                      onUnpin: (m) => _handleUnpinMessage(m.messageId),
                                      onEdit: (m) => setState(() => _editingMessage = m),
                                      onDelete: (m) {
                                        DBService.instance.deleteMessage(
                                          firmId: widget.firmId,
                                          conversationId: widget.conversationId,
                                          messageId: m.messageId,
                                        );
                                      },
                                      onJumpToQuoted: _jumpToMessage,
                                      currentUid: widget.currentUid,
                                      firmId: widget.firmId,
                                      conversationId: widget.conversationId,
                                      currentUserRole: widget.currentUserRole,
                                      participants: _participants,
                                      isHighlighted: _highlightedMessageId == msg.messageId,
                                    ),
                                  ],
                                );
                              },
                            ),

                            // Scroll to bottom floating button
                            if (_showScrollToBottom)
                              Positioned(
                                bottom: 16,
                                right: 16,
                                child: FloatingActionButton.small(
                                  backgroundColor: const Color.fromRGBO(40, 40, 44, 0.95),
                                  foregroundColor: Colors.white,
                                  onPressed: _scrollToBottom,
                                  child: const Icon(Icons.arrow_downward, size: 18),
                                ),
                              ),
                          ],
                        );
                      },
                    );
                  },
                ),
              ),

              // Typing Indicators
              StreamBuilder<List<TypingIndicatorStatus>>(
                stream: DBService.instance.streamTyping(
                  firmId: widget.firmId,
                  conversationId: widget.conversationId,
                ),
                builder: (context, typeSnap) {
                  return TypingIndicatorWidget(
                    typingUsers: typeSnap.data ?? [],
                    currentUid: widget.currentUid,
                  );
                },
              ),

              // Composer
              ChatComposerWidget(
                canPost: widget.canPost,
                cannotPostReason: widget.kind == UnifiedChatKind.allStaff
                    ? 'Only Admins and Leads can post announcements in #all-staff.'
                    : 'You do not have permission to post in this channel.',
                primaryColor: widget.primaryColor,
                participants: _participants,
                canMentionAll: _canUserMentionAll(),
                replyingTo: _replyingTo,
                editingMessage: _editingMessage,
                onCancelReply: () => setState(() => _replyingTo = null),
                onCancelEdit: () => setState(() => _editingMessage = null),
                onTyping: (text) {
                  if (_participants.isEmpty) {
                    _loadParticipants();
                  }
                  DBService.instance.setTypingStatus(
                    firmId: widget.firmId,
                    conversationId: widget.conversationId,
                    uid: widget.currentUid,
                    userName: widget.currentUserName,
                    isTyping: text.isNotEmpty,
                  );
                },
                onSendMessage: _handleSendMessage,
                currentUid: widget.currentUid,
                canCreatePoll: _canCreatePoll(),
                onCreatePoll: _handleCreatePoll,
              ),
            ],
          ),
        );
      },
    );
  }

  void _showPinnedMessagesModal(BuildContext context, List<PinnedMessage> pins) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color.fromRGBO(30, 29, 34, 1),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.amber.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.push_pin, color: Colors.amberAccent, size: 18),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Pinned Messages (${pins.length})',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.grey, size: 20),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                ),
                const Divider(color: Colors.white12, height: 24),
                if (pins.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.push_pin_outlined, size: 48, color: Colors.grey[600]),
                          const SizedBox(height: 12),
                          const Text(
                            'No Pinned Messages',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Long press any message to pin it so everyone can easily reference it.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.grey[400],
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: pins.length,
                      separatorBuilder: (_, __) => const Divider(color: Colors.white10, height: 1),
                      itemBuilder: (ctx, i) {
                        final p = pins[i];
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                          leading: CircleAvatar(
                            backgroundColor: Colors.amber.withOpacity(0.15),
                            child: const Icon(Icons.push_pin, color: Colors.amberAccent, size: 18),
                          ),
                          title: Text(
                            p.snippet.isNotEmpty ? p.snippet : '(Media or attachment)',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white, fontSize: 14),
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 4.0),
                            child: Row(
                              children: [
                                Text(
                                  'By ${p.pinnedBy}',
                                  style: TextStyle(color: Colors.grey[400], fontSize: 11),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: Colors.amber.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    p.formatRemaining(),
                                    style: const TextStyle(color: Colors.amberAccent, fontSize: 10),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          trailing: _canUserPin()
                              ? IconButton(
                                  icon: const Icon(Icons.close, color: Colors.grey, size: 18),
                                  tooltip: 'Unpin',
                                  onPressed: () {
                                    _handleUnpinMessage(p.messageId);
                                    Navigator.pop(ctx);
                                  },
                                )
                              : null,
                          onTap: () {
                            Navigator.pop(ctx);
                            _jumpToMessage(p.messageId);
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
  }

  AppBar _buildAppBar(bool showLastSeen, List<PinnedMessage> activePins) {
    return AppBar(
      backgroundColor: const Color.fromRGBO(28, 27, 27, 1),
      elevation: 0,
      titleSpacing: 0,
      actions: [
        IconButton(
          icon: const Icon(Icons.search, color: Colors.white70, size: 22),
          tooltip: 'Search Messages',
          onPressed: _openSearchSheet,
        ),
        IconButton(
          icon: Badge(
            isLabelVisible: activePins.isNotEmpty,
            label: Text(
              '${activePins.length}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10),
            ),
            backgroundColor: Colors.amber,
            textColor: Colors.black,
            child: Icon(
              Icons.push_pin_outlined,
              color: activePins.isNotEmpty ? Colors.amberAccent : Colors.grey[400],
            ),
          ),
          tooltip: 'Pinned Messages',
          onPressed: () => _showPinnedMessagesModal(context, activePins),
        ),
        const SizedBox(width: 4),
      ],
      title: Row(
        children: [
          Stack(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: widget.primaryColor.withOpacity(0.25),
                backgroundImage: (widget.otherUserImage != null && widget.otherUserImage!.isNotEmpty)
                    ? NetworkImage(widget.otherUserImage!)
                    : null,
                child: (widget.otherUserImage == null || widget.otherUserImage!.isEmpty)
                    ? Text(
                        widget.title.isNotEmpty ? widget.title[0].toUpperCase() : '?',
                        style: TextStyle(color: widget.primaryColor, fontWeight: FontWeight.bold),
                      )
                    : null,
              ),
              if (widget.kind == UnifiedChatKind.direct && widget.firmId != null && widget.otherUserId != null && showLastSeen)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: StreamBuilder<UserPresence?>(
                    stream: DBService.instance.streamPresence(widget.firmId!, widget.otherUserId!),
                    builder: (context, snap) {
                      final isOnline = snap.data?.isOnline == true;
                      if (!isOnline) return const SizedBox.shrink();
                      return Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: const Color(0xFF00E676),
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color.fromRGBO(28, 27, 27, 1), width: 1.8),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF00E676).withOpacity(0.7),
                              blurRadius: 3,
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                StreamBuilder<List<TypingIndicatorStatus>>(
                  stream: DBService.instance.streamTyping(
                    firmId: widget.firmId,
                    conversationId: widget.conversationId,
                  ),
                  builder: (context, typeSnap) {
                    final othersTyping = (typeSnap.data ?? [])
                        .where((t) => t.uid != widget.currentUid && t.isActive)
                        .toList();

                    if (othersTyping.isNotEmpty) {
                      final names = othersTyping.map((t) => t.userName).toSet().toList();
                      final String typingText = widget.kind == UnifiedChatKind.direct
                          ? 'typing...'
                          : (names.length == 1
                              ? '${names.first} is typing...'
                              : (names.length == 2
                                  ? '${names[0]} and ${names[1]} are typing...'
                                  : '${names[0]} and ${names.length - 1} others are typing...'));

                      return Row(
                        children: [
                          const BouncingDots(color: Color(0xFF00E5FF), dotSize: 3.5),
                          const SizedBox(width: 5),
                          Text(
                            typingText,
                            style: const TextStyle(
                              color: Color(0xFF00E5FF),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      );
                    }

                    if (widget.kind == UnifiedChatKind.direct &&
                        widget.firmId != null &&
                        widget.otherUserId != null &&
                        showLastSeen) {
                      return StreamBuilder<UserPresence?>(
                        stream: DBService.instance.streamPresence(
                          widget.firmId!,
                          widget.otherUserId!,
                        ),
                        builder: (context, snap) {
                          final presence = snap.data;
                          if (presence == null) {
                            return const SizedBox.shrink();
                          }
                          final isOnline = presence.isOnline;

                          return Row(
                            children: [
                              if (isOnline) ...[
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF00E676),
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFF00E676).withOpacity(0.75),
                                        blurRadius: 4,
                                        spreadRadius: 1,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 6),
                              ] else ...[
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.grey[500]!, width: 1.2),
                                  ),
                                ),
                                const SizedBox(width: 6),
                              ],
                              Text(
                                presence.formatLastSeen(),
                                style: TextStyle(
                                  color: isOnline ? const Color(0xFF00E676) : Colors.grey[400],
                                  fontSize: 11,
                                  fontWeight: isOnline ? FontWeight.w600 : FontWeight.normal,
                                ),
                              ),
                            ],
                          );
                        },
                      );
                    } else {
                      return Text(
                        widget.subtitle ??
                            (widget.kind == UnifiedChatKind.department
                                ? 'Department Channel'
                                : (widget.kind == UnifiedChatKind.project
                                    ? 'Project Group'
                                    : (widget.kind == UnifiedChatKind.allStaff
                                        ? 'Company Announcement'
                                        : (widget.kind == UnifiedChatKind.general
                                            ? 'General Team Chat'
                                            : 'Direct Chat')))),
                        style: TextStyle(color: Colors.grey[400], fontSize: 11),
                      );
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
