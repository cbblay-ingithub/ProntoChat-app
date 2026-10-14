import 'package:flutter/material.dart';
import '../../models/poll_model.dart';
import '../../services/db_service.dart';

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
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.7,
      ),
      decoration: const BoxDecoration(
        color: Color.fromRGBO(28, 27, 28, 1),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 10, bottom: 6),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[700],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Poll Votes',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.grey),
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
                  style: const TextStyle(color: Colors.white70, fontSize: 13, fontStyle: FontStyle.italic),
                ),
              ),
            ),
            const Divider(color: Colors.white12, height: 20),

            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _votes.isEmpty
                      ? const Center(
                          child: Text('No votes yet.', style: TextStyle(color: Colors.grey)),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          itemCount: widget.poll.options.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 14),
                          itemBuilder: (ctx, index) {
                            final option = widget.poll.options[index];
                            final votersForOption = _votes.where((v) {
                              final ids = (v['optionIds'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];
                              return ids.contains(option.id);
                            }).toList();

                            return Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color.fromRGBO(38, 37, 40, 1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          option.text,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                      Text(
                                        '${votersForOption.length} votes',
                                        style: const TextStyle(color: Colors.purpleAccent, fontSize: 12),
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
                                          backgroundColor: Colors.white10,
                                          labelPadding: const EdgeInsets.symmetric(horizontal: 4),
                                          avatar: CircleAvatar(
                                            backgroundColor: Colors.purpleAccent.withOpacity(0.4),
                                            child: Text(
                                              name.isNotEmpty ? name[0].toUpperCase() : '?',
                                              style: const TextStyle(fontSize: 10, color: Colors.white),
                                            ),
                                          ),
                                          label: Text(name, style: const TextStyle(color: Colors.white70, fontSize: 11)),
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
