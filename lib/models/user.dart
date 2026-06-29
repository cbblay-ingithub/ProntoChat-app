import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'user.freezed.dart';
part 'user.g.dart';

/// Enum for user roles in the system
enum UserRole {
  super_admin, // Created the firm, can manage everything
  admin, // Can manage staff and approve employees
  employee, // Regular employee with limited access
}

/// Represents a user in the ProntoChat system.
/// Users can have different roles depending on the firm context.
@freezed
class AppUser with _$AppUser {
  const factory AppUser({
    /// Firebase Auth UID
    required String uid,

    /// User's full name
    required String name,

    /// User's email address
    required String email,

    /// User's role (affects permissions and dashboard access)
    @Default(UserRole.employee) UserRole role,

    /// URL to user's profile image in Firebase Storage
    String? image,

    /// Timestamp when the user account was created
    required DateTime createdAt,

    /// Last time the user was active
    DateTime? lastSeen,

    /// Lowercase version of name for search/filtering
    String? nameLower,
  }) = _AppUser;

  factory AppUser.fromJson(Map<String, dynamic> json) =>
      _$AppUserFromJson(json);
}

/// Extension methods for Firestore conversion
extension AppUserFirestore on AppUser {
  /// Convert Firestore DocumentSnapshot to AppUser model
  static AppUser fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return AppUser(
      uid: doc.id,
      name: data['name'] ?? '',
      email: data['email'] ?? '',
      role: _parseRole(data['role'] as String?),
      image: data['image'],
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      lastSeen: data['lastSeen'] != null
          ? (data['lastSeen'] as Timestamp).toDate()
          : null,
      nameLower: data['nameLower'],
    );
  }

  /// Convert AppUser to Firestore-compatible Map
  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'email': email,
      'role': role.name,
      'createdAt': Timestamp.fromDate(createdAt),
      if (image != null) 'image': image,
      if (lastSeen != null) 'lastSeen': Timestamp.fromDate(lastSeen!),
      'nameLower': name.toLowerCase(),
    };
  }

  /// Helper to parse role string to enum
  static UserRole _parseRole(String? roleStr) {
    return UserRole.values.firstWhere(
      (role) => role.name == roleStr,
      orElse: () => UserRole.employee,
    );
  }
}
