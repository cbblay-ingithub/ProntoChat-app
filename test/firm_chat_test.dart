import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:provider/provider.dart' as provider;
import 'package:firebase_core/firebase_core.dart';
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/test.dart';
import 'package:pronto_chat/models/chat_message.dart';
import 'package:pronto_chat/providers/auth_provider.dart';
import 'package:pronto_chat/screens/employee/firm_chat_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setupFirebaseCoreMocks();

  setUpAll(() async {
    await Firebase.initializeApp();
  });

  group('ChatMessage Model Mapping Tests', () {
    test('ChatMessage fromMap correctly parses map structure with Timestamp', () {
      final now = DateTime.now();
      // Mocking Firebase Timestamp class conversion
      final mapData = {
        'senderId': 'user_123',
        'senderName': 'Alice Developer',
        'text': 'Hello world! This is a test message.',
        'timestamp': now, // In tests, Firestore mocks accept DateTime directly
      };

      final chatMsg = ChatMessage.fromMap(mapData, 'msg_abc');

      expect(chatMsg.messageId, equals('msg_abc'));
      expect(chatMsg.senderId, equals('user_123'));
      expect(chatMsg.senderName, equals('Alice Developer'));
      expect(chatMsg.text, equals('Hello world! This is a test message.'));
      // Note: raw timestamp is DateTime in this case, matching now
      expect(chatMsg.timestamp, isNotNull);
    });

    test('ChatMessage toMap creates valid Firestore serialization structure', () {
      final chatMsg = ChatMessage(
        messageId: 'msg_xyz',
        senderId: 'user_456',
        senderName: 'Bob Designer',
        text: 'Visual aesthetics look premium!',
        timestamp: DateTime.now(),
      );

      final map = chatMsg.toMap();

      expect(map['senderId'], equals('user_456'));
      expect(map['senderName'], equals('Bob Designer'));
      expect(map['text'], equals('Visual aesthetics look premium!'));
      expect(map['timestamp'], isNotNull); // FieldValue.serverTimestamp() representation
    });
  });

  testWidgets('FirmChatScreen UI structure and inputs render correctly', (WidgetTester tester) async {
    await tester.pumpWidget(
      provider.ChangeNotifierProvider(
        create: (_) => AuthProvider(),
        child: const ProviderScope(
          child: MaterialApp(
            home: FirmChatScreen(
              firmId: 'test_firm_id',
              uid: 'test_uid',
              name: 'Test Employee',
            ),
          ),
        ),
      ),
    );

    // Initial frame tick
    await tester.pump();

    // Verify critical elements are present
    expect(find.byType(TextField), findsOneWidget);
    expect(find.byIcon(Icons.send), findsOneWidget);
    expect(find.text('Type a message...'), findsOneWidget);
    expect(find.text('Workspace'), findsOneWidget);
    expect(find.text('General Team Chat'), findsOneWidget);
  });
}
