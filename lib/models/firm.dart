import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'firm.freezed.dart';
part 'firm.g.dart';

/// Represents a firm/organization in the ProntoChat system.
/// Firms are the top-level multi-tenant entity that groups employees and admins.
@freezed
class Firm with _$Firm {
  const factory Firm({
    /// Firestore document ID (UUID or custom ID)
    required String firmId,

    /// Display name of the firm (e.g., "Acme Corporation")
    required String name,

    /// Primary brand color as hex string (e.g., "#295CB4")
    required String primaryColor,

    /// UID of the super_admin who created this firm
    required String adminId,

    /// Timestamp when the firm was created
    required DateTime createdAt,

    /// Optional secondary brand color for UI accents
    String? secondaryColor,

    /// Optional logo URL for brand styling
    String? logoUrl,
  }) = _Firm;

  factory Firm.fromJson(Map<String, dynamic> json) => _$FirmFromJson(json);
}

/// Extension methods for Firestore conversion
extension FirmFirestore on Firm {
  /// Convert Firestore DocumentSnapshot to Firm model
  static Firm fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return Firm(
      firmId: doc.id,
      name: data['name'] ?? '',
      primaryColor: data['primaryColor'] ?? '#295CB4',
      adminId: data['adminId'] ?? '',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      secondaryColor: data['secondaryColor'],
      logoUrl: data['logoUrl'],
    );
  }

  /// Convert Firm to Firestore-compatible Map
  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'primaryColor': primaryColor,
      'adminId': adminId,
      'createdAt': Timestamp.fromDate(createdAt),
      if (secondaryColor != null) 'secondaryColor': secondaryColor,
      if (logoUrl != null) 'logoUrl': logoUrl,
    };
  }
}
