import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a firm/organization in the ProntoChat system.
/// Firms are the top-level multi-tenant entity that groups employees and admins.
class Firm {
  /// Firestore document ID
  final String firmId;

  /// Display name of the firm (e.g., "Acme Corporation")
  final String name;

  /// Primary brand color as hex string (e.g., "#295CB4")
  final String primaryColor;

  /// UID of the admin/owner who created this firm
  final String ownerUid;

  /// Backward-compatible alias for ownerUid
  String get adminId => ownerUid;

  /// Plan name (fixed "trial" default)
  final String plan;

  /// Status of the firm ("active" | "suspended")
  final String status;

  /// Seat limit for the firm (fixed 5 for trial)
  final int seatLimit;

  /// Current seat usage counter (includes admin + staff)
  final int seatCount;

  /// Timestamp when terms of service were accepted
  final DateTime termsAcceptedAt;

  /// Timestamp when the firm was created
  final DateTime createdAt;

  /// Optional secondary brand color for UI accents
  final String? secondaryColor;

  /// Optional logo URL for brand styling
  final String? logoUrl;

  /// Optional invite token
  final String? inviteToken;

  Firm({
    required this.firmId,
    required this.name,
    required this.primaryColor,
    String? ownerUid,
    String? adminId,
    this.plan = 'trial',
    this.status = 'active',
    this.seatLimit = 5,
    this.seatCount = 1,
    DateTime? termsAcceptedAt,
    DateTime? createdAt,
    this.secondaryColor,
    this.logoUrl,
    this.inviteToken,
  })  : ownerUid = ownerUid ?? adminId ?? '',
        createdAt = createdAt ?? DateTime.now(),
        termsAcceptedAt = termsAcceptedAt ?? createdAt ?? DateTime.now();

  bool get isSuspended => status == 'suspended';
  bool get isActive => status == 'active';

  Firm copyWith({
    String? firmId,
    String? name,
    String? primaryColor,
    String? ownerUid,
    String? plan,
    String? status,
    int? seatLimit,
    int? seatCount,
    DateTime? termsAcceptedAt,
    DateTime? createdAt,
    String? secondaryColor,
    String? logoUrl,
    String? inviteToken,
  }) {
    return Firm(
      firmId: firmId ?? this.firmId,
      name: name ?? this.name,
      primaryColor: primaryColor ?? this.primaryColor,
      ownerUid: ownerUid ?? this.ownerUid,
      plan: plan ?? this.plan,
      status: status ?? this.status,
      seatLimit: seatLimit ?? this.seatLimit,
      seatCount: seatCount ?? this.seatCount,
      termsAcceptedAt: termsAcceptedAt ?? this.termsAcceptedAt,
      createdAt: createdAt ?? this.createdAt,
      secondaryColor: secondaryColor ?? this.secondaryColor,
      logoUrl: logoUrl ?? this.logoUrl,
      inviteToken: inviteToken ?? this.inviteToken,
    );
  }

  factory Firm.fromJson(Map<String, dynamic> json) {
    return Firm(
      firmId: json['firmId'] as String? ?? '',
      name: json['name'] as String? ?? '',
      primaryColor: json['primaryColor'] as String? ?? '#295CB4',
      ownerUid: (json['ownerUid'] ?? json['adminId']) as String? ?? '',
      plan: json['plan'] as String? ?? 'trial',
      status: json['status'] as String? ?? 'active',
      seatLimit: (json['seatLimit'] as num?)?.toInt() ?? 5,
      seatCount: (json['seatCount'] as num?)?.toInt() ?? 1,
      termsAcceptedAt: json['termsAcceptedAt'] != null
          ? DateTime.tryParse(json['termsAcceptedAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      secondaryColor: json['secondaryColor'] as String?,
      logoUrl: json['logoUrl'] as String?,
      inviteToken: json['inviteToken'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'firmId': firmId,
      'name': name,
      'primaryColor': primaryColor,
      'ownerUid': ownerUid,
      'adminId': ownerUid,
      'plan': plan,
      'status': status,
      'seatLimit': seatLimit,
      'seatCount': seatCount,
      'termsAcceptedAt': termsAcceptedAt.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      if (secondaryColor != null) 'secondaryColor': secondaryColor,
      if (logoUrl != null) 'logoUrl': logoUrl,
      if (inviteToken != null) 'inviteToken': inviteToken,
    };
  }

  factory Firm.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    
    DateTime parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      return DateTime.now();
    }

    final createdAt = parseDate(data['createdAt']);
    final termsAcceptedAt = data['termsAcceptedAt'] != null
        ? parseDate(data['termsAcceptedAt'])
        : createdAt;

    return Firm(
      firmId: doc.id,
      name: data['name'] as String? ?? '',
      primaryColor: data['primaryColor'] as String? ?? '#295CB4',
      ownerUid: (data['ownerUid'] ?? data['adminId']) as String? ?? '',
      plan: data['plan'] as String? ?? 'trial',
      status: data['status'] as String? ?? 'active',
      seatLimit: (data['seatLimit'] as num?)?.toInt() ?? 5,
      seatCount: (data['seatCount'] as num?)?.toInt() ?? 1,
      termsAcceptedAt: termsAcceptedAt,
      createdAt: createdAt,
      secondaryColor: data['secondaryColor'] as String?,
      logoUrl: data['logoUrl'] as String?,
      inviteToken: data['inviteToken'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'primaryColor': primaryColor,
      'ownerUid': ownerUid,
      'adminId': ownerUid, // for backward compatibility with existing rules/code
      'plan': plan,
      'status': status,
      'seatLimit': seatLimit,
      'seatCount': seatCount,
      'termsAcceptedAt': Timestamp.fromDate(termsAcceptedAt),
      'createdAt': Timestamp.fromDate(createdAt),
      if (secondaryColor != null) 'secondaryColor': secondaryColor,
      if (logoUrl != null) 'logoUrl': logoUrl,
      if (inviteToken != null) 'inviteToken': inviteToken,
    };
  }
}

/// Extension methods for Firestore conversion compatibility
extension FirmFirestore on Firm {
  static Firm fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    return Firm.fromFirestore(doc);
  }
}
