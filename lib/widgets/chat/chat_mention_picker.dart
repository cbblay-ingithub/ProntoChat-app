import 'package:flutter/material.dart';
import '../../theme/pc_tokens.dart';

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
    final tokens = context.pcTokens;
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

    final showAll =
        canMentionAll && ('all'.contains(cleanQuery) || cleanQuery.isEmpty);

    if (filtered.isEmpty && !showAll) {
      if (participants.isEmpty) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: tokens.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            border: Border(top: BorderSide(color: tokens.border)),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline_rounded, color: tokens.textMuted, size: 16),
              const SizedBox(width: 8),
              Text(
                'No team members found to mention',
                style: TextStyle(color: tokens.textMuted, fontSize: 12),
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
        color: tokens.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
        border: Border(top: BorderSide(color: tokens.primaryBorder, width: 1.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, -4),
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
                backgroundColor: tokens.warningSoft,
                child: Text(
                  '@',
                  style: TextStyle(
                    color: tokens.warningAccent,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
              title: Row(
                children: [
                  Text(
                    '@all',
                    style: TextStyle(
                      color: tokens.warningAccent,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '(Notify all participants)',
                    style: TextStyle(color: tokens.textMuted, fontSize: 11),
                  ),
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
                backgroundColor: tokens.primarySoft,
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style: TextStyle(
                    color: tokens.primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
              title: Text(
                name,
                style: TextStyle(
                  color: tokens.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: (email.isNotEmpty && email != name)
                  ? Text(
                      email,
                      style: TextStyle(color: tokens.textMuted, fontSize: 11),
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
