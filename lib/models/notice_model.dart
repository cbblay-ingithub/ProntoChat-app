import 'package:cloud_firestore/cloud_firestore.dart';
import 'media_ref.dart';

/// Notice type discriminator
enum NoticeType {
  announcement,
  urgent,
  policy,
}

extension NoticeTypeExtension on NoticeType {
  String get value {
    switch (this) {
      case NoticeType.announcement:
        return 'announcement';
      case NoticeType.urgent:
        return 'urgent';
      case NoticeType.policy:
        return 'policy';
    }
  }

  static NoticeType fromString(String? val) {
    switch (val?.toLowerCase()) {
      case 'urgent':
        return NoticeType.urgent;
      case 'policy':
        return NoticeType.policy;
      case 'announcement':
      default:
        return NoticeType.announcement;
    }
  }

  String get label {
    switch (this) {
      case NoticeType.announcement:
        return 'Announcement';
      case NoticeType.urgent:
        return 'Urgent Alert';
      case NoticeType.policy:
        return 'Policy';
    }
  }
}

/// Notice model representing full content stored in `Firms/{firmId}/notices/{noticeId}`.
class NoticeModel {
  final String id;
  final NoticeType type;
  final String title;
  final String body;
  final List<MediaRef> media;
  final List<String> videoLinks;
  final List<String> audienceKeys;
  final List<String> audienceNames;
  final String authorId;
  final String authorName;
  final String authorLabel;
  final bool pinned;
  final DateTime? expiresAt;
  final int version;
  final String status; // 'published' | 'retracted'
  final DateTime createdAt;
  final DateTime? editedAt;
  final DateTime? retractedAt;
  final String? retractedBy;

  const NoticeModel({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    this.media = const [],
    this.videoLinks = const [],
    required this.audienceKeys,
    required this.audienceNames,
    required this.authorId,
    required this.authorName,
    required this.authorLabel,
    this.pinned = false,
    this.expiresAt,
    this.version = 1,
    this.status = 'published',
    required this.createdAt,
    this.editedAt,
    this.retractedAt,
    this.retractedBy,
  });

  bool get isAnnouncement => type == NoticeType.announcement;
  bool get isUrgent => type == NoticeType.urgent;
  bool get isPolicy => type == NoticeType.policy;
  bool get isPublished => status == 'published';
  bool get isRetracted => status == 'retracted';
  bool get isEdited => editedAt != null;
  bool get isExpired => expiresAt != null && DateTime.now().isAfter(expiresAt!);

  /// Displays recipient summary: 'Everyone' if firm-wide, else snapshot names.
  String get audienceSummary {
    if (audienceKeys.contains('firm')) {
      return 'Everyone';
    }
    if (audienceNames.isNotEmpty) {
      if (audienceNames.length == 1) return audienceNames.first;
      if (audienceNames.length <= 3) return audienceNames.join(', ');
      return '${audienceNames.take(2).join(', ')} +${audienceNames.length - 2} more';
    }
    return 'Selected Departments';
  }

  /// Whether this notice was created after the user's lastSeenAt timestamp.
  bool isNewFor(DateTime? lastSeenAt) {
    if (lastSeenAt == null) return true;
    return createdAt.isAfter(lastSeenAt);
  }

  factory NoticeModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    return NoticeModel.fromMap(doc.id, doc.data() ?? {});
  }

  factory NoticeModel.fromMap(String id, Map<String, dynamic> data) {
    DateTime parseDate(dynamic val, [DateTime? fallback]) {
      if (val is Timestamp) return val.toDate();
      if (val is int) return DateTime.fromMillisecondsSinceEpoch(val);
      if (val is String) return DateTime.tryParse(val) ?? (fallback ?? DateTime.now());
      return fallback ?? DateTime.now();
    }

    final rawMedia = (data['media'] as List<dynamic>? ?? []);
    final mediaList = rawMedia
        .whereType<Map>()
        .map((m) => MediaRef.fromMap(Map<String, dynamic>.from(m)))
        .toList();

    final rawVideoLinks = (data['videoLinks'] as List<dynamic>? ?? [])
        .map((e) => e.toString())
        .toList();

    final rawAudienceKeys = (data['audienceKeys'] as List<dynamic>? ?? [])
        .map((e) => e.toString())
        .toList();

    final rawAudienceNames = (data['audienceNames'] as List<dynamic>? ?? [])
        .map((e) => e.toString())
        .toList();

    return NoticeModel(
      id: id,
      type: NoticeTypeExtension.fromString(data['type'] as String?),
      title: data['title'] as String? ?? '',
      body: data['body'] as String? ?? '',
      media: mediaList,
      videoLinks: rawVideoLinks,
      audienceKeys: rawAudienceKeys,
      audienceNames: rawAudienceNames,
      authorId: data['authorId'] as String? ?? '',
      authorName: data['authorName'] as String? ?? 'Colleague',
      authorLabel: data['authorLabel'] as String? ?? '',
      pinned: data['pinned'] as bool? ?? false,
      expiresAt: data['expiresAt'] != null ? parseDate(data['expiresAt']) : null,
      version: (data['version'] as num?)?.toInt() ?? 1,
      status: data['status'] as String? ?? 'published',
      createdAt: parseDate(data['createdAt']),
      editedAt: data['editedAt'] != null ? parseDate(data['editedAt']) : null,
      retractedAt: data['retractedAt'] != null ? parseDate(data['retractedAt']) : null,
      retractedBy: data['retractedBy'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'type': type.value,
      'title': title,
      'body': body,
      'media': media.map((m) => m.toMap()).toList(),
      'videoLinks': videoLinks,
      'audienceKeys': audienceKeys,
      'audienceNames': audienceNames,
      'authorId': authorId,
      'authorName': authorName,
      'authorLabel': authorLabel,
      'pinned': pinned,
      if (expiresAt != null) 'expiresAt': Timestamp.fromDate(expiresAt!),
      'version': version,
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
      if (editedAt != null) 'editedAt': Timestamp.fromDate(editedAt!),
      if (retractedAt != null) 'retractedAt': Timestamp.fromDate(retractedAt!),
      if (retractedBy != null) 'retractedBy': retractedBy,
    };
  }

  NoticeModel copyWith({
    String? id,
    NoticeType? type,
    String? title,
    String? body,
    List<MediaRef>? media,
    List<String>? videoLinks,
    List<String>? audienceKeys,
    List<String>? audienceNames,
    String? authorId,
    String? authorName,
    String? authorLabel,
    bool? pinned,
    DateTime? expiresAt,
    int? version,
    String? status,
    DateTime? createdAt,
    DateTime? editedAt,
    DateTime? retractedAt,
    String? retractedBy,
  }) {
    return NoticeModel(
      id: id ?? this.id,
      type: type ?? this.type,
      title: title ?? this.title,
      body: body ?? this.body,
      media: media ?? this.media,
      videoLinks: videoLinks ?? this.videoLinks,
      audienceKeys: audienceKeys ?? this.audienceKeys,
      audienceNames: audienceNames ?? this.audienceNames,
      authorId: authorId ?? this.authorId,
      authorName: authorName ?? this.authorName,
      authorLabel: authorLabel ?? this.authorLabel,
      pinned: pinned ?? this.pinned,
      expiresAt: expiresAt ?? this.expiresAt,
      version: version ?? this.version,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      editedAt: editedAt ?? this.editedAt,
      retractedAt: retractedAt ?? this.retractedAt,
      retractedBy: retractedBy ?? this.retractedBy,
    );
  }
}

/// Emoji reaction model for `.../reactions/{uid}`
class NoticeReaction {
  final String uid;
  final String emoji;
  final DateTime at;

  const NoticeReaction({
    required this.uid,
    required this.emoji,
    required this.at,
  });

  factory NoticeReaction.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    DateTime parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is int) return DateTime.fromMillisecondsSinceEpoch(val);
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      return DateTime.now();
    }

    return NoticeReaction(
      uid: doc.id,
      emoji: data['emoji'] as String? ?? '👍',
      at: parseDate(data['at']),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'emoji': emoji,
      'at': Timestamp.fromDate(at),
    };
  }
}

/// Policy acknowledgement model for `.../acks/{uid}`
class NoticeAck {
  final String uid;
  final int version;
  final DateTime at;
  final String? userName;

  const NoticeAck({
    required this.uid,
    required this.version,
    required this.at,
    this.userName,
  });

  factory NoticeAck.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    DateTime parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is int) return DateTime.fromMillisecondsSinceEpoch(val);
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      return DateTime.now();
    }

    return NoticeAck(
      uid: doc.id,
      version: (data['version'] as num?)?.toInt() ?? 1,
      at: parseDate(data['at']),
      userName: data['userName'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'version': version,
      'at': Timestamp.fromDate(at),
      if (userName != null) 'userName': userName,
    };
  }
}

/// Notice view model for `.../views/{uid}`
class NoticeView {
  final String uid;
  final DateTime at;

  const NoticeView({
    required this.uid,
    required this.at,
  });

  factory NoticeView.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    DateTime parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is int) return DateTime.fromMillisecondsSinceEpoch(val);
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      return DateTime.now();
    }

    return NoticeView(
      uid: doc.id,
      at: parseDate(data['at']),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'at': Timestamp.fromDate(at),
    };
  }
}
