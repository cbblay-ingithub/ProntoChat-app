import 'package:cloud_firestore/cloud_firestore.dart';
import 'poll_model.dart';
import 'media_ref.dart';
import '../utils/search_token_util.dart';

class MessageMention {
  final String uid;
  final String name;
  final int start;
  final int end;

  const MessageMention({
    required this.uid,
    required this.name,
    required this.start,
    required this.end,
  });

  factory MessageMention.fromMap(Map<String, dynamic> map) {
    return MessageMention(
      uid: map['uid'] as String? ?? '',
      name: map['name'] as String? ?? '',
      start: (map['start'] as num?)?.toInt() ?? 0,
      end: (map['end'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'name': name,
      'start': start,
      'end': end,
    };
  }
}

class MessageReplyTo {
  final String messageId;
  final String senderId;
  final String senderName;
  final String snippet;
  final String kind; // 'text', 'image', 'poll', etc.

  const MessageReplyTo({
    required this.messageId,
    required this.senderId,
    required this.senderName,
    required this.snippet,
    this.kind = 'text',
  });

  factory MessageReplyTo.fromMap(Map<String, dynamic> map) {
    return MessageReplyTo(
      messageId: map['messageId'] as String? ?? '',
      senderId: map['senderId'] as String? ?? '',
      senderName: map['senderName'] as String? ?? 'Colleague',
      snippet: map['snippet'] as String? ?? '',
      kind: map['kind'] as String? ?? 'text',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'messageId': messageId,
      'senderId': senderId,
      'senderName': senderName,
      'snippet': snippet.length > 100 ? snippet.substring(0, 100) : snippet,
      'kind': kind,
    };
  }
}

class ChatMessage {
  final String messageId;
  final String senderId;
  final String senderName;
  final String text;
  final DateTime timestamp;
  final String type;
  final List<MessageMention> mentions;
  final MessageReplyTo? replyTo;
  final DateTime? editedAt;
  final bool deleted;
  final bool isPending;
  final bool isFailed;
  final bool hasPendingWrites;
  final List<String> searchTokens;
  final PollModel? poll;
  final MediaRef? media;

  ChatMessage({
    required this.messageId,
    required this.senderId,
    required this.senderName,
    required this.text,
    required this.timestamp,
    this.type = 'text',
    this.mentions = const [],
    this.replyTo,
    this.editedAt,
    this.deleted = false,
    this.isPending = false,
    this.isFailed = false,
    this.hasPendingWrites = false,
    this.searchTokens = const [],
    this.poll,
    this.media,
  });

  /// Factory constructor to parse Firestore document into ChatMessage
  factory ChatMessage.fromMap(Map<String, dynamic> map, String id, {bool hasPendingWrites = false}) {
    DateTime parsedTime;
    final dynamic rawTimestamp = map['timestamp'];
    if (rawTimestamp is Timestamp) {
      parsedTime = rawTimestamp.toDate();
    } else if (rawTimestamp is int) {
      parsedTime = DateTime.fromMillisecondsSinceEpoch(rawTimestamp);
    } else if (rawTimestamp is String) {
      parsedTime = DateTime.tryParse(rawTimestamp) ?? DateTime.now();
    } else {
      parsedTime = DateTime.now();
    }

    DateTime? parsedEditedTime;
    final dynamic rawEditedAt = map['editedAt'];
    if (rawEditedAt is Timestamp) {
      parsedEditedTime = rawEditedAt.toDate();
    } else if (rawEditedAt is int) {
      parsedEditedTime = DateTime.fromMillisecondsSinceEpoch(rawEditedAt);
    } else if (rawEditedAt is String) {
      parsedEditedTime = DateTime.tryParse(rawEditedAt);
    }

    List<MessageMention> parsedMentions = [];
    if (map['mentions'] is List) {
      parsedMentions = (map['mentions'] as List)
          .whereType<Map<String, dynamic>>()
          .map((m) => MessageMention.fromMap(m))
          .toList();
    }

    MessageReplyTo? parsedReplyTo;
    if (map['replyTo'] is Map) {
      parsedReplyTo = MessageReplyTo.fromMap(Map<String, dynamic>.from(map['replyTo'] as Map));
    }

    List<String> parsedSearchTokens = [];
    if (map['searchTokens'] is List) {
      parsedSearchTokens = (map['searchTokens'] as List).map((e) => e.toString()).toList();
    }

    PollModel? parsedPoll;
    if (map['poll'] is Map) {
      parsedPoll = PollModel.fromMap(Map<String, dynamic>.from(map['poll'] as Map));
    }

    MediaRef? parsedMedia;
    if (map['media'] is Map) {
      parsedMedia = MediaRef.fromMap(Map<String, dynamic>.from(map['media'] as Map));
    }

    // Handles both text and content fields for full backward compatibility
    final rawText = (map['text'] ?? map['content'] ?? '') as String;

    return ChatMessage(
      messageId: id,
      senderId: map['senderId'] ?? '',
      senderName: map['senderName'] ?? '',
      text: rawText,
      timestamp: parsedTime,
      type: map['type'] ?? 'text',
      mentions: parsedMentions,
      replyTo: parsedReplyTo,
      editedAt: parsedEditedTime,
      deleted: map['deleted'] == true,
      hasPendingWrites: hasPendingWrites,
      searchTokens: parsedSearchTokens,
      poll: parsedPoll,
      media: parsedMedia,
    );
  }

  /// Converts ChatMessage instance into Firestore-compatible Map
  Map<String, dynamic> toMap() {
    final Map<String, dynamic> map = {
      'senderId': senderId,
      'senderName': senderName,
      'text': text,
      'content': text, // Preserves compatibility with direct chat readers
      'timestamp': FieldValue.serverTimestamp(),
      'type': type,
      'deleted': deleted,
    };

    if (deleted) {
      map['searchTokens'] = <String>[];
    } else if (searchTokens.isNotEmpty) {
      map['searchTokens'] = searchTokens;
    } else {
      map['searchTokens'] = SearchTokenUtil.generateTokens(text: text, poll: poll);
    }

    if (poll != null) {
      map['poll'] = poll!.toMap();
    }

    if (media != null) {
      map['media'] = media!.toMap();
    }

    if (mentions.isNotEmpty) {
      map['mentions'] = mentions.map((m) => m.toMap()).toList();
      final hasAll = mentions.any((m) => m.uid == 'all');
      if (hasAll) {
        map['hasAllMention'] = true;
      }
    }

    if (replyTo != null) {
      map['replyTo'] = replyTo!.toMap();
    }

    if (editedAt != null) {
      map['editedAt'] = Timestamp.fromDate(editedAt!);
    }

    return map;
  }

  ChatMessage copyWith({
    String? messageId,
    String? senderId,
    String? senderName,
    String? text,
    DateTime? timestamp,
    String? type,
    List<MessageMention>? mentions,
    MessageReplyTo? replyTo,
    DateTime? editedAt,
    bool? deleted,
    bool? isPending,
    bool? isFailed,
    bool? hasPendingWrites,
    List<String>? searchTokens,
    PollModel? poll,
    MediaRef? media,
  }) {
    return ChatMessage(
      messageId: messageId ?? this.messageId,
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
      text: text ?? this.text,
      timestamp: timestamp ?? this.timestamp,
      type: type ?? this.type,
      mentions: mentions ?? this.mentions,
      replyTo: replyTo ?? this.replyTo,
      editedAt: editedAt ?? this.editedAt,
      deleted: deleted ?? this.deleted,
      isPending: isPending ?? this.isPending,
      isFailed: isFailed ?? this.isFailed,
      hasPendingWrites: hasPendingWrites ?? this.hasPendingWrites,
      searchTokens: searchTokens ?? this.searchTokens,
      poll: poll ?? this.poll,
      media: media ?? this.media,
    );
  }
}
