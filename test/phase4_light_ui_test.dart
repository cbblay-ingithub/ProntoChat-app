import 'package:firebase_core/firebase_core.dart';
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pronto_chat/providers/auth_provider.dart';
import 'package:pronto_chat/screens/admin/admin_shell.dart';
import 'package:pronto_chat/screens/auth/join_screen.dart';
import 'package:pronto_chat/screens/auth/sign_in_screen.dart';
import 'package:pronto_chat/screens/auth/welcome_screen.dart';
import 'package:pronto_chat/theme/pc_tokens.dart';
import 'package:pronto_chat/widgets/dashboard/dashboard_tokens.dart';
import 'package:provider/provider.dart' as provider;

class _TestAuthProvider extends AuthProvider {
  @override
  bool get isInitializing => false;

  @override
  bool get isAuthenticating => false;
}

double _contrastRatio(Color a, Color b) {
  final l1 = a.computeLuminance();
  final l2 = b.computeLuminance();
  final lighter = l1 > l2 ? l1 : l2;
  final darker = l1 > l2 ? l2 : l1;
  return (lighter + 0.05) / (darker + 0.05);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setupFirebaseCoreMocks();

  setUpAll(() async {
    await Firebase.initializeApp();
  });

  Widget wrapWithLightTheme(Widget child) {
    return ProviderScope(
      child: provider.ChangeNotifierProvider<AuthProvider>(
        create: (_) => _TestAuthProvider(),
        child: MaterialApp(
          theme: PcThemeBuilder.buildLightTheme(
            primaryColor: const Color(0xFF2563EB),
          ),
          home: child,
        ),
      ),
    );
  }

  group('Phase 4 Clean Light-Mode UI: Auth, Onboarding & Admin Hub', () {
    test('DashboardTokens meet WCAG AA contrast on white card surfaces', () {
      expect(DashboardTokens.surfaceDark, const Color(0xFFFFFFFF));
      expect(
        _contrastRatio(DashboardTokens.textPrimary, DashboardTokens.surfaceDark),
        greaterThanOrEqualTo(7.0),
      );
      expect(
        _contrastRatio(
          DashboardTokens.textSecondary,
          DashboardTokens.surfaceDark,
        ),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        _contrastRatio(DashboardTokens.textMuted, DashboardTokens.surfaceDark),
        greaterThanOrEqualTo(4.5),
      );
    });

    testWidgets('WelcomeScreen preserves keys and adapts across mobile and desktop',
        (WidgetTester tester) async {
      for (final size in [const Size(390, 844), const Size(1280, 820)]) {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;

        await tester.pumpWidget(wrapWithLightTheme(const WelcomeScreen()));
        await tester.pump();

        expect(find.byKey(const Key('welcome_sign_in_button')), findsOneWidget);
        expect(
          find.byKey(const Key('welcome_join_company_button')),
          findsOneWidget,
        );
        expect(find.text('ProntoChat'), findsOneWidget);
      }
      addTearDown(tester.view.reset);
    });

    testWidgets('SignInScreen preserves form keys on mobile and desktop card layout',
        (WidgetTester tester) async {
      for (final size in [const Size(390, 844), const Size(1280, 820)]) {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;

        await tester.pumpWidget(wrapWithLightTheme(const SignInScreen()));
        await tester.pump();

        expect(find.byKey(const Key('sign_in_email_field')), findsOneWidget);
        expect(find.byKey(const Key('sign_in_password_field')), findsOneWidget);
        expect(find.byKey(const Key('sign_in_submit_button')), findsOneWidget);
      }
      addTearDown(tester.view.reset);
    });

    testWidgets('JoinScreen preserves all onboarding form keys in light mode',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 860);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(wrapWithLightTheme(const JoinScreen()));
      await tester.pump();

      expect(find.byKey(const Key('join_firm_id_field')), findsOneWidget);
      expect(find.byKey(const Key('join_code_field')), findsOneWidget);
      expect(find.byKey(const Key('join_name_field')), findsOneWidget);
      expect(find.byKey(const Key('join_email_field')), findsOneWidget);
      expect(find.byKey(const Key('join_password_field')), findsOneWidget);
      expect(find.byKey(const Key('join_submit_button')), findsOneWidget);
    });

    testWidgets('AdminShell renders light collapsible rail on desktop and drawer on mobile',
        (WidgetTester tester) async {
      final router = GoRouter(
        initialLocation: '/admin/dashboard',
        routes: [
          StatefulShellRoute.indexedStack(
            builder: (context, state, shell) =>
                AdminShell(navigationShell: shell),
            branches: [
              StatefulShellBranch(
                routes: [
                  GoRoute(
                    path: '/admin/dashboard',
                    builder: (_, _) => const Center(child: Text('Dash Pane')),
                  ),
                ],
              ),
              StatefulShellBranch(
                routes: [
                  GoRoute(
                    path: '/admin/onboarding',
                    builder: (_, _) => const Center(child: Text('Onboard Pane')),
                  ),
                ],
              ),
              StatefulShellBranch(
                routes: [
                  GoRoute(
                    path: '/admin/notices',
                    builder: (_, _) => const Center(child: Text('Notices Pane')),
                  ),
                ],
              ),
              StatefulShellBranch(
                routes: [
                  GoRoute(
                    path: '/admin/brand',
                    builder: (_, _) => const Center(child: Text('Brand Pane')),
                  ),
                ],
              ),
            ],
          ),
        ],
      );

      // 1. Desktop (1280x820): Persistent left rail visible
      tester.view.physicalSize = const Size(1280, 820);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp.router(
            theme: PcThemeBuilder.buildLightTheme(
              primaryColor: const Color(0xFF2563EB),
            ),
            routerConfig: router,
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Management Hub'), findsOneWidget);
      expect(find.text('Onboarding'), findsOneWidget);
      expect(find.text('Notices & Groups'), findsOneWidget);
      expect(find.text('Customization'), findsOneWidget);
      expect(find.text('Dash Pane'), findsOneWidget);

      // Collapse rail and verify tooltips remain accessible
      await tester.tap(find.byTooltip('Collapse Sidebar'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Expand Sidebar'), findsOneWidget);

      // 2. Mobile (390x844): Switches to compact navigation drawer
      tester.view.physicalSize = const Size(390, 844);
      await tester.pumpAndSettle();
      expect(find.byTooltip('Open Navigation'), findsOneWidget);
    });
  });
}
