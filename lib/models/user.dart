import 'package:cloud_firestore/cloud_firestore.dart';

/// Enum for user roles in the system
enum UserRole {
  super_admin,
  admin,
  employee,
}

/// Represents a user identity in the ProntoChat system, decoupled from any single firm.
class AppUser {
  final String uid;
  final String name;
  final String email;
  final UserRole role;
  final String? image;
  final DateTime createdAt;
  final DateTime? lastSeen;
  final String? nameLower;
  final List<String> firmIds;
  final String? ownedFirmId;

  const AppUser({
    required this.uid,
    required this.name,
    required this.email,
    this.role = UserRole.employee,
    this.image,
    required this.createdAt,
    this.lastSeen,
    this.nameLower,
    this.firmIds = const [],
    this.ownedFirmId,
  });

  AppUser copyWith({
    String? uid,
    String? name,
    String? email,
    UserRole? role,
    String? image,
    DateTime? createdAt,
    DateTime? lastSeen,
    String? nameLower,
    List<String>? firmIds,
    String? ownedFirmId,
  }) {
    return AppUser(
      uid: uid ?? this.uid,
      name: name ?? this.name,
      email: email ?? this.email,
      role: role ?? this.role,
      image: image ?? this.image,
      createdAt: createdAt ?? this.createdAt,
      lastSeen: lastSeen ?? this.lastSeen,
      nameLower: nameLower ?? this.nameLower,
      firmIds: firmIds ?? this.firmIds,
      ownedFirmId: ownedFirmId ?? this.ownedFirmId,
    );
  }

  factory AppUser.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};

    DateTime parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      return DateTime.now();
    }

    final rawRole = (data['role'] as String?)?.toLowerCase();
    UserRole role = UserRole.employee;
    if (rawRole == 'super_admin') {
      role = UserRole.super_admin;
    } else if (rawRole == 'admin') {
      role = UserRole.admin;
    }

    final List<dynamic>? rawFirmIds = data['firmIds'] as List<dynamic>?;
    final List<String> firmIds = rawFirmIds?.map((e) => e.toString()).toList() ?? [];

    return AppUser(
      uid: doc.id,
      name: data['name'] as String? ?? '',
      email: data['email'] as String? ?? '',
      role: role,
      image: data['image'] as String?,
      createdAt: parseDate(data['createdAt']),
      lastSeen: data['lastSeen'] != null ? parseDate(data['lastSeen']) : null,
      nameLower: data['nameLower'] as String?,
      firmIds: firmIds,
      ownedFirmId: data['ownedFirmId'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'email': email,
      'role': role.name,
      'createdAt': Timestamp.fromDate(createdAt),
      if (image != null) 'image': image,
      if (lastSeen != null) 'lastSeen': Timestamp.fromDate(lastSeen!),
      'nameLower': nameLower ?? name.toLowerCase(),
      'firmIds': firmIds,
      if (ownedFirmId != null) 'ownedFirmId': ownedFirmId,
    };
  }
}

/// Extension methods for backward compatibility
extension AppUserFirestore on AppUser {
  static AppUser fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    return AppUser.fromFirestore(doc);
  }
}
