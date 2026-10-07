import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a department within a firm.
class Department {
  final String deptId;
  final String firmId;
  final String name;
  final String? headUid;
  final String conversationId;
  final String status; // 'active' | 'archived'
  final DateTime createdAt;
  final String createdBy;
  final int headcount;

  const Department({
    required this.deptId,
    required this.firmId,
    required this.name,
    this.headUid,
    required this.conversationId,
    this.status = 'active',
    required this.createdAt,
    required this.createdBy,
    this.headcount = 0,
  });

  bool get isActive => status == 'active';
  bool get isArchived => status == 'archived';

  Department copyWith({
    String? deptId,
    String? firmId,
    String? name,
    String? headUid,
    String? conversationId,
    String? status,
    DateTime? createdAt,
    String? createdBy,
    int? headcount,
  }) {
    return Department(
      deptId: deptId ?? this.deptId,
      firmId: firmId ?? this.firmId,
      name: name ?? this.name,
      headUid: headUid ?? this.headUid,
      conversationId: conversationId ?? this.conversationId,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      createdBy: createdBy ?? this.createdBy,
      headcount: headcount ?? this.headcount,
    );
  }

  factory Department.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc, String firmId, {int headcount = 0}) {
    final data = doc.data() ?? {};

    DateTime parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      return DateTime.now();
    }

    return Department(
      deptId: doc.id,
      firmId: firmId,
      name: data['name'] as String? ?? '',
      headUid: data['headUid'] as String?,
      conversationId: data['conversationId'] as String? ?? '',
      status: data['status'] as String? ?? 'active',
      createdAt: parseDate(data['createdAt']),
      createdBy: data['createdBy'] as String? ?? '',
      headcount: headcount,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      if (headUid != null) 'headUid': headUid,
      'conversationId': conversationId,
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
      'createdBy': createdBy,
    };
  }
}
