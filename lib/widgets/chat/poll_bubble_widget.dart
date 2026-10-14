import 'dart:async';
import 'package:flutter/material.dart';
import '../../models/chat_message.dart';
import '../../models/poll_model.dart';
import '../../services/db_service.dart';
import 'poll_voters_sheet.dart';

class PollBubbleWidget extends StatefulWidget {
  final ChatMessage message;
  final String? firmId;
  final String conversationId;
  final String currentUid;
  final String currentUserRole;
  final Color primaryColor;
  final List<Map<String, String>> participants;

  const PollBubbleWidget({
    super.key,
    required this.message,
    this.firmId,
    required this.conversationId,
    required this.currentUid,
    required this.currentUserRole,
    required this.primaryColor,
    this.participants = const [],
  });

  @override
  State<PollBubbleWidget> createState() => _PollBubbleWidgetState();
}

class _PollBubbleWidgetState extends State<PollBubbleWidget> {
  Map<String, int> _counts = {};
  List<String> _userSelectedOptionIds = [];
  bool _isLoadingCounts = false;
  bool _isVoting = false;

  StreamSubscription? _voteSub;
  Timer? _refreshTimer;

  PollModel get poll => widget.message.poll!;

  @override
  void initState() {
    super.initState();
    _fetchTallies();
    _listenToUserVote();

    // Modest refresh timer while visible (every 60 seconds)
    _refreshTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      if (mounted && !poll.isClosed) {
        _fetchTallies();
      }
    });
  }

  @override
  void didUpdateWidget(covariant PollBubbleWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.message.messageId != widget.message.messageId) {
      _voteSub?.cancel();
      _fetchTallies();
      _listenToUserVote();
    }
  }

  @override
  void dispose() {
    _voteSub?.cancel();
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _listenToUserVote() {
    _voteSub = DBService.instance
        .streamUserPollVote(
          firmId: widget.firmId,
          conversationId: widget.conversationId,
          pollMessageId: widget.message.messageId,
          uid: widget.currentUid,
        )
        .listen((snapshot) {
      if (snapshot.exists && snapshot.data() != null) {
        final data = snapshot.data()!;
        final raw = data['optionIds'];
        if (raw is List) {
          if (mounted) {
            setState(() {
              _userSelectedOptionIds = raw.map((e) => e.toString()).toList();
            });
          }
        }
      } else {
        if (mounted) {
          setState(() {
            _userSelectedOptionIds = [];
          });
        }
      }
    });
  }

  Future<void> _fetchTallies() async {
    if (_isLoadingCounts) return;
    _isLoadingCounts = true;

    try {
      final counts = await DBService.instance.getPollOptionCounts(
        firmId: widget.firmId,
        conversationId: widget.conversationId,
        pollMessageId: widget.message.messageId,
        optionIds: poll.options.map((o) => o.id).toList(),
      );
      if (mounted) {
        setState(() {
          _counts = counts;
          _isLoadingCounts = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingCounts = false);
    }
  }

  Future<void> _handleVote(String optionId) async {
    if (poll.isClosed || _isVoting) return;

    List<String> newSelection;
    if (poll.allowMultiple) {
      newSelection = List<String>.from(_userSelectedOptionIds);
      if (newSelection.contains(optionId)) {
        newSelection.remove(optionId);
      } else {
        newSelection.add(optionId);
      }
    } else {
      if (_userSelectedOptionIds.contains(optionId)) {
        return; // Already voted for this single option
      }
      newSelection = [optionId];
    }

    setState(() {
      _userSelectedOptionIds = newSelection;
      _isVoting = true;
    });

    try {
      await DBService.instance.castPollVote(
        firmId: widget.firmId,
        conversationId: widget.conversationId,
        pollMessageId: widget.message.messageId,
        uid: widget.currentUid,
        optionIds: newSelection,
      );
      await _fetchTallies();
    } catch (e) {
      debugPrint('Notice casting vote: $e');
    } finally {
      if (mounted) setState(() => _isVoting = false);
    }
  }

  Future<void> _handleClosePoll() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color.fromRGBO(34, 33, 35, 1),
        title: const Text('Close Poll?', style: TextStyle(color: Colors.white)),
        content: const Text(
          'No further votes will be accepted. This cannot be undone.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Close Poll'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await DBService.instance.closePoll(
        firmId: widget.firmId,
        conversationId: widget.conversationId,
        pollMessageId: widget.message.messageId,
      );
    }
  }

  void _showVotersSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => PollVotersSheet(
        firmId: widget.firmId,
        conversationId: widget.conversationId,
        pollMessageId: widget.message.messageId,
        poll: poll,
        participants: widget.participants,
      ),
    );
  }

  String _formatRemainingTime() {
    if (poll.closedAt != null) return 'Closed';
    if (poll.closesAt == null) return '';
    final diff = poll.closesAt!.difference(DateTime.now());
    if (diff.isNegative) return 'Closed';
    if (diff.inDays > 0) return '${diff.inDays}d left';
    if (diff.inHours > 0) return '${diff.inHours}h left';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m left';
    return 'Closing soon';
  }

  @override
  Widget build(BuildContext context) {
    final totalVotes = _counts.values.fold<int>(0, (sum, val) => sum + val);
    final isClosed = poll.isClosed;
    final role = widget.currentUserRole.toLowerCase();
    final canClose = !isClosed &&
        (poll.createdBy == widget.currentUid ||
            role == 'admin' ||
            role == 'super_admin');

    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 320),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Question header
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.poll, color: Colors.purpleAccent, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  poll.question,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),

          // Subheader info: multiple choice or single
          Row(
            children: [
              Text(
                poll.allowMultiple ? 'Select one or more' : 'Select one',
                style: TextStyle(color: Colors.grey[400], fontSize: 11),
              ),
              const Spacer(),
              if (isClosed)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'Closed',
                    style: TextStyle(color: Colors.redAccent, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                )
              else if (poll.closesAt != null)
                Text(
                  _formatRemainingTime(),
                  style: const TextStyle(color: Colors.amberAccent, fontSize: 11),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // Options list
          ...poll.options.map((option) {
            final optionVotes = _counts[option.id] ?? 0;
            final percentage = totalVotes > 0 ? (optionVotes / totalVotes) : 0.0;
            final isSelected = _userSelectedOptionIds.contains(option.id);

            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: InkWell(
                onTap: isClosed ? null : () => _handleVote(option.id),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.25),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSelected ? Colors.purpleAccent : Colors.white12,
                      width: isSelected ? 1.5 : 1,
                    ),
                  ),
                  child: Stack(
                    children: [
                      // Percentage fill bar
                      FractionallySizedBox(
                        widthFactor: percentage,
                        child: Container(
                          height: 42,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Colors.purpleAccent.withOpacity(0.35)
                                : Colors.white.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(9),
                          ),
                        ),
                      ),
                      // Content inside option
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        child: Row(
                          children: [
                            Icon(
                              poll.allowMultiple
                                  ? (isSelected ? Icons.check_box : Icons.check_box_outline_blank)
                                  : (isSelected ? Icons.radio_button_checked : Icons.radio_button_off),
                              size: 16,
                              color: isSelected ? Colors.purpleAccent : Colors.grey,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                option.text,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '${(percentage * 100).toInt()}%',
                              style: TextStyle(
                                color: isSelected ? Colors.purpleAccent : Colors.grey[400],
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
          const SizedBox(height: 6),

          // Footer: Total votes and buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$totalVotes vote${totalVotes == 1 ? '' : 's'}',
                style: TextStyle(color: Colors.grey[400], fontSize: 11),
              ),
              Row(
                children: [
                  if (canClose) ...[
                    GestureDetector(
                      onTap: _handleClosePoll,
                      child: const Text(
                        'Close',
                        style: TextStyle(color: Colors.redAccent, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  GestureDetector(
                    onTap: _showVotersSheet,
                    child: const Text(
                      'View votes',
                      style: TextStyle(color: Colors.purpleAccent, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
