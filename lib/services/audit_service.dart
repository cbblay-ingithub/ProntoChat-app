import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/audit_entry.dart';
import 'db_service.dart';

/// Service managing the minimal append-only audit log:
/// Firms/{firmId}/auditLog/{auditId}
class AuditService {
  AuditService._internal();
  static final AuditService instance = AuditService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Helper to get current admin actor metadata
  Future<Map<String, String>> _getCurrentActor() async {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? 'unknown';
    String name = 'Admin';
    try {
      final user = await DBService.instance.getUserData(uid);
      if (user != null && (user['name'] as String?)?.isNotEmpty == true) {
        name = user['name'] as String;
      }
    } catch (_) {}
    return {'uid': uid, 'name': name};
  }

  /// Appends an audit entry to an existing Firestore WriteBatch.
  Future<void> appendAuditToBatch(
    WriteBatch batch, {
    required String firmId,
    required String action,
    required String targetType,
    required String targetId,
    required String targetLabel,
    String? actorId,
    String? actorName,
  }) async {
    try {
      final docRef = _db
          .collection('Firms')
          .doc(firmId)
          .collection('auditLog')
          .doc();

      final resolvedActorId = actorId ?? FirebaseAuth.instance.currentUser?.uid ?? 'unknown';
      String resolvedActorName = actorName ?? 'Admin';
      if (actorName == null) {
        final actor = await _getCurrentActor();
        resolvedActorName = actor['name']!;
      }

      batch.set(docRef, {
        'actorId': resolvedActorId,
        'actorName': resolvedActorName,
        'action': action,
        'targetType': targetType,
        'targetId': targetId,
        'targetLabel': targetLabel,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('[AuditService] Error appending to batch: $e');
    }
  }

  /// Write a standalone audit log entry (best effort; never throws so as not to break main action).
  Future<void> logAction({
    required String firmId,
    required String action,
    required String targetType,
    required String targetId,
    required String targetLabel,
  }) async {
    try {
      final actor = await _getCurrentActor();
      await _db
          .collection('Firms')
          .doc(firmId)
          .collection('auditLog')
          .add({
        'actorId': actor['uid'],
        'actorName': actor['name'],
        'action': action,
        'targetType': targetType,
        'targetId': targetId,
        'targetLabel': targetLabel,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('[AuditService] Non-fatal error writing audit log: $e');
    }
  }

  /// Fetch the latest audit log entries for the dashboard activity feed
  Future<List<AuditEntry>> fetchRecentActivity(String firmId, {int limit = 10}) async {
    try {
      final snapshot = await _db
          .collection('Firms')
          .doc(firmId)
          .collection('auditLog')
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs.map((doc) => AuditEntry.fromFirestore(doc)).toList();
    } catch (e) {
      debugPrint('[AuditService] Error fetching audit logs: $e');
      return [];
    }
  }
}
