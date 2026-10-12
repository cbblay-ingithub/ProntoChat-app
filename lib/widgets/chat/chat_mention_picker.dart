import 'package:flutter/material.dart';

class ChatMentionPicker extends StatelessWidget {
  final List<Map<String, String>> participants;
  final String query;
  final bool canMentionAll;
  final ValueChanged<Map<String, String>> onSelectParticipant;

  const ChatMentionPicker({
    super.key,
    required this.participants,
    required this.query,
    required this.canMentionAll,
    required this.onSelectParticipant,
  });

  @override
  Widget build(BuildContext context) {
    final cleanQuery = query.toLowerCase().replaceAll('@', '').trim();

    final filtered = participants.where((p) {
      if (cleanQuery.isEmpty) return true;
      final name = (p['name'] ?? '').toLowerCase();
      final email = (p['email'] ?? '').toLowerCase();
      final username = email.contains('@') ? email.split('@').first : email;
      return name.contains(cleanQuery) ||
          email.contains(cleanQuery) ||
          username.contains(cleanQuery);
    }).toList();

    final showAll = canMentionAll && ('all'.contains(cleanQuery) || cleanQuery.isEmpty);

    if (filtered.isEmpty && !showAll) {
      if (participants.isEmpty) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: const Color.fromRGBO(34, 33, 33, 0.98),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            border: Border(
              top: BorderSide(color: Colors.blueAccent.withOpacity(0.3), width: 1.5),
            ),
          ),
          child: const Row(
            children: [
              Icon(Icons.info_outline, color: Colors.grey, size: 16),
              SizedBox(width: 8),
              Text(
                'No team members found to mention',
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ],
          ),
        );
      }
      return const SizedBox.shrink();
    }

    return Container(
      constraints: const BoxConstraints(maxHeight: 200),
      decoration: BoxDecoration(
        color: const Color.fromRGBO(34, 33, 33, 0.98),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
        border: Border(
          top: BorderSide(color: Colors.blueAccent.withOpacity(0.3), width: 1.5),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(vertical: 4),
        children: [
          if (showAll)
            ListTile(
              dense: true,
              leading: CircleAvatar(
                radius: 14,
                backgroundColor: Colors.amber.withOpacity(0.2),
                child: const Text('@', style: TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.bold, fontSize: 13)),
              ),
              title: const Row(
                children: [
                  Text('@all', style: TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.bold, fontSize: 13)),
                  SizedBox(width: 8),
                  Text('(Notify all participants)', style: TextStyle(color: Colors.grey, fontSize: 11)),
                ],
              ),
              onTap: () => onSelectParticipant({'uid': 'all', 'name': 'all'}),
            ),
          ...filtered.map((p) {
            final name = p['name'] ?? 'Colleague';
            final email = p['email'] ?? '';
            return ListTile(
              dense: true,
              leading: CircleAvatar(
                radius: 14,
                backgroundColor: Colors.blueAccent.withOpacity(0.2),
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
              title: Text(
                name,
                style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
              ),
              subtitle: (email.isNotEmpty && email != name)
                  ? Text(
                      email,
                      style: TextStyle(color: Colors.grey[400], fontSize: 11),
                    )
                  : null,
              onTap: () => onSelectParticipant(p),
            );
          }),
        ],
      ),
    );
  }
}
