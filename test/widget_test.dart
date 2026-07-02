import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/test.dart';
import 'package:provider/provider.dart' as provider;
import 'package:pronto_chat/main.dart';
import 'package:pronto_chat/providers/auth_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setupFirebaseCoreMocks();

  setUpAll(() async {
    await Firebase.initializeApp();
  });

  testWidgets('App load smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(
      ProviderScope(
        child: provider.ChangeNotifierProvider(
          create: (_) => AuthProvider(),
          child: const MyApp(),
        ),
      ),
    );

    // Verify loading indicator is shown initially in the AuthGate splash screen
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
