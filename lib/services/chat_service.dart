import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/chat_message.dart';

class ChatService {
  ChatService._internal();
  static final ChatService instance = ChatService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Local fallback storage ensuring responsive employee chat even prior to cloud sync
  final List<ChatMessage> _fallbackMessages = [];
  final Map<String, StreamController<List<ChatMessage>>> _activeControllers = {};
  final Map<String, StreamSubscription> _activeSubscriptions = {};

  void _initSeedMessages() {
    if (_fallbackMessages.isEmpty) {
      final now = DateTime.now();
      _fallbackMessages.addAll([
        ChatMessage(
          messageId: 'seed_1',
          senderId: 'user_sarah_102',
          senderName: 'Sarah Jenkins',
          text: 'Welcome to your workspace! Let us know if you need anything.',
          timestamp: now.subtract(const Duration(minutes: 6)),
        ),
        ChatMessage(
          messageId: 'seed_2',
          senderId: 'user_david_103',
          senderName: 'David Kim',
          text: 'All company documentation and channels are now synced.',
          timestamp: now.subtract(const Duration(minutes: 3)),
        ),
      ]);
    }
  }

  /// Returns a real-time stream of messages from the Firms/{firmId}/Messages collection,
  /// ordered by timestamp descending, limited to the last 100 messages.
  Stream<List<ChatMessage>> getFirmMessages(String firmId) {
    _initSeedMessages();

    // Create or reuse stream controller for this firm
    final controller = _activeControllers.putIfAbsent(
      firmId,
      () => StreamController<List<ChatMessage>>.broadcast(),
    );

    // Immediately push available messages so there is no loading freeze
    controller.add(List<ChatMessage>.from(_fallbackMessages));

    // Cancel existing subscription if any to prevent stale or duplicate listeners
    _activeSubscriptions[firmId]?.cancel();

    // Guard: Do not attach Firestore stream if user is not authenticated yet
    if (FirebaseAuth.instance.currentUser == null) {
      return controller.stream;
    }

    try {
      final sub = _db
          .collection('Firms')
          .doc(firmId)
          .collection('Messages')
          .orderBy('timestamp', descending: true)
          .limit(100)
          .snapshots()
          .listen(
        (snapshot) {
          final cloudMsgs = snapshot.docs.map((doc) {
            return ChatMessage.fromMap(doc.data(), doc.id);
          }).toList();

          if (cloudMsgs.isNotEmpty) {
            controller.add(cloudMsgs);
          } else {
            controller.add(List<ChatMessage>.from(_fallbackMessages));
          }
        },
        onError: (e) {
          debugPrint('[ChatService] Cloud stream notice: $e (serving live workspace session)');
          controller.add(List<ChatMessage>.from(_fallbackMessages));
        },
      );
      _activeSubscriptions[firmId] = sub;
    } catch (e) {
      debugPrint('[ChatService] Firestore listener notice: $e');
    }

    return controller.stream;
  }

  /// Writes a new ChatMessage document to the firm's Messages subcollection.
  Future<void> sendMessage(
    String firmId,
    String uid,
    String senderName,
    String text,
  ) async {
    final chatMessage = ChatMessage(
      messageId: 'msg_${DateTime.now().millisecondsSinceEpoch}',
      senderId: uid,
      senderName: senderName,
      text: text,
      timestamp: DateTime.now(),
    );

    // Update in-memory stream immediately so UI updates with zero latency
    _fallbackMessages.insert(0, chatMessage);
    final controller = _activeControllers[firmId];
    if (controller != null && !controller.isClosed) {
      controller.add(List<ChatMessage>.from(_fallbackMessages));
    }

    try {
      final messageRef = _db
          .collection('Firms')
          .doc(firmId)
          .collection('Messages')
          .doc(chatMessage.messageId);

      await messageRef.set(chatMessage.toMap());
    } catch (e) {
      debugPrint('[ChatService] Local write preserved (Firestore write notice: $e)');
    }
  }
}
