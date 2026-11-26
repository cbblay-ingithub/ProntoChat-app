import 'package:flutter/material.dart';
import '../../models/poll_model.dart';
import '../../services/db_service.dart';
import '../../theme/pc_tokens.dart';

class PollVotersSheet extends StatefulWidget {
  final String? firmId;
  final String conversationId;
  final String pollMessageId;
  final PollModel poll;
  final List<Map<String, String>> participants;

  const PollVotersSheet({
    super.key,
    this.firmId,
    required this.conversationId,
    required this.pollMessageId,
    required this.poll,
    required this.participants,
  });

  @override
  State<PollVotersSheet> createState() => _PollVotersSheetState();
}

class _PollVotersSheetState extends State<PollVotersSheet> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _votes = [];

  @override
  void initState() {
    super.initState();
    _loadVoters();
  }

  Future<void> _loadVoters() async {
    try {
      final list = await DBService.instance.loadPollVoters(
        firmId: widget.firmId,
        conversationId: widget.conversationId,
        pollMessageId: widget.pollMessageId,
      );
      if (mounted) {
        setState(() {
          _votes = list;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _getUserName(String uid) {
    final match = widget.participants.firstWhere(
      (p) => p['uid'] == uid,
      orElse: () => {'name': 'Member'},
    );
    return match['name'] ?? 'Member';
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.pcTokens;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.72,
      ),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 10, bottom: 6),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: tokens.borderStrong,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Poll Votes',
                    style: TextStyle(
                      color: tokens.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded, color: tokens.textMuted),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  widget.poll.question,
                  style: TextStyle(
                    color: tokens.textSecondary,
                    fontSize: 13,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Divider(color: tokens.border, height: 1),
            ),
            Expanded(
              child: _isLoading
                  ? Center(
                      child: CircularProgressIndicator(
                        color: tokens.projectAccent,
                      ),
                    )
                  : _votes.isEmpty
                      ? Center(
                          child: Text(
                            'No votes yet.',
                            style: TextStyle(color: tokens.textMuted),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          itemCount: widget.poll.options.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 12),
                          itemBuilder: (ctx, index) {
                            final option = widget.poll.options[index];
                            final votersForOption = _votes.where((v) {
                              final ids = (v['optionIds'] as List<dynamic>?)
                                      ?.map((e) => e.toString())
                                      .toList() ??
                                  [];
                              return ids.contains(option.id);
                            }).toList();

                            return Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: tokens.surfaceSubtle,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: tokens.border),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          option.text,
                                          style: TextStyle(
                                            color: tokens.textPrimary,
                                            fontWeight: FontWeight.w700,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                      Text(
                                        '${votersForOption.length} votes',
                                        style: TextStyle(
                                          color: tokens.projectAccent,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (votersForOption.isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    Wrap(
                                      spacing: 6,
                                      runSpacing: 6,
                                      children: votersForOption.map((v) {
                                        final uid = v['uid'] as String? ?? '';
                                        final name = _getUserName(uid);
                                        return Chip(
                                          backgroundColor: tokens.surface,
                                          side: BorderSide(color: tokens.border),
                                          labelPadding:
                                              const EdgeInsets.symmetric(
                                            horizontal: 4,
                                          ),
                                          avatar: CircleAvatar(
                                            backgroundColor: tokens.projectSoft,
                                            child: Text(
                                              name.isNotEmpty
                                                  ? name[0].toUpperCase()
                                                  : '?',
                                              style: TextStyle(
                                                fontSize: 10,
                                                color: tokens.projectAccent,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                          label: Text(
                                            name,
                                            style: TextStyle(
                                              color: tokens.textPrimary,
                                              fontSize: 11,
                                            ),
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                  ],
                                ],
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
