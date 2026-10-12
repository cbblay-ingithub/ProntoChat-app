import 'package:cloud_firestore/cloud_firestore.dart';

/// Pinned message item on conversation master doc
class PinnedMessage {
  final String messageId;
  final String snippet;
  final String pinnedBy;
  final DateTime pinnedAt;
  final DateTime pinnedUntil;

  const PinnedMessage({
    required this.messageId,
    required this.snippet,
    required this.pinnedBy,
    required this.pinnedAt,
    required this.pinnedUntil,
  });

  bool get isExpired => DateTime.now().isAfter(pinnedUntil);

  String formatRemaining() {
    final now = DateTime.now();
    if (now.isAfter(pinnedUntil)) return 'Expired';
    final diff = pinnedUntil.difference(now);
    if (diff.inDays >= 1) {
      return '${diff.inDays}d left';
    } else if (diff.inHours >= 1) {
      return '${diff.inHours}h left';
    } else {
      return '${diff.inMinutes}m left';
    }
  }

  factory PinnedMessage.fromMap(Map<String, dynamic> map) {
    DateTime parseDate(dynamic val, {DateTime? fallback}) {
      if (val is Timestamp) return val.toDate();
      if (val is int) return DateTime.fromMillisecondsSinceEpoch(val);
      if (val is String) return DateTime.tryParse(val) ?? (fallback ?? DateTime.now());
      return fallback ?? DateTime.now();
    }

    final at = parseDate(map['pinnedAt']);
    final until = parseDate(map['pinnedUntil'], fallback: at.add(const Duration(hours: 24)));

    return PinnedMessage(
      messageId: map['messageId'] as String? ?? '',
      snippet: map['snippet'] as String? ?? '',
      pinnedBy: map['pinnedBy'] as String? ?? '',
      pinnedAt: at,
      pinnedUntil: until,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'messageId': messageId,
      'snippet': snippet.length > 100 ? snippet.substring(0, 100) : snippet,
      'pinnedBy': pinnedBy,
      'pinnedAt': Timestamp.fromDate(pinnedAt),
      'pinnedUntil': Timestamp.fromDate(pinnedUntil),
    };
  }
}

/// User presence model from Firms/{firmId}/presence/{uid}
class UserPresence {
  final String uid;
  final DateTime lastSeenAt;

  static const List<String> _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];

  const UserPresence({
    required this.uid,
    required this.lastSeenAt,
  });

  factory UserPresence.fromMap(String uid, Map<String, dynamic> data) {
    DateTime parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is int) return DateTime.fromMillisecondsSinceEpoch(val);
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      return DateTime.now();
    }

    return UserPresence(
      uid: uid,
      lastSeenAt: parseDate(data['lastSeenAt']),
    );
  }

  factory UserPresence.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    return UserPresence.fromMap(doc.id, doc.data() ?? {});
  }

  /// Whether the user was active within roughly the last 5 minutes
  bool get isOnline {
    final diff = DateTime.now().difference(lastSeenAt);
    return diff.inMinutes < 5;
  }

  /// Format last seen display text with calendar date and time
  String formatLastSeen() {
    if (isOnline) return 'Online';
    final now = DateTime.now();
    final local = lastSeenAt.toLocal();
    final isToday = local.year == now.year && local.month == now.month && local.day == now.day;
    final yesterday = now.subtract(const Duration(days: 1));
    final isYesterday = local.year == yesterday.year && local.month == yesterday.month && local.day == yesterday.day;
    final timeStr = '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
    final monthName = _months[local.month - 1];

    if (isToday) {
      return 'last seen today, $monthName ${local.day} at $timeStr';
    } else if (isYesterday) {
      return 'last seen yesterday, $monthName ${local.day} at $timeStr';
    } else if (local.year == now.year) {
      return 'last seen $monthName ${local.day} at $timeStr';
    } else {
      return 'last seen $monthName ${local.day}, ${local.year} at $timeStr';
    }
  }
}

/// Typing indicator model from .../typing/{uid}
class TypingIndicatorStatus {
  final String uid;
  final String userName;
  final DateTime updatedAt;

  const TypingIndicatorStatus({
    required this.uid,
    required this.userName,
    required this.updatedAt,
  });

  factory TypingIndicatorStatus.fromMap(String uid, Map<String, dynamic> data) {
    DateTime parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is int) return DateTime.fromMillisecondsSinceEpoch(val);
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      return DateTime.now();
    }

    return TypingIndicatorStatus(
      uid: uid,
      userName: data['userName'] as String? ?? 'Colleague',
      updatedAt: parseDate(data['updatedAt']),
    );
  }

  factory TypingIndicatorStatus.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    return TypingIndicatorStatus.fromMap(doc.id, doc.data() ?? {});
  }

  /// Active if updated within the last 5 seconds (with clock skew tolerance)
  bool get isActive {
    final now = DateTime.now();
    final diff = now.difference(updatedAt).inSeconds;
    // Skew tolerance: if timestamp is slightly in future or <= 5s in past
    return diff >= -2 && diff <= 5;
  }
}

/// Read pointer model from .../reads/{uid}
class ReadPointer {
  final String uid;
  final String lastReadMessageId;
  final DateTime lastReadAt;
  final bool hasMention;

  const ReadPointer({
    required this.uid,
    required this.lastReadMessageId,
    required this.lastReadAt,
    this.hasMention = false,
  });

  factory ReadPointer.fromMap(String uid, Map<String, dynamic> data) {
    DateTime parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is int) return DateTime.fromMillisecondsSinceEpoch(val);
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      return DateTime.now();
    }

    return ReadPointer(
      uid: uid,
      lastReadMessageId: data['lastReadMessageId'] as String? ?? '',
      lastReadAt: parseDate(data['lastReadAt']),
      hasMention: data['hasMention'] == true,
    );
  }

  factory ReadPointer.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    return ReadPointer.fromMap(doc.id, doc.data() ?? {});
  }

  Map<String, dynamic> toMap() {
    return {
      'lastReadMessageId': lastReadMessageId,
      'lastReadAt': Timestamp.fromDate(lastReadAt),
      'hasMention': hasMention,
    };
  }
}
