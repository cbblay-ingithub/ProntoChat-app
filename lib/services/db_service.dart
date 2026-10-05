import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pronto_chat/models/firm.dart';
import 'package:pronto_chat/models/membership.dart';
import 'package:pronto_chat/models/user.dart';

class DBService {
  // ══════════════════════════════════════════════════════════════════════════
  // SINGLETON
  // ══════════════════════════════════════════════════════════════════════════

  static final DBService instance = DBService._internal();
  late final FirebaseFirestore _db;

  DBService._internal() {
    _db = FirebaseFirestore.instance;
  }

  // ── Collection / subcollection name constants ─────────────────────────────
  final String _userCollection = 'Users';
  final String _conversationCollection = 'Conversations';
  final String _messagesSubcollection = 'Messages';
  final String _userConvSubcollection =
      'conversations'; // lives under Users/{uid}
  final String _firmsCollection = 'Firms';
  final String _membershipsCollection = 'Memberships';

  // ══════════════════════════════════════════════════════════════════════════
  // USERS
  // ══════════════════════════════════════════════════════════════════════════

  /// Create a new user document in Firestore.
  /// Called immediately after Firebase Auth account creation.
  Future<void> createUserInDB(
    String uid,
    String name,
    String email,
    String imageURL,
  ) async {
    try {
      await _db.collection(_userCollection).doc(uid).set({
        'name': name,
        'nameLower': name.toLowerCase(),
        'email': email,
        'image': imageURL,
        'lastSeen':
            FieldValue.serverTimestamp(), // ← use server time, not device
        'createdAt': FieldValue.serverTimestamp(),
      });
      print('✅ User created in Firestore: $uid');
    } catch (e) {
      print('❌ Error creating user: $e');
      rethrow;
    }
  }

  /// Fetch a single user's data by UID.
  /// Returns null if the document doesn't exist.
  Future<Map<String, dynamic>?> getUserData(String uid) async {
    try {
      final doc = await _db.collection(_userCollection).doc(uid).get();
      if (doc.exists) return {'uid': doc.id, ...doc.data()!};
      return null;
    } catch (e) {
      print('❌ Error getting user data: $e');
      return null;
    }
  }

  /// Partially update a user document.
  /// Pass only the fields you want to change, e.g. {'image': newUrl}.
  Future<void> updateUserData(String uid, Map<String, dynamic> data) async {
    try {
      await _db.collection(_userCollection).doc(uid).update(data);
      print('✅ User data updated: $uid');
    } catch (e) {
      print('❌ Error updating user data: $e');
      rethrow;
    }
  }

  /// Stamp the user's lastSeen field — call this on app resume / login.
  Future<void> updateLastSeen(String uid) async {
    try {
      await _db.collection(_userCollection).doc(uid).set({
        'lastSeen': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('❌ Error updating lastSeen: $e');
      // Not critical — swallow the error so it doesn't surface to the user
    }
  }

  /// Permanently delete a user document.
  /// Does NOT delete their Auth account or Storage files — handle those separately.
  Future<void> deleteUser(String uid) async {
    try {
      await _db.collection(_userCollection).doc(uid).delete();
      print('✅ User deleted: $uid');
    } catch (e) {
      print('❌ Error deleting user: $e');
      rethrow;
    }
  }

  /// Search users by name prefix — powers the "new conversation" search bar.
  /// Firestore has no native full-text search; this is a prefix match.
  /// Replace with Algolia/Typesense for production-grade search.
  Future<List<Map<String, dynamic>>> searchUsers(String query) async {
    try {
      final q = query.toLowerCase().trim();

      // Guard — don't fire a query for empty input
      if (q.isEmpty) return [];

      final result = await _db
          .collection(_userCollection)
          .where('nameLower', isGreaterThanOrEqualTo: q)
          .where('nameLower', isLessThanOrEqualTo: '$q\uf8ff')
          .limit(10)
          .get();

      return result.docs.map((doc) => {'uid': doc.id, ...doc.data()}).toList();
    } catch (e) {
      debugPrint('❌ searchUsers error: $e');
      return [];
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // CONVERSATIONS
  // ══════════════════════════════════════════════════════════════════════════

  /// Create a conversation between two users.
  ///
  /// The conversationId is derived deterministically by sorting both UIDs and
  /// joining them with an underscore — this guarantees that User A starting a
  /// chat with User B and User B starting a chat with User A always produce the
  /// same document, preventing duplicate conversations.
  ///
  /// A WriteBatch is used so all three writes (master doc + both user previews)
  /// either all succeed or all fail — no partial state on network errors.
  /// FIX 1: Named parameters + String return type to match search_page.dart.
  /// FIX 2: Sorted UID pair for deterministic conversation ID — A→B and B→A
  ///         always resolve to the same document.
  /// FIX 3: Each user's subcollection entry now stores the OTHER person's
  ///         name/image, so the conversation list shows the correct profile.
  ///         Previously both entries used currentUserName/Image, meaning the
  ///         current user always saw their own name/avatar in the list.
  /// FIX 4: Existence check via the user's OWN subcollection (isOwner rule)
  ///         instead of the Conversations doc (isConversationMember rule),
  ///         which was always denied for new conversations.
  Future<String> createConversation({
    required String currentUid,
    required String otherUid,
    required String currentUserName,
    required String currentUserImage,
    required String otherUserName,
    required String otherUserImage,
  }) async {
    try {
      // Deterministic ID — sort so A↔B always maps to the same document
      final List<String> ids = [currentUid, otherUid]..sort();
      final String conversationId = ids.join('_');

      // FIX 4: Check existence via the user's own subcollection —
      // the isOwner rule always allows this read, unlike isConversationMember
      // which denies reads on documents that don't exist yet.
      final existingDoc = await _db
          .collection(_userCollection)
          .doc(currentUid)
          .collection(_userConvSubcollection)
          .doc(conversationId)
          .get();

      if (existingDoc.exists) {
        debugPrint('ℹ️  Conversation already exists: $conversationId');
        return conversationId;
      }

      final WriteBatch batch = _db.batch();

      // Master conversation document
      batch.set(_db.collection(_conversationCollection).doc(conversationId), {
        'members': [currentUid, otherUid],
        'lastMessage': '',
        'timestamp': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      // FIX 3: Current user's entry shows the OTHER user's name/image
      batch.set(
        _db
            .collection(_userCollection)
            .doc(currentUid)
            .collection(_userConvSubcollection)
            .doc(conversationId),
        {
          'chatId': conversationId,
          'name': otherUserName, // ← other person's name
          'image': otherUserImage, // ← other person's image
          'lastMessage': '',
          'timestamp': FieldValue.serverTimestamp(),
          'unseenCount': 0,
        },
      );

      // FIX: Other user's entry shows the CURRENT user's name/image.
      // This was accidentally omitted — without it the receiver has no
      // subcollection doc, so sendMessage's batch.update() on that path
      // always fails with permission-denied (update on non-existent doc).
      batch.set(
        _db
            .collection(_userCollection)
            .doc(otherUid)
            .collection(_userConvSubcollection)
            .doc(conversationId),
        {
          'chatId': conversationId,
          'name': currentUserName, // ← current user's name
          'image': currentUserImage, // ← current user's image
          'lastMessage': '',
          'timestamp': FieldValue.serverTimestamp(),
          'unseenCount': 0,
        },
      );

      await batch.commit();
      debugPrint('✅ Conversation created: $conversationId');
      return conversationId;
    } catch (e) {
      debugPrint('❌ Error creating conversation: $e');
      rethrow;
    }
  }

  Future<void> markConversationAsSeen({
    required String conversationId,
    required String uid,
  }) async {
    try {
      // This is a more scalable approach. Instead of reading and writing every
      // message document, we just update the user's conversation preview.
      // The `unseenCount` is reset, and a `lastReadTimestamp` can be added
      // for more granular "seen" logic in the UI if needed.
      await _db
          .collection(_userCollection)
          .doc(uid)
          .collection(_userConvSubcollection)
          .doc(conversationId)
          .update({
            'unseenCount': 0,
            'lastReadTimestamp': FieldValue.serverTimestamp(),
          });
      // The previous implementation that updated `seenBy` on every message
      // was removed as it does not scale well with long conversations.
    } catch (e) {
      print('❌ Error marking conversation as seen: $e');
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // MESSAGES
  // ══════════════════════════════════════════════════════════════════════════

  /// Send a message of any supported type.
  ///
  /// Supported types:
  ///   'text'     → content is the message string
  ///   'image'    → content is a Firebase Storage download URL
  ///   'video'    → content is a Firebase Storage download URL
  ///   'audio'    → content is a Firebase Storage download URL (voice note)
  ///   'location' → content is "latitude,longitude" e.g. "5.6037,0.1870"
  ///
  /// Optional fields (image / video / audio only):
  ///   thumbnail  → preview image URL
  ///   duration   → length in seconds
  ///   size       → file size in bytes
  ///
  /// Uses a WriteBatch so the message write and all preview updates are atomic.
  Future<void> sendMessage({
    required String conversationId,
    required String senderId,
    required String receiverId,
    required String type,
    required String content,
    String? thumbnail,
    int? duration,
    int? size,
  }) async {
    try {
      // ── Build message payload ─────────────────────────────────────────────
      final Map<String, dynamic> messageData = {
        'senderId': senderId,
        'type': type,
        'content': content,
        'timestamp': FieldValue.serverTimestamp(),
        'seenBy': [senderId], // sender has implicitly seen their own message
      };

      // Only write optional fields when they carry a value — keeps docs lean
      if (thumbnail != null) messageData['thumbnail'] = thumbnail;
      if (duration != null) messageData['duration'] = duration;
      if (size != null) messageData['size'] = size;

      // ── Human-readable preview for the conversation list ──────────────────
      final String preview = switch (type) {
        'text' => content,
        'image' => '📷  Photo',
        'video' => '🎥  Video',
        'audio' => '🎤  Voice note',
        'location' => '📍  Location',
        _ => 'New message',
      };

      // ── Atomic batch: 4 writes ────────────────────────────────────────────
      final WriteBatch batch = _db.batch();

      // 1. New message document (auto-ID)
      final messageRef = _db
          .collection(_conversationCollection)
          .doc(conversationId)
          .collection(_messagesSubcollection)
          .doc();

      batch.set(messageRef, messageData);

      // 2. Update master conversation preview
      batch
          .update(_db.collection(_conversationCollection).doc(conversationId), {
            'lastMessage': preview,
            'lastMessageSender': senderId,
            'timestamp': FieldValue.serverTimestamp(),
          });

      // 3. Update sender's conversation preview (no unseenCount bump).
      // FIX: set(merge:true) instead of update() — update() throws if the
      // doc doesn't exist. merge:true creates it if missing, updates if present.
      batch.set(
        _db
            .collection(_userCollection)
            .doc(senderId)
            .collection(_userConvSubcollection)
            .doc(conversationId),
        {'lastMessage': preview, 'timestamp': FieldValue.serverTimestamp()},
        SetOptions(merge: true),
      );

      // 4. Update receiver's preview + atomically increment their unseenCount.
      // FIX: set(merge:true) instead of update() for same reason as above.
      // FieldValue.increment() is safe under concurrent writes.
      batch.set(
        _db
            .collection(_userCollection)
            .doc(receiverId)
            .collection(_userConvSubcollection)
            .doc(conversationId),
        {
          'lastMessage': preview,
          'timestamp': FieldValue.serverTimestamp(),
          'unseenCount': FieldValue.increment(1),
        },
        SetOptions(merge: true),
      );

      await batch.commit();
    } catch (e) {
      print('❌ Error sending message: $e');
      rethrow;
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // REAL-TIME STREAMS
  // ══════════════════════════════════════════════════════════════════════════

  /// Stream the current user's conversation list, newest first.
  /// Powers the conversations list screen.
  /// Each document emitted is a Users/{uid}/conversations/{chatId} preview.
  // In db_service.dart
  Stream<QuerySnapshot> streamConversations(String userId) {
    return _db
        .collection(_userCollection)
        .doc(userId)
        .collection(_userConvSubcollection)
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  /// Stream all messages in a conversation, oldest first.
  /// Powers the chat screen.
  /// includeMetadataChanges: false means we only emit confirmed server writes,
  /// so the timestamp field is never null when the UI reads it.
  Stream<QuerySnapshot> streamMessages(String conversationId) {
    return _db
        .collection(_conversationCollection)
        .doc(conversationId)
        .collection(_messagesSubcollection)
        .orderBy('timestamp', descending: false)
        .snapshots(includeMetadataChanges: false);
  }

  // ══════════════════════════════════════════════════════════════════════════
  // DELETE
  // ══════════════════════════════════════════════════════════════════════════

  /// Removes the conversation from THIS user's list only.
  /// The other participant's chat and all messages are unaffected —
  /// this mirrors how WhatsApp handles "delete for me".
  Future<void> deleteConversationForUser({
    required String conversationId,
    required String uid,
  }) async {
    try {
      await _db
          .collection(_userCollection)
          .doc(uid)
          .collection(_userConvSubcollection)
          .doc(conversationId)
          .delete();
      print('✅ Conversation removed for user: $uid');
    } catch (e) {
      print('❌ Error deleting conversation: $e');
      rethrow;
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // FIRMS (Multi-Tenant Support)
  // ══════════════════════════════════════════════════════════════════════════

  /// Create a firm with its admin user and membership in a single atomic operation.
  ///
  /// This method ensures that all three documents (Firm, User, Membership) are
  /// written together in a single batch. If any write fails, the entire operation
  /// is rolled back, preventing inconsistent state.
  ///
  /// Parameters:
  ///   - firmData: Firestore-compatible map (from Firm.toFirestore())
  ///   - userData: Firestore-compatible map (from AppUser.toFirestore())
  ///   - membershipData: Firestore-compatible map (from Membership.toFirestore())
  ///   - firmId: Document ID for the firm (can be auto-generated or custom)
  ///   - uid: Admin's Firebase Auth UID
  ///   - membershipId: Document ID for the membership (can be auto-generated)
  Future<Map<String, dynamic>> createFirmWithAdmin({
    required String firmId,
    required String uid,
    required String membershipId,
    required Map<String, dynamic> firmData,
    required Map<String, dynamic> userData,
    required Map<String, dynamic> membershipData,
  }) async {
    try {
      final WriteBatch batch = _db.batch();

      // 1. Create Firm document
      batch.set(_db.collection(_firmsCollection).doc(firmId), firmData);

      // 2. Create/Update User document with admin role
      batch.set(
        _db.collection(_userCollection).doc(uid),
        userData,
        SetOptions(merge: true), // Merge in case user already exists
      );

      // 3. Create Membership document linking user to firm
      batch.set(
        _db.collection(_membershipsCollection).doc(membershipId),
        membershipData,
      );

      // 4. Add admin to Firms/{firmId}/members/{uid} for directory listing
      final adminMemberRef = _db
          .collection(_firmsCollection)
          .doc(firmId)
          .collection('members')
          .doc(uid);
      batch.set(adminMemberRef, {
        'name': userData['name'] ?? 'Admin',
        'role': 'admin',
        'status': 'active',
        'createdAt': FieldValue.serverTimestamp(),
        'avatarUrl': 'https://api.dicebear.com/7.x/avataaars/png?seed=${Uri.encodeComponent((userData['name'] as String?) ?? 'Admin')}',
      });

      await batch.commit();
      print('✅ Firm created with admin: firmId=$firmId, uid=$uid');

      return {'firmId': firmId, 'uid': uid, 'membershipId': membershipId};
    } catch (e) {
      print('❌ Error creating firm with admin: $e');
      rethrow;
    }
  }

  /// Fetch a single firm by ID.
  /// Returns a Firm object.
  Future<Firm> getFirm(String firmId) async {
    try {
      final doc = await _db.collection(_firmsCollection).doc(firmId).get();
      if (doc.exists) {
        return FirmFirestore.fromFirestore(doc);
      }
      throw Exception('Firm not found: $firmId');
    } catch (e) {
      print('❌ Error getting firm: $e');
      rethrow;
    }
  }

  /// Stream all firms for a given user (by uid).
  /// Returns a stream of Firm objects that the user is a member of.
  Stream<List<Firm>> getUserFirms(String uid) {
    return _db
        .collection(_membershipsCollection)
        .where('uid', isEqualTo: uid)
        .snapshots()
        .asyncMap((membershipSnapshot) async {
          if (membershipSnapshot.docs.isEmpty) {
            return [];
          }

          // Get unique firm IDs from memberships to avoid duplicate fetches.
          final firmIds = membershipSnapshot.docs
              .map((doc) => doc['firmId'] as String)
              .toSet()
              .toList();

          if (firmIds.isEmpty) {
            return [];
          }

          // Fetch firms in chunks to respect Firestore's 'whereIn' 30-item limit.
          // This avoids the N+1 query problem of fetching each firm individually.
          const int chunkSize = 30;
          final List<Firm> firms = [];

          for (var i = 0; i < firmIds.length; i += chunkSize) {
            final chunk = firmIds.sublist(
              i,
              i + chunkSize > firmIds.length ? firmIds.length : i + chunkSize,
            );

            if (chunk.isEmpty) continue;

            try {
              final firmDocs = await _db
                  .collection(_firmsCollection)
                  .where(FieldPath.documentId, whereIn: chunk)
                  .get();
              for (final doc in firmDocs.docs) {
                try {
                  firms.add(FirmFirestore.fromFirestore(doc));
                } catch (e) {
                  debugPrint(
                    '❌ Error parsing firm document ${doc.id}, skipping: $e',
                  );
                }
              }
            } catch (e) {
              debugPrint('❌ Error fetching firms chunk: $e');
            }
          }
          return firms;
        });
  }

  /// Get a specific membership record (linking a user to a firm).
  Future<Map<String, dynamic>> getMembership(String membershipId) async {
    try {
      final doc = await _db
          .collection(_membershipsCollection)
          .doc(membershipId)
          .get();
      if (doc.exists) {
        return {'membershipId': doc.id, ...doc.data()!};
      }
      throw Exception('Membership not found: $membershipId');
    } catch (e) {
      print('❌ Error getting membership: $e');
      rethrow;
    }
  }

  /// Update a firm document (e.g., update brand colors).
  Future<void> updateFirm(String firmId, Map<String, dynamic> data) async {
    try {
      await _db.collection(_firmsCollection).doc(firmId).update(data);
      print('✅ Firm updated: $firmId');
    } catch (e) {
      print('❌ Error updating firm: $e');
      rethrow;
    }
  }

  /// Update a membership status (e.g., approve pending employee).
  Future<void> updateMembership(
    String membershipId,
    Map<String, dynamic> data,
  ) async {
    try {
      await _db
          .collection(_membershipsCollection)
          .doc(membershipId)
          .update(data);
      print('✅ Membership updated: $membershipId');
    } catch (e) {
      print('❌ Error updating membership: $e');
      rethrow;
    }
  }

  /// Stream memberships matching the firmId and a specific status (e.g., pending, approved).
  Stream<List<Membership>> getMembershipsByStatus(String firmId, String status) {
    if (FirebaseAuth.instance.currentUser == null) {
      return Stream.value([]);
    }
    final statusList = (status == 'approved') ? ['approved', 'active'] : [status];
    return _db
        .collection(_membershipsCollection)
        .where('firmId', isEqualTo: firmId)
        .where('status', whereIn: statusList)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => MembershipFirestore.fromFirestore(doc))
            .toList());
  }

  /// Fetch user details (name, image, etc.) from the Users collection.
  Future<AppUser?> getUserDetails(String uid) async {
    if (FirebaseAuth.instance.currentUser == null) {
      return null;
    }
    try {
      final doc = await _db.collection(_userCollection).doc(uid).get();
      if (doc.exists) {
        return AppUserFirestore.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      if (FirebaseAuth.instance.currentUser == null) return null;
      debugPrint('❌ Error getting user details: $e');
      return null;
    }
  }

  /// Update membership status (e.g., approved, rejected, or revoked).
  /// Also synchronizes the status inside the Firms/{firmId}/members/{uid} subcollection.
  Future<void> updateMembershipStatus(String membershipId, String newStatus) async {
    try {
      // Fetch the membership first to extract the uid and firmId
      final doc = await _db.collection(_membershipsCollection).doc(membershipId).get();
      if (!doc.exists) {
        throw Exception('Membership not found: $membershipId');
      }
      final data = doc.data()!;
      final String uid = data['uid'] ?? '';
      final String firmId = data['firmId'] ?? '';
      final String? preApprovedDocId = data['preApprovedDocId'] as String?;

      final WriteBatch batch = _db.batch();

      // 1. Update primary membership document status
      batch.update(_db.collection(_membershipsCollection).doc(membershipId), {
        'status': newStatus,
        if (newStatus == 'approved') 'approvedAt': FieldValue.serverTimestamp(),
        if (newStatus == 'revoked') 'revokedAt': FieldValue.serverTimestamp(),
        if (newStatus == 'rejected') 'rejectedAt': FieldValue.serverTimestamp(),
      });

      // 2. Synchronize status to the Firms/{firmId}/members/{uid} subcollection
      if (firmId.isNotEmpty && uid.isNotEmpty) {
        final firmMemberRef = _db
            .collection(_firmsCollection)
            .doc(firmId)
            .collection('members')
            .doc(uid);

        // Subcollection uses 'active' for approved users
        final String subcollectionStatus = (newStatus == 'approved') ? 'active' : newStatus;
        batch.set(firmMemberRef, {
          'status': subcollectionStatus,
        }, SetOptions(merge: true));
      }

      // 3. If approved and preApprovedDocId exists, mark PreApprovedStaff as joined
      if (newStatus == 'approved' && preApprovedDocId != null && preApprovedDocId.isNotEmpty && firmId.isNotEmpty) {
        final preApprovedRef = _db
            .collection(_firmsCollection)
            .doc(firmId)
            .collection('PreApprovedStaff')
            .doc(preApprovedDocId);
        batch.update(preApprovedRef, {
          'status': 'joined',
          'joinedAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();
      debugPrint('✅ Membership status updated: membershipId=$membershipId, newStatus=$newStatus');
    } catch (e) {
      debugPrint('❌ Error updating membership status: $e');
      rethrow;
    }
  }

  /// Stream active colleagues belonging to the given firm (scoped to Firm/{firmId}/members).
  Stream<List<Map<String, dynamic>>> streamFirmMembers(String firmId) {
    return _db
        .collection(_firmsCollection)
        .doc(firmId)
        .collection('members')
        .where('status', isEqualTo: 'active')
        .limit(50)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => {'uid': doc.id, ...doc.data()})
            .toList());
  }

  // ══════════════════════════════════════════════════════════════════════════
  // ORCHESTRATION: Firm Signup (Atomic Operations)
  // ══════════════════════════════════════════════════════════════════════════

  /// Orchestrate the complete firm signup flow:
  /// 1. Create Firm document
  /// 2. Create/Update User document with super_admin role
  /// 3. Create Membership document linking user to firm (with status: approved)
  ///
  /// This method expects the Firebase Auth account to already exist.
  /// Call this AFTER Firebase Auth.createUserWithEmailAndPassword() succeeds.
  ///
  /// Returns the generated firmId on success.
  Future<String> signUpWithFirm({
    required String uid,
    required String email,
    required String adminName,
    required String firmName,
    required String primaryColor,
  }) async {
    try {
      final firmId = _db.collection(_firmsCollection).doc().id;
      final membershipId = uid;

      final firmData = {
        'name': firmName,
        'primaryColor': primaryColor,
        'ownerUid': uid,
        'adminId': uid,
        'plan': 'trial',
        'status': 'active',
        'seatLimit': 5,
        'seatCount': 1,
        'termsAcceptedAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      };

      final userData = {
        'name': adminName,
        'nameLower': adminName.toLowerCase(),
        'email': email,
        'role': 'super_admin',
        'ownedFirmId': firmId,
        'firmIds': FieldValue.arrayUnion([firmId]),
        'createdAt': FieldValue.serverTimestamp(),
        'lastSeen': FieldValue.serverTimestamp(),
      };

      final membershipData = {
        'uid': uid,
        'firmId': firmId,
        'status': 'active',
        'role': 'admin',
        'createdAt': FieldValue.serverTimestamp(),
        'joinedAt': FieldValue.serverTimestamp(),
        'approvedAt': FieldValue.serverTimestamp(),
      };

      final WriteBatch batch = _db.batch();
      batch.set(_db.collection(_firmsCollection).doc(firmId), firmData);
      batch.set(_db.collection(_userCollection).doc(uid), userData, SetOptions(merge: true));
      batch.set(_db.collection(_membershipsCollection).doc(membershipId), membershipData);

      final adminMemberRef = _db
          .collection(_firmsCollection)
          .doc(firmId)
          .collection('members')
          .doc(uid);
      batch.set(adminMemberRef, {
        'name': adminName,
        'role': 'admin',
        'status': 'active',
        'joinedAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
        'avatarUrl': 'https://api.dicebear.com/7.x/avataaars/png?seed=${Uri.encodeComponent(adminName)}',
      });

      await batch.commit();
      debugPrint('✅ Firm created with trial plan and admin membership: firmId=$firmId, uid=$uid');
      return firmId;
    } catch (e) {
      debugPrint('❌ Error signing up with firm: $e');
      rethrow;
    }
  }

  /// Add pre-approved staff member with one-time verification code and increment seatCount.
  Future<void> addPreApprovedStaff({
    required String firmId,
    required String email,
    required String name,
    required String code,
  }) async {
    try {
      final firmDoc = await _db.collection(_firmsCollection).doc(firmId).get();
      if (!firmDoc.exists) throw Exception('Firm not found: $firmId');
      
      final data = firmDoc.data()!;
      final int seatCount = (data['seatCount'] as num?)?.toInt() ?? 1;
      final int seatLimit = (data['seatLimit'] as num?)?.toInt() ?? 5;

      if (seatCount >= seatLimit) {
        throw Exception('Trial seat limit of $seatLimit seats reached. Cannot add more staff.');
      }

      final cleanEmail = email.trim().toLowerCase();
      final staffRef = _db
          .collection(_firmsCollection)
          .doc(firmId)
          .collection('PreApprovedStaff')
          .doc();

      final WriteBatch batch = _db.batch();
      batch.set(staffRef, {
        'email': cleanEmail,
        'name': name.trim(),
        'code': code.trim(),
        'status': 'invited',
        'role': 'employee',
        'invitedAt': FieldValue.serverTimestamp(),
      });

      batch.update(_db.collection(_firmsCollection).doc(firmId), {
        'seatCount': FieldValue.increment(1),
      });

      await batch.commit();
      debugPrint('✅ Pre-approved staff added: $cleanEmail (code: $code)');
    } catch (e) {
      debugPrint('❌ Error adding pre-approved staff: $e');
      rethrow;
    }
  }

  /// Remove pre-approved staff member and decrement seatCount.
  Future<void> removePreApprovedStaff({
    required String firmId,
    required String staffDocId,
  }) async {
    try {
      final staffRef = _db
          .collection(_firmsCollection)
          .doc(firmId)
          .collection('PreApprovedStaff')
          .doc(staffDocId);

      final WriteBatch batch = _db.batch();
      batch.delete(staffRef);
      batch.update(_db.collection(_firmsCollection).doc(firmId), {
        'seatCount': FieldValue.increment(-1),
      });

      await batch.commit();
      debugPrint('✅ Pre-approved staff removed: $staffDocId');
    } catch (e) {
      debugPrint('❌ Error removing pre-approved staff: $e');
      rethrow;
    }
  }

  /// Stream pre-approved staff list for the admin console.
  Stream<List<Map<String, dynamic>>> streamPreApprovedStaff(String firmId) {
    return _db
        .collection(_firmsCollection)
        .doc(firmId)
        .collection('PreApprovedStaff')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => {'id': doc.id, ...doc.data()})
            .toList());
  }

  /// Verify one-time code and onboard an employee in a single atomic transaction.
  Future<void> verifyAndOnboardEmployee({
    required String firmId,
    required String uid,
    required String email,
    required String name,
    required String code,
  }) async {
    try {
      final cleanEmail = email.trim().toLowerCase();
      final cleanCode = code.trim();

      // Check PreApprovedStaff for matching email and one-time code
      final query = await _db
          .collection(_firmsCollection)
          .doc(firmId)
          .collection('PreApprovedStaff')
          .where('email', isEqualTo: cleanEmail)
          .get();

      if (query.docs.isEmpty) {
        throw Exception(
          'Email not found on pre-authorized staff list. Please contact your company administrator.',
        );
      }

      QueryDocumentSnapshot<Map<String, dynamic>>? matchedDoc;
      for (final doc in query.docs) {
        final docCode = (doc.data()['code'] as String?)?.trim();
        final docStatus = doc.data()['status'] as String?;
        if (docCode == cleanCode && docStatus == 'invited') {
          matchedDoc = doc;
          break;
        }
      }

      if (matchedDoc == null) {
        throw Exception(
          'Invalid or already used verification code. Please check with your company administrator.',
        );
      }

      final WriteBatch batch = _db.batch();

      // 1. Mark pre-approved record as joined
      batch.update(matchedDoc.reference, {
        'status': 'joined',
        'joinedAt': FieldValue.serverTimestamp(),
        'uid': uid,
      });

      // 2. Write active membership in firms/{firmId}/members/{uid}
      final firmMemberRef = _db
          .collection(_firmsCollection)
          .doc(firmId)
          .collection('members')
          .doc(uid);

      batch.set(
        firmMemberRef,
        {
          'name': name.trim(),
          'role': 'employee',
          'status': 'active',
          'joinedAt': FieldValue.serverTimestamp(),
          'avatarUrl': 'https://api.dicebear.com/7.x/avataaars/png?seed=${Uri.encodeComponent(name.trim())}',
        },
        SetOptions(merge: true),
      );

      // 3. Update Users/{uid} identity document
      final userRef = _db.collection(_userCollection).doc(uid);
      batch.set(
        userRef,
        {
          'name': name.trim(),
          'nameLower': name.trim().toLowerCase(),
          'email': cleanEmail,
          'role': 'employee',
          'firmIds': FieldValue.arrayUnion([firmId]),
          'lastSeen': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      // 4. Update legacy Memberships/{uid} for backward compatibility
      final legacyMembershipRef = _db.collection(_membershipsCollection).doc(uid);
      batch.set(
        legacyMembershipRef,
        {
          'uid': uid,
          'firmId': firmId,
          'email': cleanEmail,
          'name': name.trim(),
          'status': 'active',
          'role': 'employee',
          'joinedAt': FieldValue.serverTimestamp(),
          'approvedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      await batch.commit();
      debugPrint('✅ Employee $cleanEmail successfully onboarded with active membership in $firmId');
    } catch (e) {
      debugPrint('❌ Error onboarding employee: $e');
      rethrow;
    }
  }

  /// Backward-compatible profile registration
  Future<void> registerEmployeeProfile({
    required String uid,
    required String firmId,
    required String name,
    required String email,
    String? jobTitle,
    bool isApproved = false,
    String? preApprovedDocId,
  }) async {
    try {
      final WriteBatch batch = _db.batch();
      final userRef = _db.collection(_userCollection).doc(uid);
      batch.set(
        userRef,
        {
          'name': name,
          'nameLower': name.toLowerCase(),
          'email': email,
          'role': 'employee',
          'firmIds': FieldValue.arrayUnion([firmId]),
          'createdAt': FieldValue.serverTimestamp(),
          'lastSeen': FieldValue.serverTimestamp(),
          if (jobTitle != null && jobTitle.isNotEmpty) 'jobTitle': jobTitle,
        },
        SetOptions(merge: true),
      );

      final membershipRef = _db.collection(_membershipsCollection).doc(uid);
      batch.set(
        membershipRef,
        {
          'uid': uid,
          'firmId': firmId,
          'email': email,
          'name': name,
          'status': isApproved ? 'active' : 'pending',
          'role': 'employee',
          'createdAt': FieldValue.serverTimestamp(),
          if (jobTitle != null && jobTitle.isNotEmpty) 'jobTitle': jobTitle,
          if (isApproved) 'joinedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      final firmMemberRef = _db
          .collection(_firmsCollection)
          .doc(firmId)
          .collection('members')
          .doc(uid);
      batch.set(
        firmMemberRef,
        {
          'name': name,
          'role': 'employee',
          'status': isApproved ? 'active' : 'pending',
          'joinedAt': FieldValue.serverTimestamp(),
          'createdAt': FieldValue.serverTimestamp(),
          'avatarUrl': 'https://api.dicebear.com/7.x/avataaars/png?seed=${Uri.encodeComponent(name)}',
        },
        SetOptions(merge: true),
      );

      await batch.commit();
      debugPrint('✅ Employee profile registered: uid=$uid, firmId=$firmId');
    } catch (e) {
      debugPrint('❌ Error in registerEmployeeProfile: $e');
      rethrow;
    }
  }
  // ────────────────────────────────────────────────────────────────────────────────
}
