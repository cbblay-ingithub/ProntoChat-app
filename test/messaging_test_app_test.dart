import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pronto_chat/messaging_test_app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Messaging test suite renders and allows typing and sending messages', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MessagingTestApp(),
      ),
    );

    await tester.pump();

    // Verify top controls and headers are visible
    expect(find.text('TEST MODE: MESSAGING HARNESS'), findsOneWidget);
    expect(find.text('Acme Corp Workspace'), findsOneWidget);
    expect(find.text('Team Chat'), findsOneWidget);
    expect(find.text('1-on-1 DM'), findsOneWidget);

    // Verify initial seed messages
    expect(find.text('Welcome to the Acme Corp workspace!'), findsOneWidget);

    // Enter a new test message into the text field
    final textFieldFinder = find.byType(TextField);
    expect(textFieldFinder, findsOneWidget);

    await tester.enterText(textFieldFinder, 'Testing real-time messaging pipeline');
    await tester.pump();

    // Tap the send button
    final sendButtonFinder = find.byIcon(Icons.send);
    expect(sendButtonFinder, findsOneWidget);

    await tester.tap(sendButtonFinder);
    await tester.pump();

    // Verify the sent message appears on the screen
    expect(find.text('Testing real-time messaging pipeline'), findsOneWidget);

    // Switch to 1-on-1 Direct Message tab
    await tester.tap(find.text('1-on-1 DM'));
    await tester.pumpAndSettle();

    // Verify 1-on-1 DM header and conversation
    expect(find.text('Sarah Jenkins'), findsWidgets);
    expect(find.text('Online'), findsOneWidget);
    expect(find.text('Direct message Sarah...'), findsOneWidget);

    // Switch back to Team Chat
    await tester.tap(find.text('Team Chat'));
    await tester.pumpAndSettle();
    expect(find.text('Acme Corp Workspace'), findsOneWidget);
  });
}
