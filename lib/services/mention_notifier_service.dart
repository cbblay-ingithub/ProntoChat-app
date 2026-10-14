import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/mention_inbox_item.dart';
import 'db_service.dart';
import 'snackbar_service.dart';

class MentionNotifierService {
  MentionNotifierService._internal();
  static final MentionNotifierService instance = MentionNotifierService._internal();

  StreamSubscription? _unreadSub;
  final Set<String> _seenMessageIds = {};
  bool _initialized = false;

  void startListening({
    required String firmId,
    required String uid,
    required BuildContext context,
    required void Function(MentionInboxItem item) onOpenMention,
  }) {
    _unreadSub?.cancel();
    _initialized = false;

    _unreadSub = DBService.instance
        .streamUnreadMentions(firmId: firmId, uid: uid, limit: 5)
        .listen((snapshot) {
      final items = snapshot.docs.map((d) => MentionInboxItem.fromMap(d.id, d.data())).toList();

      if (!_initialized) {
        // Record currently existing unread items so we don't spam banner on first launch
        for (final item in items) {
          _seenMessageIds.add(item.messageId);
        }
        _initialized = true;
        return;
      }

      for (final item in items) {
        if (!_seenMessageIds.contains(item.messageId)) {
          _seenMessageIds.add(item.messageId);
          _showMentionBanner(context, item, onOpenMention);
        }
      }
    });
  }

  void _showMentionBanner(
    BuildContext context,
    MentionInboxItem item,
    void Function(MentionInboxItem item) onOpenMention,
  ) {
    // Distinct haptic for mentions
    HapticFeedback.heavyImpact();

    // Show distinct foreground in-app banner
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;

    messenger.showSnackBar(
      SnackBar(
        backgroundColor: const Color.fromRGBO(30, 36, 48, 1),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Colors.lightBlueAccent, width: 1.2),
        ),
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(
                color: Color(0x3300E5FF),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.alternate_email, color: Colors.lightBlueAccent, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${item.senderName} mentioned you',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    item.snippet,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
        action: SnackBarAction(
          label: 'View',
          textColor: Colors.lightBlueAccent,
          onPressed: () {
            onOpenMention(item);
          },
        ),
      ),
    );
  }

  void stopListening() {
    _unreadSub?.cancel();
    _unreadSub = null;
    _seenMessageIds.clear();
    _initialized = false;
  }
}
