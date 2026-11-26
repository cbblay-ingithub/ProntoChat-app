import 'dart:async';
import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pronto_chat/models/firm.dart';
import 'package:pronto_chat/providers/firm/providers.dart';
import 'package:pronto_chat/screens/admin/admin_shell.dart';
import 'package:pronto_chat/screens/admin/tabs/customization_tab.dart';
import 'package:pronto_chat/theme/admin_theme_provider.dart';
import 'package:pronto_chat/theme/admin_theme_storage.dart';
import 'package:pronto_chat/theme/pc_tokens.dart';
import 'package:pronto_chat/theme/pronto_tokens.dart';

Future<void> _loadAllSdkFonts() async {
  const fontDir =
      r'C:\Users\cyrus\flutter\flutter\bin\cache\artifacts\material_fonts';
  final dir = Directory(fontDir);
  if (!dir.existsSync()) return;

  Future<ByteData> readFont(String file) async {
    final bytes = await File('$fontDir\\$file').readAsBytes();
    return ByteData.sublistView(bytes);
  }

  for (final family in [
    'Roboto',
    '.SF Pro Text',
    '.SF UI Text',
    'Ahem',
    'packages/flutter_test/Ahem',
  ]) {
    final loader = FontLoader(family)
      ..addFont(readFont('roboto-thin.ttf'))
      ..addFont(readFont('roboto-light.ttf'))
      ..addFont(readFont('roboto-regular.ttf'))
      ..addFont(readFont('roboto-medium.ttf'))
      ..addFont(readFont('roboto-bold.ttf'))
      ..addFont(readFont('roboto-black.ttf'))
      ..addFont(readFont('roboto-italic.ttf'))
      ..addFont(readFont('roboto-bolditalic.ttf'));
    await loader.load();
  }

  final icons = FontLoader('MaterialIcons')
    ..addFont(readFont('materialicons-regular.otf'));
  await icons.load();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setupFirebaseCoreMocks();

  setUpAll(() async {
    await Firebase.initializeApp();
    await _loadAllSdkFonts();

    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    const mockedPigeonChannels = [
      'dev.flutter.pigeon.firebase_auth_platform_interface.FirebaseAuthHostApi.registerIdTokenListener',
      'dev.flutter.pigeon.firebase_auth_platform_interface.FirebaseAuthHostApi.registerAuthStateListener',
      'dev.flutter.pigeon.cloud_firestore_platform_interface.FirebaseFirestoreHostApi.documentReferenceSnapshot',
      'dev.flutter.pigeon.cloud_firestore_platform_interface.FirebaseFirestoreHostApi.querySnapshot',
    ];
    for (final ch in mockedPigeonChannels) {
      messenger.setMockMessageHandler(
        ch,
        (_) => Completer<ByteData?>().future,
      );
    }
  });

  testWidgets(
      'Slice 1: AdminShell + CustomizationTab live re-theming across 5 themes x Light/Dark x 1920x1080 & 900x1080',
      (WidgetTester tester) async {
    AdminThemeStorage.writeCachedAccentHex('#00C853');
    AdminThemeStorage.writeCachedThemeId('calm');
    AdminThemeStorage.writeDarkMode(false);

    final sampleFirm = Firm(
      firmId: 'apex_legal',
      name: 'Apex Legal Partners',
      primaryColor: '#00C853',
      themeId: 'calm',
      welcomeText:
          'Welcome to Apex Legal Partners! Enter your 6-digit staff code.',
    );

    final router = GoRouter(
      initialLocation: '/admin/brand',
      routes: [
        StatefulShellRoute.indexedStack(
          builder: (context, state, navigationShell) =>
              AdminShell(navigationShell: navigationShell),
          branches: [
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/admin/dashboard',
                  builder: (_, _) => const SizedBox.shrink(),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/admin/onboarding',
                  builder: (_, _) => const SizedBox.shrink(),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/admin/notices',
                  builder: (_, _) => const SizedBox.shrink(),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/admin/brand',
                  builder: (_, _) => const CustomizationTab(),
                ),
              ],
            ),
          ],
        ),
      ],
    );

    final container = ProviderContainer(
      overrides: [
        currentFirmProvider.overrideWithValue(sampleFirm),
      ],
    );
    addTearDown(container.dispose);

    // ── Viewport A: 1920x1080 ───────────────────────────────────────────────
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          debugShowCheckedModeBanner: false,
          theme: PcThemeBuilder.buildLightTheme(
            primaryColor: const Color(0xFF00C853),
          ),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 1. Light Mode @ 1920x1080 across all 5 themes
    for (final theme in ProntoThemeId.values) {
      await tester.tap(find.text(theme.label).first);
      await tester.pumpAndSettle();
      expect(
        container.read(adminThemeSpecProvider).themeId,
        equals(theme),
      );
      expect(
        container.read(adminThemeSpecProvider).brightness,
        equals(Brightness.light),
      );
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/slice1/light_1920_${theme.id}.png'),
      );
    }

    // 2. Toggle Dark Mode ON via the Customization Light/Dark Switch @ 1920x1080
    await tester.tap(find.byTooltip('Switch to Dark Mode'));
    await tester.pumpAndSettle();
    expect(container.read(adminThemeControllerProvider).isDarkMode, isTrue);

    for (final theme in ProntoThemeId.values) {
      await tester.tap(find.text(theme.label).first);
      await tester.pumpAndSettle();
      expect(
        container.read(adminThemeSpecProvider).themeId,
        equals(theme),
      );
      expect(
        container.read(adminThemeSpecProvider).brightness,
        equals(Brightness.dark),
      );
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/slice1/dark_1920_${theme.id}.png'),
      );
    }

    // ── Viewport B: Narrow ~900px (900x1080) ────────────────────────────────
    tester.view.physicalSize = const Size(900, 1080);
    await tester.pumpAndSettle();

    Future<void> scrollMainToTop() async {
      final scrollables = tester.widgetList<Scrollable>(find.byType(Scrollable));
      for (final s in scrollables) {
        if (s.axisDirection == AxisDirection.down && s.controller != null && s.controller!.hasClients) {
          s.controller!.jumpTo(0);
        }
      }
      final states = tester.stateList<ScrollableState>(find.byType(Scrollable));
      for (final st in states) {
        if (st.widget.axisDirection == AxisDirection.down) {
          st.position.jumpTo(0);
        }
      }
      await tester.pumpAndSettle();
    }

    // 3. Dark Mode @ 900x1080 across all 5 themes
    for (final theme in ProntoThemeId.values) {
      await tester.ensureVisible(find.text(theme.label).first);
      await tester.tap(find.text(theme.label).first);
      await scrollMainToTop();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/slice1/dark_900_${theme.id}.png'),
      );
    }

    // 4. Toggle back to Light Mode @ 900x1080 across all 5 themes
    await tester.tap(find.byTooltip('Switch to Light Mode'));
    await tester.pumpAndSettle();
    expect(container.read(adminThemeControllerProvider).isDarkMode, isFalse);

    for (final theme in ProntoThemeId.values) {
      await tester.ensureVisible(find.text(theme.label).first);
      await tester.tap(find.text(theme.label).first);
      await scrollMainToTop();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/slice1/light_900_${theme.id}.png'),
      );
    }

    // 5. Verify Reset restores default #295CB4 + Calm live, and Discard reverts to firm (#00C853 + Calm)
    await tester.ensureVisible(find.text('Reset'));
    await tester.tap(find.text('Reset'));
    await tester.pumpAndSettle();
    expect(
      container.read(adminThemeControllerProvider).effectiveAccentHex,
      equals('#295CB4'),
    );
    expect(
      container.read(adminThemeControllerProvider).effectiveThemeId,
      equals(ProntoThemeId.calm),
    );

    await tester.ensureVisible(find.text('Discard'));
    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();
    expect(
      container.read(adminThemeControllerProvider).effectiveAccentHex,
      equals('#00C853'),
    );
  });
}
