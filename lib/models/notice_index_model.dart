import 'package:cloud_firestore/cloud_firestore.dart';
import 'notice_model.dart';

/// Metadata-only notice index model stored in `Firms/{firmId}/noticeIndex/{noticeId}`.
/// Strictly excludes title, body, media, and video links to protect confidential content from
/// unaddressed admins while enabling oversight and retraction.
class NoticeIndexModel {
  final String id;
  final String authorId;
  final String authorName;
  final NoticeType type;
  final List<String> audienceKeys;
  final List<String> audienceNames;
  final DateTime createdAt;
  final DateTime? expiresAt;
  final String status; // 'published' | 'retracted'
  final int version;
  final DateTime? retractedAt;
  final String? retractedBy;
  final String? retractReason;

  const NoticeIndexModel({
    required this.id,
    required this.authorId,
    required this.authorName,
    required this.type,
    required this.audienceKeys,
    required this.audienceNames,
    required this.createdAt,
    this.expiresAt,
    this.status = 'published',
    this.version = 1,
    this.retractedAt,
    this.retractedBy,
    this.retractReason,
  });

  bool get isPublished => status == 'published';
  bool get isRetracted => status == 'retracted';
  bool get isExpired => expiresAt != null && DateTime.now().isAfter(expiresAt!);
  bool get isPolicy => type == NoticeType.policy;
  bool get isUrgent => type == NoticeType.urgent;
  bool get isAnnouncement => type == NoticeType.announcement;

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

  factory NoticeIndexModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    return NoticeIndexModel.fromMap(doc.id, doc.data() ?? {});
  }

  factory NoticeIndexModel.fromMap(String id, Map<String, dynamic> data) {
    DateTime parseDate(dynamic val, [DateTime? fallback]) {
      if (val is Timestamp) return val.toDate();
      if (val is int) return DateTime.fromMillisecondsSinceEpoch(val);
      if (val is String) return DateTime.tryParse(val) ?? (fallback ?? DateTime.now());
      return fallback ?? DateTime.now();
    }

    final rawAudienceKeys = (data['audienceKeys'] as List<dynamic>? ?? [])
        .map((e) => e.toString())
        .toList();

    final rawAudienceNames = (data['audienceNames'] as List<dynamic>? ?? [])
        .map((e) => e.toString())
        .toList();

    return NoticeIndexModel(
      id: id,
      authorId: data['authorId'] as String? ?? '',
      authorName: data['authorName'] as String? ?? 'Colleague',
      type: NoticeTypeExtension.fromString(data['type'] as String?),
      audienceKeys: rawAudienceKeys,
      audienceNames: rawAudienceNames,
      createdAt: parseDate(data['createdAt']),
      expiresAt: data['expiresAt'] != null ? parseDate(data['expiresAt']) : null,
      status: data['status'] as String? ?? 'published',
      version: (data['version'] as num?)?.toInt() ?? 1,
      retractedAt: data['retractedAt'] != null ? parseDate(data['retractedAt']) : null,
      retractedBy: data['retractedBy'] as String?,
      retractReason: data['retractReason'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'authorId': authorId,
      'authorName': authorName,
      'type': type.value,
      'audienceKeys': audienceKeys,
      'audienceNames': audienceNames,
      'createdAt': Timestamp.fromDate(createdAt),
      if (expiresAt != null) 'expiresAt': Timestamp.fromDate(expiresAt!),
      'status': status,
      'version': version,
      if (retractedAt != null) 'retractedAt': Timestamp.fromDate(retractedAt!),
      if (retractedBy != null) 'retractedBy': retractedBy,
      if (retractReason != null) 'retractReason': retractReason,
    };
  }
}
