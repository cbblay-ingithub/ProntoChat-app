import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a Project Group in a firm.
/// Admin can view metadata: name, ownerUid, memberCount, status.
/// Participants can access the underlying conversation.
class ProjectGroup {
  final String projectId;
  final String firmId;
  final String conversationId;
  final String name;
  final String ownerUid;
  final List<String> participantIds;
  final int memberCount;
  final String status; // 'active' | 'archived'
  final DateTime createdAt;

  const ProjectGroup({
    required this.projectId,
    required this.firmId,
    required this.conversationId,
    required this.name,
    required this.ownerUid,
    this.participantIds = const [],
    required this.memberCount,
    this.status = 'active',
    required this.createdAt,
  });

  bool get isActive => status == 'active';
  bool get isArchived => status == 'archived';

  factory ProjectGroup.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc, String firmId) {
    final data = doc.data() ?? {};

    DateTime parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      return DateTime.now();
    }

    final rawParticipants = data['participantIds'] as List<dynamic>?;
    final participantIds = rawParticipants?.map((e) => e.toString()).toList() ?? [];

    return ProjectGroup(
      projectId: doc.id,
      firmId: firmId,
      conversationId: data['conversationId'] as String? ?? doc.id,
      name: data['name'] as String? ?? 'Untitled Project',
      ownerUid: data['ownerUid'] as String? ?? '',
      participantIds: participantIds,
      memberCount: (data['memberCount'] as num?)?.toInt() ?? participantIds.length,
      status: data['status'] as String? ?? 'active',
      createdAt: parseDate(data['createdAt']),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'ownerUid': ownerUid,
      'conversationId': conversationId,
      'participantIds': participantIds,
      'memberCount': memberCount,
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
