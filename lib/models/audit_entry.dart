import 'package:cloud_firestore/cloud_firestore.dart';

/// Minimal append-only audit log entry for admin oversight.
class AuditEntry {
  final String id;
  final String actorId;
  final String actorName;
  final String action;
  final String targetType;
  final String targetId;
  final String targetLabel;
  final DateTime createdAt;

  const AuditEntry({
    required this.id,
    required this.actorId,
    required this.actorName,
    required this.action,
    required this.targetType,
    required this.targetId,
    required this.targetLabel,
    required this.createdAt,
  });

  factory AuditEntry.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    DateTime parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      return DateTime.now();
    }

    return AuditEntry(
      id: doc.id,
      actorId: data['actorId'] as String? ?? '',
      actorName: data['actorName'] as String? ?? 'Admin',
      action: data['action'] as String? ?? '',
      targetType: data['targetType'] as String? ?? '',
      targetId: data['targetId'] as String? ?? '',
      targetLabel: data['targetLabel'] as String? ?? '',
      createdAt: parseDate(data['createdAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'actorId': actorId,
      'actorName': actorName,
      'action': action,
      'targetType': targetType,
      'targetId': targetId,
      'targetLabel': targetLabel,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  /// Readable description for user-facing activity feeds
  String get humanDescription {
    switch (action) {
      case 'staff_added':
        return '$actorName invited $targetLabel';
      case 'csv_imported':
        return '$actorName imported staff via CSV ($targetLabel)';
      case 'member_revoked':
        return '$actorName revoked access for $targetLabel';
      case 'member_restored':
        return '$actorName restored access for $targetLabel';
      case 'role_changed':
        return '$actorName updated role for $targetLabel';
      case 'department_assigned':
        return '$actorName assigned department for $targetLabel';
      case 'department_created':
        return '$actorName created department "$targetLabel"';
      case 'department_archived':
        return '$actorName archived department "$targetLabel"';
      case 'project_archived':
        return '$actorName archived project group "$targetLabel"';
      case 'settings_updated':
        return '$actorName updated $targetLabel';
      default:
        return '$actorName performed $action on $targetLabel';
    }
  }
}
