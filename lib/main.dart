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

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase with options for the current platform
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(
    ProviderScope(
      child: provider.ChangeNotifierProvider(
        create: (_) => AuthProvider(),
        child: const MyApp(),
      ),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // Instantiated once at the class level — not inside build() — so the same
  // scaffoldMessengerKey is reused across every rebuild.
  static final SnackbarService _snackbarService = SnackbarService();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
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
      // AuthGate is the root — it watches AuthProvider and renders
      // HomePage (authenticated) or LoginPage (not authenticated).
      // This handles both cold-starts with an existing session and
      // explicit login/logout flows without any manual navigation.
      home: const AuthGate(),
      routes: {
        '/login': (context) => const LoginPage(),
        '/register': (context) => const RegistrationPage(),
        '/register-firm': (context) => const RegisterFirmPage(),
        '/home': (context) => const HomePage(),
        '/admin-dashboard': (context) => const AdminDashboard(),
        '/search': (context) => const UserSearchPage(),
      },
      // ✅ FIX: Use the service's scaffoldMessengerKey
      navigatorKey: NavigationService.instance.navigatorKey,
      scaffoldMessengerKey: _snackbarService.scaffoldMessengerKey,
      debugShowCheckedModeBanner: false,
    );
  }
}
