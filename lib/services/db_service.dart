import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
  final String _userCollection         = 'Users';
  final String _conversationCollection = 'Conversations';
  final String _messagesSubcollection  = 'Messages';
  final String _userConvSubcollection  = 'conversations'; // lives under Users/{uid}


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
        'name'      : name,
        'email'     : email,
        'image'     : imageURL,
        'lastSeen'  : FieldValue.serverTimestamp(), // ← use server time, not device
        'createdAt' : FieldValue.serverTimestamp(),
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
      await _db.collection(_userCollection).doc(uid).update({
        'lastSeen': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('❌ Error updating lastSeen: $e');
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
      final result = await _db
          .collection(_userCollection)
          .where('name', isGreaterThanOrEqualTo: query)
          .where('name', isLessThanOrEqualTo: '$query\uf8ff')
          .limit(10)
          .get();

      return result.docs
          .map((doc) => {'uid': doc.id, ...doc.data()})
          .toList();
    } catch (e) {
      print('❌ Error searching users: $e');
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
      batch.set(
        _db.collection(_conversationCollection).doc(conversationId),
        {
          'members'     : [currentUid, otherUid],
          'lastMessage' : '',
          'timestamp'   : FieldValue.serverTimestamp(),
          'createdAt'   : FieldValue.serverTimestamp(),
        },
      );

      // FIX 3: Current user's entry shows the OTHER user's name/image
      batch.set(
        _db.collection(_userCollection).doc(currentUid)
            .collection(_userConvSubcollection).doc(conversationId),
        {
          'chatId'      : conversationId,
          'name'        : otherUserName,    // ← other person's name
          'image'       : otherUserImage,   // ← other person's image
          'lastMessage' : '',
          'timestamp'   : FieldValue.serverTimestamp(),
          'unseenCount' : 0,
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
    await _db
        .collection(_userCollection)
        .doc(uid)
        .collection(_userConvSubcollection)
        .doc(conversationId)
        .update({'unseenCount': 0});

    // ✅ Filter client-side — Firestore has no "array does not contain" query
    final allMessages = await _db
        .collection(_conversationCollection)
        .doc(conversationId)
        .collection(_messagesSubcollection)
        .get();

    final unseenDocs = allMessages.docs.where((doc) {
      final seenBy = List<String>.from(doc.data()['seenBy'] ?? []);
      return !seenBy.contains(uid);
    }).toList();

    if (unseenDocs.isEmpty) return;

    final WriteBatch batch = _db.batch();
    for (final doc in unseenDocs) {
      batch.update(doc.reference, {
        'seenBy': FieldValue.arrayUnion([uid]),
      });
    }
    await batch.commit();

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
    int?    duration,
    int?    size,
  }) async {
    try {
      // ── Build message payload ─────────────────────────────────────────────
      final Map<String, dynamic> messageData = {
        'senderId'  : senderId,
        'type'      : type,
        'content'   : content,
        'timestamp' : FieldValue.serverTimestamp(),
        'seenBy'    : [senderId], // sender has implicitly seen their own message
      };

      // Only write optional fields when they carry a value — keeps docs lean
      if (thumbnail != null) messageData['thumbnail'] = thumbnail;
      if (duration  != null) messageData['duration']  = duration;
      if (size      != null) messageData['size']       = size;

      // ── Human-readable preview for the conversation list ──────────────────
      final String preview = switch (type) {
        'text'     => content,
        'image'    => '📷  Photo',
        'video'    => '🎥  Video',
        'audio'    => '🎤  Voice note',
        'location' => '📍  Location',
        _          => 'New message',
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
      batch.update(
        _db.collection(_conversationCollection).doc(conversationId),
        {
          'lastMessage'       : preview,
          'lastMessageSender' : senderId,
          'timestamp'         : FieldValue.serverTimestamp(),
        },
      );

      // 3. Update sender's conversation preview (no unseenCount bump)
      batch.update(
        _db
            .collection(_userCollection)
            .doc(senderId)
            .collection(_userConvSubcollection)
            .doc(conversationId),
        {
          'lastMessage' : preview,
          'timestamp'   : FieldValue.serverTimestamp(),
        },
      );

      // 4. Update receiver's preview + atomically increment their unseenCount
      // FieldValue.increment() is safe under concurrent writes — never do
      // read-then-write for counters in Firestore.
      batch.update(
        _db
            .collection(_userCollection)
            .doc(receiverId)
            .collection(_userConvSubcollection)
            .doc(conversationId),
        {
          'lastMessage' : preview,
          'timestamp'   : FieldValue.serverTimestamp(),
          'unseenCount' : FieldValue.increment(1),
        },
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
}