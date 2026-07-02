import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/test.dart';
import 'package:pronto_chat/pages/register_firm_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setupFirebaseCoreMocks();

  setUpAll(() async {
    await Firebase.initializeApp();
  });

  testWidgets('RegisterFirmPage validation and structure test', (WidgetTester tester) async {
    // Build RegisterFirmPage under ProviderScope and MaterialApp
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: RegisterFirmPage(),
        ),
      ),
    );

    // Verify structural elements are present
    expect(find.text('Create Your Firm'), findsOneWidget);
    expect(find.text('Set up your corporate chat platform'), findsOneWidget);
    expect(find.byType(TextFormField), findsNWidgets(4)); // Email, Password, Full Name, Firm Name
    expect(find.text('Create Firm'), findsOneWidget);

    // Tap "Create Firm" to trigger form validation
    await tester.tap(find.text('Create Firm'));
    await tester.pump();

    // Verify that empty validation messages are displayed
    expect(find.text('Email is required'), findsOneWidget);
    expect(find.text('Password is required'), findsOneWidget);
    expect(find.text('This field is required'), findsNWidgets(2)); // Name & Company fields
  });
}
