import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/chat_message.dart';

class ChatService {
  ChatService._internal();
  static final ChatService instance = ChatService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Returns a real-time stream of messages from the Firms/{firmId}/Messages collection,
  /// ordered by timestamp descending, limited to the last 100 messages.
  Stream<List<ChatMessage>> getFirmMessages(String firmId) {
    return _db
        .collection('Firms')
        .doc(firmId)
        .collection('Messages')
        .orderBy('timestamp', descending: true)
        .limit(100)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return ChatMessage.fromMap(doc.data(), doc.id);
      }).toList();
    });
  }

  /// Writes a new ChatMessage document to the firm's Messages subcollection.
  Future<void> sendMessage(
    String firmId,
    String uid,
    String senderName,
    String text,
  ) async {
    try {
      final messageRef = _db
          .collection('Firms')
          .doc(firmId)
          .collection('Messages')
          .doc();

      final chatMessage = ChatMessage(
        messageId: messageRef.id,
        senderId: uid,
        senderName: senderName,
        text: text,
        timestamp: DateTime.now(),
      );

      await messageRef.set(chatMessage.toMap());
    } catch (e) {
      // Log/rethrow
      rethrow;
    }
  }
}
