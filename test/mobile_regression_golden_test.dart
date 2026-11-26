import 'dart:async';
import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pronto_chat/pages/home_page.dart';
import 'package:pronto_chat/providers/auth_provider.dart';
import 'package:pronto_chat/screens/auth/join_screen.dart';
import 'package:pronto_chat/screens/auth/sign_in_screen.dart';
import 'package:pronto_chat/screens/auth/welcome_screen.dart';
import 'package:pronto_chat/theme/pc_tokens.dart';
import 'package:provider/provider.dart' as provider;

class _MobileAuthStub extends ChangeNotifier implements AuthProvider {
  @override
  AuthStatus status = AuthStatus.authenticated;

  @override
  String? errorMessage;

  @override
  bool get isInitializing => false;

  @override
  bool get isAuthenticating => false;

  @override
  bool get isAuthenticated => true;

  @override
  String? get currentUserId => 'emp_alex_101';

  @override
  String get currentUserName => 'Alex Morgan';

  @override
  String? get currentUserEmail => 'alex.morgan@apexlegal.com';

  @override
  String get currentUserImage => '';

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

Future<void> _loadSdkFontsIfAvailable() async {
  const fontDir = r'C:\Users\cyrus\flutter\flutter\bin\cache\artifacts\material_fonts';
  final dir = Directory(fontDir);
  if (!dir.existsSync()) return;

  Future<ByteData> readFont(String file) async {
    final bytes = await File('$fontDir\\$file').readAsBytes();
    return ByteData.sublistView(bytes);
  }

  final roboto = FontLoader('Roboto')
    ..addFont(readFont('roboto-regular.ttf'))
    ..addFont(readFont('roboto-medium.ttf'))
    ..addFont(readFont('roboto-bold.ttf'));
  await roboto.load();

  final icons = FontLoader('MaterialIcons')
    ..addFont(readFont('materialicons-regular.otf'));
  await icons.load();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setupFirebaseCoreMocks();

  setUpAll(() async {
    await Firebase.initializeApp();
    await _loadSdkFontsIfAvailable();

    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    const mockedPigeonChannels = [
      'dev.flutter.pigeon.firebase_auth_platform_interface.FirebaseAuthHostApi.registerIdTokenListener',
      'dev.flutter.pigeon.firebase_auth_platform_interface.FirebaseAuthHostApi.registerAuthStateListener',
      'dev.flutter.pigeon.cloud_firestore_platform_interface.FirebaseFirestoreHostApi.documentReferenceSnapshot',
      'dev.flutter.pigeon.cloud_firestore_platform_interface.FirebaseFirestoreHostApi.querySnapshot',
      'dev.flutter.pigeon.cloud_firestore_platform_interface.FirebaseFirestoreHostApi.documentReferenceGet',
      'dev.flutter.pigeon.cloud_firestore_platform_interface.FirebaseFirestoreHostApi.queryGet',
      'dev.flutter.pigeon.cloud_firestore_platform_interface.FirebaseFirestoreHostApi.documentReferenceSet',
      'dev.flutter.pigeon.cloud_firestore_platform_interface.FirebaseFirestoreHostApi.documentReferenceUpdate',
    ];
    for (final ch in mockedPigeonChannels) {
      messenger.setMockMessageHandler(
        ch,
        (_) => Completer<ByteData?>().future,
      );
    }
  });

  Widget wrapMobile(Widget child) {
    final baseTheme = PcThemeBuilder.buildLightTheme(
      primaryColor: const Color(0xFF00C853),
    );
    return ProviderScope(
      child: provider.ChangeNotifierProvider<AuthProvider>(
        create: (_) => _MobileAuthStub(),
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: baseTheme.copyWith(
            textTheme: baseTheme.textTheme.apply(fontFamily: 'Roboto'),
          ),
          home: child,
        ),
      ),
    );
  }

  group('Mobile Pixel-Identical Regression Goldens', () {
    testWidgets('Mobile Welcome, SignIn, Join, and Workspace tabs remain pixel-identical',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(780, 1688);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.reset);

      // 1. Welcome Screen
      await tester.pumpWidget(wrapMobile(const WelcomeScreen()));
      await tester.pump(const Duration(milliseconds: 100));
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/mobile_welcome.png'),
      );

      // 2. Sign In Screen
      await tester.pumpWidget(wrapMobile(const SignInScreen()));
      await tester.pump(const Duration(milliseconds: 100));
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/mobile_sign_in.png'),
      );

      // 3. Join Screen
      await tester.pumpWidget(wrapMobile(const JoinScreen()));
      await tester.pump(const Duration(milliseconds: 100));
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/mobile_join.png'),
      );

      // 4. HomePage -> Chats, Directory & Profile tabs
      await tester.pumpWidget(wrapMobile(const HomePage()));
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.text('Chats'));
      await tester.pump(const Duration(milliseconds: 100));
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/mobile_chats_tab.png'),
      );

      await tester.tap(find.text('Directory'));
      await tester.pump(const Duration(milliseconds: 100));
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/mobile_directory_tab.png'),
      );

      await tester.tap(find.text('Profile'));
      await tester.pump(const Duration(milliseconds: 100));
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/mobile_profile_tab.png'),
      );
    });
  });
}
