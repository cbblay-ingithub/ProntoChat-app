import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'membership.freezed.dart';
part 'membership.g.dart';

/// Enum for membership status (approval workflow)
enum MembershipStatus {
  pending, // Waiting for admin approval (employee onboarding)
  approved, // Approved and active
  revoked, // Access removed by admin
}

/// Enum for membership role within a firm context
enum MembershipRole {
  admin, // Can manage staff, approve employees, view dashboard
  employee, // Can chat, view directory, limited access
}

/// Represents a user's membership in a specific firm.
/// Links User → Firm with status and role context.
@freezed
class Membership with _$Membership {
  const factory Membership({
    /// Firestore document ID (UUID)
    required String membershipId,

    /// Firebase Auth UID of the user
    required String uid,

    /// Firestore firm ID that this user belongs to
    required String firmId,

    /// Membership status (pending, approved, revoked)
    @Default(MembershipStatus.approved) MembershipStatus status,

    /// User's role within this firm (admin, employee)
    @Default(MembershipRole.employee) MembershipRole role,

    /// Timestamp when the membership was created
    required DateTime createdAt,

    /// Optional: when the membership was approved (for tracking approval time)
    DateTime? approvedAt,

    /// Optional: when the membership was revoked
    DateTime? revokedAt,
  }) = _Membership;

  factory Membership.fromJson(Map<String, dynamic> json) =>
      _$MembershipFromJson(json);
}

/// Extension methods for Firestore conversion
extension MembershipFirestore on Membership {
  /// Convert Firestore DocumentSnapshot to Membership model
  static Membership fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return Membership(
      membershipId: doc.id,
      uid: data['uid'] ?? '',
      firmId: data['firmId'] ?? '',
      status: _parseMembershipStatus(data['status'] as String?),
      role: _parseMembershipRole(data['role'] as String?),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      approvedAt: data['approvedAt'] != null
          ? (data['approvedAt'] as Timestamp).toDate()
          : null,
      revokedAt: data['revokedAt'] != null
          ? (data['revokedAt'] as Timestamp).toDate()
          : null,
    );
  }

  /// Convert Membership to Firestore-compatible Map
  Map<String, dynamic> toFirestore() {
    return {
      'uid': uid,
      'firmId': firmId,
      'status': status.name,
      'role': role.name,
      'createdAt': Timestamp.fromDate(createdAt),
      if (approvedAt != null) 'approvedAt': Timestamp.fromDate(approvedAt!),
      if (revokedAt != null) 'revokedAt': Timestamp.fromDate(revokedAt!),
    };
  }
}

/// Helper to parse status string to enum
MembershipStatus _parseMembershipStatus(String? statusStr) {
  return MembershipStatus.values.firstWhere(
    (status) => status.name == statusStr,
    orElse: () => MembershipStatus.approved,
  );
}

/// Helper to parse role string to enum
MembershipRole _parseMembershipRole(String? roleStr) {
  return MembershipRole.values.firstWhere(
    (role) => role.name == roleStr,
    orElse: () => MembershipRole.employee,
  );
}
