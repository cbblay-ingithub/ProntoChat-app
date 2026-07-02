import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:provider/provider.dart' as provider;
import 'firebase_options.dart';
import './pages/auth_gate.dart';
import './pages/admin_dashboard.dart';
import './pages/home_page.dart';
import './pages/login_page.dart';
import './pages/registration_page.dart';
import './pages/register_firm_page.dart';
import './pages/search_page.dart';
import './providers/auth_provider.dart';
import './services/navigation_service.dart';
import './services/snackbar_service.dart';
import './services/deep_link_service.dart';
import './providers/deep_link_provider.dart';
import './router/app_router.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase with options for the current platform
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // ── PRONTOCHAT ADDITION ──
  // Instantiate DeepLinkService inside main() before runApp()
  final deepLinkService = DeepLinkService.instance;
  // ─────────────────────────

  runApp(
    ProviderScope(
      // ── PRONTOCHAT ADDITION ──
      observers: [
        AppRouteObserver(),
      ],
      overrides: [
        deepLinkServiceProvider.overrideWithValue(deepLinkService),
      ],
      // ─────────────────────────
      child: provider.ChangeNotifierProvider(
        create: (_) => AuthProvider(),
        child: const MyApp(),
      ),
    ),
  );
}

// ── PRONTOCHAT ADDITION ──
class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  // Instantiated once at the class level — not inside build() — so the same
  // scaffoldMessengerKey is reused across every rebuild.
  static final SnackbarService _snackbarService = SnackbarService();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(goRouterProvider);

    return MaterialApp.router(
      title: 'ProntoChat',
      theme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: const ColorScheme.dark(
          primary: Color.fromRGBO(41, 116, 188, 1),
          secondary: Color.fromRGBO(41, 116, 188, 1),
          surface: Color.fromRGBO(28, 27, 27, 1),
        ),
        scaffoldBackgroundColor: const Color.fromRGBO(28, 27, 27, 1),
      ),
      // Use the GoRouter config
      routerConfig: router,
      scaffoldMessengerKey: _snackbarService.scaffoldMessengerKey,
      debugShowCheckedModeBanner: false,
    );
  }
}
// ─────────────────────────
