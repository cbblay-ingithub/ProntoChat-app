import 'package:cloud_firestore/cloud_firestore.dart';

class ChatMessage {
  final String messageId;
  final String senderId;
  final String senderName;
  final String text;
  final DateTime timestamp;

  ChatMessage({
    required this.messageId,
    required this.senderId,
    required this.senderName,
    required this.text,
    required this.timestamp,
  });

  /// Factory constructor to parse Firestore document into ChatMessage
  factory ChatMessage.fromMap(Map<String, dynamic> map, String id) {
    DateTime parsedTime;
    final dynamic rawTimestamp = map['timestamp'];
    if (rawTimestamp is Timestamp) {
      parsedTime = rawTimestamp.toDate();
    } else if (rawTimestamp is int) {
      parsedTime = DateTime.fromMillisecondsSinceEpoch(rawTimestamp);
    } else if (rawTimestamp is String) {
      parsedTime = DateTime.tryParse(rawTimestamp) ?? DateTime.now();
    } else {
      parsedTime = DateTime.now();
    }

    return ChatMessage(
      messageId: id,
      senderId: map['senderId'] ?? '',
      senderName: map['senderName'] ?? '',
      text: map['text'] ?? '',
      timestamp: parsedTime,
    );
  }

  /// Converts ChatMessage instance into Firestore-compatible Map
  Map<String, dynamic> toMap() {
    return {
      'senderId': senderId,
      'senderName': senderName,
      'text': text,
      'timestamp': FieldValue.serverTimestamp(),
    };
  }
}
