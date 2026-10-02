import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/test.dart';
import 'package:pronto_chat/models/firm.dart';
import 'package:pronto_chat/pages/employee/employee_home_tab.dart';
import 'package:pronto_chat/pages/employee/employee_chats_tab.dart';
import 'package:pronto_chat/pages/employee/employee_directory_tab.dart';
import 'package:pronto_chat/pages/employee/employee_profile_tab.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setupFirebaseCoreMocks();

  setUpAll(() async {
    await Firebase.initializeApp();
  });

  final testFirm = Firm(
    firmId: 'test_firm_123',
    name: 'Apex Legal Partners',
    primaryColor: '#2974BC',
    adminId: 'admin_123',
    createdAt: DateTime.now(),
  );

  group('Employee Experience Widget Tests', () {
    testWidgets('EmployeeHomeTab renders greeting, firm card, and quick actions',
        (WidgetTester tester) async {
      int tappedIndex = -1;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: EmployeeHomeTab(
                uid: 'user_alex',
                userName: 'Alex Morgan',
                firm: testFirm,
                onNavigateToTab: (index) => tappedIndex = index,
              ),
            ),
          ),
        ),
      );

      await tester.pump();

      // Check greeting & first name
      expect(find.byWidgetPredicate((widget) =>
          widget is Text &&
          (widget.data?.startsWith('Good ') ?? false)), findsOneWidget);
      expect(find.textContaining('Alex'), findsOneWidget);
      expect(find.text('Apex Legal Partners'), findsAtLeastNWidgets(1));

      // Check quick action labels
      expect(find.text('Team Chat'), findsOneWidget);
      expect(find.text('Directory'), findsOneWidget);
      expect(find.text('Message'), findsOneWidget);

      // Tap on Directory quick action (index 2)
      await tester.tap(find.text('Directory'));
      expect(tappedIndex, equals(2));
    });

    testWidgets('EmployeeChatsTab renders title, firm context, and FAB',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: EmployeeChatsTab(
                uid: 'user_alex',
                userName: 'Alex Morgan',
                firm: testFirm,
              ),
            ),
          ),
        ),
      );

      await tester.pump();

      // AppBar header and actions
      expect(find.text('Conversations'), findsOneWidget);
      expect(find.text('Apex Legal Partners'), findsOneWidget);
      expect(find.byType(FloatingActionButton), findsOneWidget);
    });

    testWidgets('EmployeeDirectoryTab renders search input and header',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: EmployeeDirectoryTab(
                firm: testFirm,
                uid: 'user_alex',
                userName: 'Alex Morgan',
              ),
            ),
          ),
        ),
      );

      await tester.pump();

      expect(find.text('Staff Directory'), findsOneWidget);
      expect(find.text('Apex Legal Partners'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Search colleagues by name or role...'), findsOneWidget);
    });

    testWidgets('EmployeeProfileTab renders user and firm organization details',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: EmployeeProfileTab(
                uid: 'user_alex',
                userName: 'Alex Morgan',
                email: 'alex.morgan@apexlegal.com',
                firm: testFirm,
              ),
            ),
          ),
        ),
      );

      await tester.pump();

      expect(find.text('Alex Morgan'), findsOneWidget);
      expect(find.text('alex.morgan@apexlegal.com'), findsOneWidget);
      expect(find.text('Workspace & Firm Details'), findsOneWidget);
      expect(find.text('Apex Legal Partners'), findsOneWidget);
      expect(find.text('Sign Out'), findsOneWidget);
    });
  });
}
