import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/notice_model.dart';
import '../models/notice_index_model.dart';
import '../models/media_ref.dart';

/// Centralized service handling all data operations for the Notices feature.
/// Strictly conforms to Free (Spark) Tier requirements, cache-first patterns,
/// and metadata-only admin oversight.
class NoticesService {
  NoticesService._internal();
  static final NoticesService instance = NoticesService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _noticesCol(String firmId) =>
      _db.collection('Firms').doc(firmId).collection('notices');

  CollectionReference<Map<String, dynamic>> _noticeIndexCol(String firmId) =>
      _db.collection('Firms').doc(firmId).collection('noticeIndex');

  CollectionReference<Map<String, dynamic>> _noticeStateCol(String firmId) =>
      _db.collection('Firms').doc(firmId).collection('noticeState');

  // Throttling timer for noticeState.lastSeenAt updates (at most once every 60s per user)
  DateTime? _lastSeenUpdatedTime;

  // Local cache for notice feed
  List<NoticeModel> _cachedFeed = [];
  DateTime? _lastFeedFetchTime;
  List<NoticeModel> get cachedFeed => List.unmodifiable(_cachedFeed);

  // ── 1. Create Notice (Atomic Batch with NoticeIndex) ────────────────────────
  Future<String> createNotice({
    required String firmId,
    required NoticeType type,
    required String title,
    required String body,
    List<MediaRef> media = const [],
    List<String> videoLinks = const [],
    required List<String> audienceKeys,
    required List<String> audienceNames,
    required String authorId,
    required String authorName,
    required String authorLabel,
    bool pinned = false,
    DateTime? expiresAt,
  }) async {
    final noticeRef = _noticesCol(firmId).doc();
    final indexRef = _noticeIndexCol(firmId).doc(noticeRef.id);
    final now = FieldValue.serverTimestamp();

    final batch = _db.batch();

    // 1. Notice Document (full content)
    final noticeData = <String, dynamic>{
      'type': type.value,
      'title': title.trim(),
      'body': body.trim(),
      'media': media.take(4).map((m) => m.toMap()).toList(),
      'videoLinks': videoLinks.take(3).toList(),
      'audienceKeys': audienceKeys.take(50).toList(),
      'audienceNames': audienceNames.take(50).toList(),
      'authorId': authorId,
      'authorName': authorName,
      'authorLabel': authorLabel,
      'pinned': pinned,
      if (expiresAt != null) 'expiresAt': Timestamp.fromDate(expiresAt),
      'version': 1,
      'status': 'published',
      'createdAt': now,
    };
    batch.set(noticeRef, noticeData);

    // 2. NoticeIndex Document (metadata-only: NO title, body, media or videoLinks)
    final indexData = <String, dynamic>{
      'authorId': authorId,
      'authorName': authorName,
      'type': type.value,
      'audienceKeys': audienceKeys.take(50).toList(),
      'audienceNames': audienceNames.take(50).toList(),
      'createdAt': now,
      if (expiresAt != null) 'expiresAt': Timestamp.fromDate(expiresAt),
      'status': 'published',
      'version': 1,
    };
    batch.set(indexRef, indexData);

    await batch.commit();

    // Invalidate local cache so next refresh gets newest notice
    _lastFeedFetchTime = null;
    _cachedFeed = [];

    return noticeRef.id;
  }

  // ── 2. Edit Notice Content (Author only) ────────────────────────────────────
  Future<void> editNotice({
    required String firmId,
    required NoticeModel existingNotice,
    required String title,
    required String body,
    List<MediaRef> media = const [],
    List<String> videoLinks = const [],
    bool? pinned,
    DateTime? expiresAt,
  }) async {
    final noticeRef = _noticesCol(firmId).doc(existingNotice.id);
    final indexRef = _noticeIndexCol(firmId).doc(existingNotice.id);
    final now = FieldValue.serverTimestamp();

    final newVersion = existingNotice.isPolicy
        ? existingNotice.version + 1
        : existingNotice.version;

    final batch = _db.batch();

    batch.update(noticeRef, {
      'title': title.trim(),
      'body': body.trim(),
      'media': media.take(4).map((m) => m.toMap()).toList(),
      'videoLinks': videoLinks.take(3).toList(),
      if (pinned != null) 'pinned': pinned,
      if (expiresAt != null) 'expiresAt': Timestamp.fromDate(expiresAt),
      'version': newVersion,
      'editedAt': now,
    });

    batch.update(indexRef, {
      'version': newVersion,
      if (expiresAt != null) 'expiresAt': Timestamp.fromDate(expiresAt),
    });

    await batch.commit();
    _lastFeedFetchTime = null;
  }

  // ── 3. Retract Notice (Author or Admin) ──────────────────────────────────────
  Future<void> retractNotice({
    required String firmId,
    required String noticeId,
    required String retractedByUid,
    String? reason,
  }) async {
    final noticeRef = _noticesCol(firmId).doc(noticeId);
    final indexRef = _noticeIndexCol(firmId).doc(noticeId);
    final now = FieldValue.serverTimestamp();

    final batch = _db.batch();

    batch.update(noticeRef, {
      'status': 'retracted',
      'retractedAt': now,
      'retractedBy': retractedByUid,
    });

    batch.update(indexRef, {
      'status': 'retracted',
      'retractedAt': now,
      'retractedBy': retractedByUid,
      if (reason != null && reason.trim().isNotEmpty)
        'retractReason': reason.trim(),
    });

    await batch.commit();
    _lastFeedFetchTime = null;
  }

  // ── 4. Feed Queries (Cache-first with pull-to-refresh & pagination) ──────────
  Future<List<NoticeModel>> fetchFeedNotices({
    required String firmId,
    String? userDepartmentId,
    int limit = 10,
    DocumentSnapshot? startAfterDoc,
    bool forceRefresh = false,
  }) async {
    // Return cached in-memory feed if fresh (< 5 minutes) and not force refreshing or paginating
    if (!forceRefresh && startAfterDoc == null && _cachedFeed.isNotEmpty && _lastFeedFetchTime != null) {
      final elapsed = DateTime.now().difference(_lastFeedFetchTime!);
      if (elapsed < const Duration(minutes: 5)) {
        return _cachedFeed;
      }
    }

    final audienceFilter = <String>['firm'];
    if (userDepartmentId != null && userDepartmentId.isNotEmpty) {
      audienceFilter.add('dept:$userDepartmentId');
    }

    Query<Map<String, dynamic>> query = _noticesCol(firmId)
        .where('status', isEqualTo: 'published')
        .where('audienceKeys', arrayContainsAny: audienceFilter)
        .orderBy('createdAt', descending: true)
        .limit(limit);

    if (startAfterDoc != null) {
      query = query.startAfterDocument(startAfterDoc);
    }

    QuerySnapshot<Map<String, dynamic>> snapshot;
    try {
      snapshot = await query.get(const GetOptions(source: Source.serverAndCache));
    } catch (e) {
      debugPrint('[NoticesService] Primary query with orderBy failed ($e). Falling back to non-indexed query with client-side sort.');
      try {
        final fallbackQuery = _noticesCol(firmId)
            .where('status', isEqualTo: 'published')
            .where('audienceKeys', arrayContainsAny: audienceFilter)
            .limit(limit * 3);
        snapshot = await fallbackQuery.get();
      } catch (e2) {
        debugPrint('[NoticesService] Fallback query failed: $e2');
        rethrow;
      }
    }

    final notices = snapshot.docs
        .map((d) => NoticeModel.fromFirestore(d))
        .where((n) => !n.isExpired)
        .toList();

    // Ensure strictly sorted newest-first
    notices.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final result = notices.take(limit).toList();

    if (startAfterDoc == null) {
      _cachedFeed = result;
      _lastFeedFetchTime = DateTime.now();
    }

    return result;
  }

  /// Get up to 3 pinned unexpired notices addressed to the user
  Future<List<NoticeModel>> fetchPinnedNotices({
    required String firmId,
    String? userDepartmentId,
  }) async {
    final audienceFilter = <String>['firm'];
    if (userDepartmentId != null && userDepartmentId.isNotEmpty) {
      audienceFilter.add('dept:$userDepartmentId');
    }

    try {
      QuerySnapshot<Map<String, dynamic>> snapshot;
      try {
        snapshot = await _noticesCol(firmId)
            .where('status', isEqualTo: 'published')
            .where('pinned', isEqualTo: true)
            .where('audienceKeys', arrayContainsAny: audienceFilter)
            .orderBy('createdAt', descending: true)
            .limit(3)
            .get(const GetOptions(source: Source.serverAndCache));
      } catch (e) {
        debugPrint('[NoticesService] fetchPinnedNotices primary failed ($e), falling back to client sort');
        snapshot = await _noticesCol(firmId)
            .where('status', isEqualTo: 'published')
            .where('pinned', isEqualTo: true)
            .where('audienceKeys', arrayContainsAny: audienceFilter)
            .limit(10)
            .get();
      }

      final notices = snapshot.docs
          .map((d) => NoticeModel.fromFirestore(d))
          .where((n) => !n.isExpired)
          .toList();
      notices.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return notices.take(3).toList();
    } catch (e) {
      debugPrint('[NoticesService] Error fetching pinned notices: $e');
      return [];
    }
  }

  // ── 5. Urgent Foreground Notifier Stream (Limit 1) ──────────────────────────
  Stream<NoticeModel?> streamLatestUrgentNotice({
    required String firmId,
    String? userDepartmentId,
  }) {
    final audienceFilter = <String>['firm'];
    if (userDepartmentId != null && userDepartmentId.isNotEmpty) {
      audienceFilter.add('dept:$userDepartmentId');
    }

    return _noticesCol(firmId)
        .where('status', isEqualTo: 'published')
        .where('type', isEqualTo: 'urgent')
        .where('audienceKeys', arrayContainsAny: audienceFilter)
        .orderBy('createdAt', descending: true)
        .limit(1)
        .snapshots()
        .map((snapshot) {
      if (snapshot.docs.isEmpty) return null;
      final notice = NoticeModel.fromFirestore(snapshot.docs.first);
      return notice.isExpired ? null : notice;
    });
  }

  // ── 6. Reach Preview (Debounced count() aggregate query) ─────────────────────
  Future<int> computeReach({
    required String firmId,
    required List<String> audienceKeys,
  }) async {
    try {
      if (audienceKeys.contains('firm')) {
        final agg = await _db
            .collection('Firms')
            .doc(firmId)
            .collection('members')
            .where('status', isEqualTo: 'active')
            .count()
            .get();
        return agg.count ?? 0;
      }

      int total = 0;
      for (final key in audienceKeys) {
        if (key.startsWith('dept:')) {
          final deptId = key.substring(5);
          final agg = await _db
              .collection('Firms')
              .doc(firmId)
              .collection('members')
              .where('departmentId', isEqualTo: deptId)
              .where('status', isEqualTo: 'active')
              .count()
              .get();
          total += agg.count ?? 0;
        }
      }
      return total;
    } catch (e) {
      debugPrint('[NoticesService] Error computing reach: $e');
      return 0;
    }
  }

  // ── 7. Reactions Subcollection & Aggregates ─────────────────────────────────
  static const List<String> allowedEmojis = ['👍', '✅', '❤️', '🎉', '👀'];

  Future<Map<String, int>> getReactionCounts(String firmId, String noticeId) async {
    final reactionsCol = _noticesCol(firmId).doc(noticeId).collection('reactions');
    final Map<String, int> counts = {};

    for (final emoji in allowedEmojis) {
      try {
        final agg = await reactionsCol.where('emoji', isEqualTo: emoji).count().get();
        counts[emoji] = agg.count ?? 0;
      } catch (e) {
        counts[emoji] = 0;
      }
    }
    return counts;
  }

  Stream<NoticeReaction?> streamUserReaction(String firmId, String noticeId, String uid) {
    return _noticesCol(firmId)
        .doc(noticeId)
        .collection('reactions')
        .doc(uid)
        .snapshots()
        .map((doc) => doc.exists ? NoticeReaction.fromFirestore(doc) : null);
  }

  Future<void> toggleReaction({
    required String firmId,
    required String noticeId,
    required String uid,
    required String emoji,
    String? currentEmoji,
  }) async {
    final docRef = _noticesCol(firmId).doc(noticeId).collection('reactions').doc(uid);

    if (currentEmoji == emoji) {
      // Tapping same emoji removes it
      await docRef.delete();
    } else {
      // Set or switch emoji
      await docRef.set({
        'emoji': emoji,
        'at': FieldValue.serverTimestamp(),
      });
    }
  }

  // ── 8. Policy Acknowledgements Subcollection ────────────────────────────────
  Future<int> getAckCount(String firmId, String noticeId, int version) async {
    try {
      final agg = await _noticesCol(firmId)
          .doc(noticeId)
          .collection('acks')
          .where('version', isEqualTo: version)
          .count()
          .get();
      return agg.count ?? 0;
    } catch (e) {
      return 0;
    }
  }

  Stream<NoticeAck?> streamUserAck(String firmId, String noticeId, String uid) {
    return _noticesCol(firmId)
        .doc(noticeId)
        .collection('acks')
        .doc(uid)
        .snapshots()
        .map((doc) => doc.exists ? NoticeAck.fromFirestore(doc) : null);
  }

  Future<void> acknowledgePolicy({
    required String firmId,
    required String noticeId,
    required String uid,
    required int version,
    required String userName,
  }) async {
    await _noticesCol(firmId).doc(noticeId).collection('acks').doc(uid).set({
      'version': version,
      'userName': userName,
      'at': FieldValue.serverTimestamp(),
    });
  }

  Future<List<NoticeAck>> getAcknowledgedUsers({
    required String firmId,
    required String noticeId,
    required int version,
    int limit = 50,
  }) async {
    try {
      final snapshot = await _noticesCol(firmId)
          .doc(noticeId)
          .collection('acks')
          .where('version', isEqualTo: version)
          .orderBy('at', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs.map((d) => NoticeAck.fromFirestore(d)).toList();
    } catch (e) {
      debugPrint('[NoticesService] Error fetching acknowledgements: $e');
      return [];
    }
  }

  // ── 9. Views Tracking (First open only) ──────────────────────────────────────
  Future<void> recordView({
    required String firmId,
    required String noticeId,
    required String uid,
  }) async {
    final viewRef = _noticesCol(firmId).doc(noticeId).collection('views').doc(uid);
    try {
      // Write view document once on first detail open
      await viewRef.set({
        'at': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      // Ignored if already recorded or permission check fails
    }
  }

  Future<int> getViewCount(String firmId, String noticeId) async {
    try {
      final agg = await _noticesCol(firmId).doc(noticeId).collection('views').count().get();
      return agg.count ?? 0;
    } catch (e) {
      return 0;
    }
  }

  // ── 10. NoticeState & Unread Dot ───────────────────────────────────────────
  Stream<DateTime?> streamLastSeenAt(String firmId, String uid) {
    return _noticeStateCol(firmId).doc(uid).snapshots().map((doc) {
      if (!doc.exists) return null;
      final data = doc.data() ?? {};
      final val = data['lastSeenAt'];
      if (val is Timestamp) return val.toDate();
      if (val is int) return DateTime.fromMillisecondsSinceEpoch(val);
      if (val is String) return DateTime.tryParse(val);
      return null;
    });
  }

  Future<void> updateLastSeenAt(String firmId, String uid) async {
    final now = DateTime.now();
    if (_lastSeenUpdatedTime != null && now.difference(_lastSeenUpdatedTime!).inSeconds < 60) {
      return; // Throttled to at most once per 60s
    }
    _lastSeenUpdatedTime = now;

    try {
      await _noticeStateCol(firmId).doc(uid).set({
        'lastSeenAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('[NoticesService] Error updating noticeState: $e');
    }
  }

  // ── 11. Admin NoticeIndex Oversight ─────────────────────────────────────────
  Future<List<NoticeIndexModel>> fetchNoticeIndexList({
    required String firmId,
    String? statusFilter,
    NoticeType? typeFilter,
    String? authorIdFilter,
    DocumentSnapshot? startAfterDoc,
    int limit = 20,
  }) async {
    Query<Map<String, dynamic>> query = _noticeIndexCol(firmId)
        .orderBy('createdAt', descending: true);

    if (statusFilter != null && statusFilter != 'all') {
      query = query.where('status', isEqualTo: statusFilter);
    }
    if (typeFilter != null) {
      query = query.where('type', isEqualTo: typeFilter.value);
    }
    if (authorIdFilter != null && authorIdFilter.isNotEmpty) {
      query = query.where('authorId', isEqualTo: authorIdFilter);
    }

    if (startAfterDoc != null) {
      query = query.startAfterDocument(startAfterDoc);
    }

    final snapshot = await query.limit(limit).get();
    return snapshot.docs.map((d) => NoticeIndexModel.fromFirestore(d)).toList();
  }

  // ── 12. Publisher Management (Admin toggle) ─────────────────────────────────
  Future<void> setNoticePublisher({
    required String firmId,
    required String memberUid,
    required bool isPublisher,
  }) async {
    await _db
        .collection('Firms')
        .doc(firmId)
        .collection('members')
        .doc(memberUid)
        .update({
      'noticePublisher': isPublisher,
    });
  }

  // ── 13. Notice Settings (leadsMayTargetBeyondOwnDepartment) ───────────────────
  Future<void> updateLeadsMayTargetSetting({
    required String firmId,
    required bool allowed,
  }) async {
    await _db.collection('Firms').doc(firmId).update({
      'notices.leadsMayTargetBeyondOwnDepartment': allowed,
    });
  }
}
