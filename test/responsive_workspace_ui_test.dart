import 'package:firebase_core/firebase_core.dart';
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pronto_chat/pages/home_page.dart';
import 'package:pronto_chat/providers/auth_provider.dart';
import 'package:pronto_chat/theme/pc_tokens.dart';
import 'package:provider/provider.dart' as provider;

class _FakeReadyAuthProvider extends AuthProvider {
  @override
  bool get isInitializing => false;

  @override
  bool get isAuthenticating => false;

  @override
  String? get currentUserId => 'emp_alex_101';

  @override
  String get currentUserName => 'Alex Morgan';

  @override
  String? get currentUserEmail => 'alex.morgan@apexlegal.com';

  @override
  String get currentUserImage => '';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setupFirebaseCoreMocks();

  setUpAll(() async {
    await Firebase.initializeApp();
  });

  Widget buildTestableWorkspace() {
    return ProviderScope(
      child: provider.ChangeNotifierProvider<AuthProvider>(
        create: (_) => _FakeReadyAuthProvider(),
        child: MaterialApp(
          theme: PcThemeBuilder.buildLightTheme(
            primaryColor: const Color(0xFF2563EB),
          ),
          home: const HomePage(),
        ),
      ),
    );
  }

  group('Adaptive Mobile + 3-Pane Web Workspace & Clean Light Tokens', () {
    test('PcThemeBuilder builds clean light theme and ensures contrast on bright accents', () {
      final theme = PcThemeBuilder.buildLightTheme(
        primaryColor: const Color(0xFFFFEE00), // bright yellow firm color
      );
      final tokens = theme.extension<PcTokens>()!;

      expect(theme.brightness, Brightness.light);
      expect(tokens.surface, const Color(0xFFFFFFFF));
      expect(tokens.canvas, const Color(0xFFF8FAFC));
      // Bright yellow is darkened automatically so text/accents stay readable on white
      expect(HSLColor.fromColor(tokens.primary).lightness, lessThanOrEqualTo(0.45));
    });

    testWidgets('Mobile viewport (390x844) renders bottom NavigationBar without overflow',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(buildTestableWorkspace());
      await tester.pump();

      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Chats'), findsOneWidget);
      expect(find.text('Directory'), findsAtLeastNWidgets(1));
      expect(find.text('Profile'), findsOneWidget);
    });

    testWidgets('Desktop/Web viewport (1280x820) renders 3-pane Slack/Linear workspace without NavigationBar',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 820);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(buildTestableWorkspace());
      await tester.pump();

      // No mobile bottom NavigationBar on desktop/web
      expect(find.byType(NavigationBar), findsNothing);

      // Persistent Pane 2 (Conversations sidebar) + Pane 3 (Home portal) coexist side-by-side!
      expect(find.text('Conversations'), findsOneWidget);
      expect(find.text('Workspace Portal'), findsOneWidget);

      // Switch to Messages stage via rail tooltip 'Messages'
      await tester.tap(find.byTooltip('Messages'));
      await tester.pump();

      // Inline chat composer is rendered right inside Pane 3 alongside Pane 2!
      expect(find.text('Conversations'), findsOneWidget);
      expect(find.text('Type a message...'), findsOneWidget);
    });
  });
}
