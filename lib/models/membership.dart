import 'package:cloud_firestore/cloud_firestore.dart';

/// Enum for membership status
enum MembershipStatus {
  active,   // Active member with full access
  revoked,  // Access removed by admin
  pending,  // Legacy pending state
  rejected, // Legacy rejected state
}

/// Enum for membership role within a firm context
enum MembershipRole {
  admin,    // Can manage staff, invite codes, view console
  employee, // Regular team member
}

/// Represents a user's membership in a specific firm.
class Membership {
  final String membershipId;
  final String uid;
  final String firmId;
  final MembershipStatus status;
  final MembershipRole role;
  final DateTime joinedAt;
  final DateTime createdAt;
  final DateTime? revokedAt;

  Membership({
    required this.membershipId,
    required this.uid,
    required this.firmId,
    this.status = MembershipStatus.active,
    this.role = MembershipRole.employee,
    DateTime? joinedAt,
    DateTime? createdAt,
    this.revokedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        joinedAt = joinedAt ?? createdAt ?? DateTime.now();

  bool get isActive => status == MembershipStatus.active;
  bool get isRevoked => status == MembershipStatus.revoked;
  bool get isAdmin => role == MembershipRole.admin;
  bool get isEmployee => role == MembershipRole.employee;

  Membership copyWith({
    String? membershipId,
    String? uid,
    String? firmId,
    MembershipStatus? status,
    MembershipRole? role,
    DateTime? joinedAt,
    DateTime? createdAt,
    DateTime? revokedAt,
  }) {
    return Membership(
      membershipId: membershipId ?? this.membershipId,
      uid: uid ?? this.uid,
      firmId: firmId ?? this.firmId,
      status: status ?? this.status,
      role: role ?? this.role,
      joinedAt: joinedAt ?? this.joinedAt,
      createdAt: createdAt ?? this.createdAt,
      revokedAt: revokedAt ?? this.revokedAt,
    );
  }

  factory Membership.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};

    DateTime parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      return DateTime.now();
    }

    final createdAt = parseDate(data['createdAt']);
    final joinedAt = data['joinedAt'] != null
        ? parseDate(data['joinedAt'])
        : (data['approvedAt'] != null ? parseDate(data['approvedAt']) : createdAt);
    final revokedAt = data['revokedAt'] != null ? parseDate(data['revokedAt']) : null;

    final rawStatus = (data['status'] as String?)?.toLowerCase();
    MembershipStatus status = MembershipStatus.active;
    if (rawStatus == 'revoked') {
      status = MembershipStatus.revoked;
    } else if (rawStatus == 'pending') {
      status = MembershipStatus.pending;
    } else if (rawStatus == 'rejected') {
      status = MembershipStatus.rejected;
    } else {
      status = MembershipStatus.active;
    }

    final rawRole = (data['role'] as String?)?.toLowerCase();
    final role = (rawRole == 'admin' || rawRole == 'super_admin')
        ? MembershipRole.admin
        : MembershipRole.employee;

    return Membership(
      membershipId: doc.id,
      uid: data['uid'] as String? ?? doc.id,
      firmId: data['firmId'] as String? ?? '',
      status: status,
      role: role,
      joinedAt: joinedAt,
      createdAt: createdAt,
      revokedAt: revokedAt,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'uid': uid,
      'firmId': firmId,
      'status': status == MembershipStatus.active ? 'active' : status.name,
      'role': role.name,
      'joinedAt': Timestamp.fromDate(joinedAt),
      'createdAt': Timestamp.fromDate(createdAt),
      if (revokedAt != null) 'revokedAt': Timestamp.fromDate(revokedAt!),
    };
  }

  factory Membership.fromJson(Map<String, dynamic> json) {
    return Membership(
      membershipId: json['membershipId'] as String? ?? '',
      uid: json['uid'] as String? ?? '',
      firmId: json['firmId'] as String? ?? '',
      status: json['status'] == 'revoked' ? MembershipStatus.revoked : MembershipStatus.active,
      role: json['role'] == 'admin' ? MembershipRole.admin : MembershipRole.employee,
      joinedAt: json['joinedAt'] != null
          ? DateTime.tryParse(json['joinedAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'membershipId': membershipId,
      'uid': uid,
      'firmId': firmId,
      'status': status.name,
      'role': role.name,
      'joinedAt': joinedAt.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
    };
  }
}

/// Extension methods for Firestore conversion backward compatibility
extension MembershipFirestore on Membership {
  static Membership fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    return Membership.fromFirestore(doc);
  }
}
