import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/test.dart';
import 'package:provider/provider.dart' as provider;
import 'package:pronto_chat/main.dart';
import 'package:pronto_chat/providers/auth_provider.dart';
import 'package:pronto_chat/providers/deep_link_provider.dart';
import 'package:pronto_chat/screens/employee/employee_profile_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setupFirebaseCoreMocks();

  setUpAll(() async {
    await Firebase.initializeApp();
  });

  testWidgets('Deep link triggers redirect to EmployeeProfileScreen', (WidgetTester tester) async {
    final controller = StreamController<String>.broadcast();

    // Pump the app with overridden providers
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          firmIdFromLinkProvider.overrideWith((ref) => controller.stream),
        ],
        child: provider.ChangeNotifierProvider(
          create: (_) => AuthProvider(),
          child: const MyApp(),
        ),
      ),
    );

    // Initial tick to let first frame settle
    await tester.pump();

    // Simulate emitting a valid firmId deep link event
    controller.add('test-firm-123');

    // Run microtasks and give the stream event time to propagate
    for (int i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 10));
    }
    
    // Pump frames to complete the route transition to onboarding screen and then to profile screen
    await tester.pump(const Duration(milliseconds: 500));

    // Verify that the EmployeeProfileScreen is shown (since Onboarding screen immediately redirects)
    expect(find.byType(EmployeeProfileScreen), findsOneWidget);
    expect(find.text('Who Are You?'), findsOneWidget);
    expect(find.text('Full Name'), findsOneWidget);

    controller.close();
  });
}
