import 'package:cloud_firestore/cloud_firestore.dart';

class MentionInboxItem {
  final String messageId;
  final String conversationId;
  final String senderId;
  final String senderName;
  final String snippet;
  final DateTime createdAt;
  final bool read;

  const MentionInboxItem({
    required this.messageId,
    required this.conversationId,
    required this.senderId,
    required this.senderName,
    required this.snippet,
    required this.createdAt,
    this.read = false,
  });

  factory MentionInboxItem.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    return MentionInboxItem.fromMap(doc.id, doc.data() ?? {});
  }

  factory MentionInboxItem.fromMap(String id, Map<String, dynamic> data) {
    DateTime parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is int) return DateTime.fromMillisecondsSinceEpoch(val);
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      return DateTime.now();
    }

    return MentionInboxItem(
      messageId: data['messageId'] as String? ?? id,
      conversationId: data['conversationId'] as String? ?? '',
      senderId: data['senderId'] as String? ?? '',
      senderName: data['senderName'] as String? ?? 'Colleague',
      snippet: data['snippet'] as String? ?? '',
      createdAt: parseDate(data['createdAt']),
      read: data['read'] == true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'messageId': messageId,
      'conversationId': conversationId,
      'senderId': senderId,
      'senderName': senderName,
      'snippet': snippet.length > 100 ? snippet.substring(0, 100) : snippet,
      'createdAt': Timestamp.fromDate(createdAt),
      'read': read,
    };
  }

  MentionInboxItem copyWith({
    String? messageId,
    String? conversationId,
    String? senderId,
    String? senderName,
    String? snippet,
    DateTime? createdAt,
    bool? read,
  }) {
    return MentionInboxItem(
      messageId: messageId ?? this.messageId,
      conversationId: conversationId ?? this.conversationId,
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
      snippet: snippet ?? this.snippet,
      createdAt: createdAt ?? this.createdAt,
      read: read ?? this.read,
    );
  }
}
