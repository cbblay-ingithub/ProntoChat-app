import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_core/firebase_core.dart';
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/test.dart';
import 'package:provider/provider.dart' as provider;
import 'package:pronto_chat/pages/login_page.dart';
import 'package:pronto_chat/providers/auth_provider.dart';
import 'package:pronto_chat/services/navigation_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setupFirebaseCoreMocks();

  setUpAll(() async {
    await Firebase.initializeApp();
  });

  testWidgets('LoginPage renders Join with Firm ID button and opens dialog', (WidgetTester tester) async {
    String? navigatedRoute;
    NavigationService.instance.onNavigateTo = (route) async {
      navigatedRoute = route;
      return null;
    };

    await tester.pumpWidget(
      provider.ChangeNotifierProvider(
        create: (_) => AuthProvider(),
        child: const MaterialApp(
          home: LoginPage(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify button exists
    final joinButtonFinder = find.byKey(const Key('join_firm_with_id_button'));
    expect(joinButtonFinder, findsOneWidget);
    expect(find.text('Join with Firm ID or Code'), findsOneWidget);

    // Tap the join button to open dialog
    await tester.tap(joinButtonFinder);
    await tester.pumpAndSettle();

    // Verify dialog is open
    expect(find.text('Join Your Firm'), findsOneWidget);
    final dialogTextField = find.byKey(const Key('firm_id_dialog_text_field'));
    expect(dialogTextField, findsOneWidget);

    // Enter a Firm ID into the TextField
    await tester.enterText(dialogTextField, 'firm_test_123');
    await tester.pumpAndSettle();

    // Tap Continue
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    // Verify navigation was triggered with the cleaned Firm ID
    expect(navigatedRoute, equals('/employee-onboarding?firmId=firm_test_123'));
  });

  testWidgets('LoginPage manual join extracts firmId from full URL if pasted', (WidgetTester tester) async {
    String? navigatedRoute;
    NavigationService.instance.onNavigateTo = (route) async {
      navigatedRoute = route;
      return null;
    };

    await tester.pumpWidget(
      provider.ChangeNotifierProvider(
        create: (_) => AuthProvider(),
        child: const MaterialApp(
          home: LoginPage(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Tap the join button
    await tester.tap(find.byKey(const Key('join_firm_with_id_button')));
    await tester.pumpAndSettle();

    // Paste a full link
    final dialogTextField = find.byKey(const Key('firm_id_dialog_text_field'));
    await tester.enterText(dialogTextField, 'https://officespace.chottu.link/?firmId=pasted_firm_999');
    await tester.pumpAndSettle();

    // Tap Continue
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    // Verify it cleanly extracted the firmId parameter
    expect(navigatedRoute, equals('/employee-onboarding?firmId=pasted_firm_999'));
  });
}
