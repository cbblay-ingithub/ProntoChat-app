import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;          // ← ADD THIS
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:provider/provider.dart' as provider;
import 'package:chottu_link/chottu_link.dart';
import 'firebase_options.dart';
import './providers/auth_provider.dart';
import './services/snackbar_service.dart';
import './services/deep_link_service.dart';
import './providers/deep_link_provider.dart';
import './router/app_router.dart';
import './providers/firm/providers.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ── PRONTOCHAT ADDITION ──
  // Initialize ChottuLink SDK only on non‑web platforms
  if (!kIsWeb) {
    await ChottuLink.init(apiKey: "c_app_ECNOhsxucPhr24xZuncLBSaT8SxbN234");
  }
  // ─────────────────────────

  // Initialize Firebase with options for the current platform
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // ── PRONTOCHAT ADDITION ──
  // Instantiate DeepLinkService only on non‑web platforms
  final deepLinkService = kIsWeb ? null : DeepLinkService.instance;
  // ─────────────────────────

  runApp(
    ProviderScope(
      observers: [
        AppRouteObserver(),
      ],
      overrides: [
        if (deepLinkService != null)                             // ← CONDITIONAL OVERRIDE
          deepLinkServiceProvider.overrideWithValue(deepLinkService),
      ],
      child: provider.ChangeNotifierProvider(
        create: (_) => AuthProvider(),
        child: const MyApp(),
      ),
    ),
  );
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  static final SnackbarService _snackbarService = SnackbarService();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(goRouterProvider);
    final theme = ref.watch(brandThemeProvider);

    // Watch the loader provider to trigger membership loading in the background
    ref.watch(membershipLoaderProvider);

    return MaterialApp.router(
      title: 'ProntoChat',
      theme: theme,
      routerConfig: router,
      scaffoldMessengerKey: _snackbarService.scaffoldMessengerKey,
      debugShowCheckedModeBanner: false,
    );
  }
}