import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart'; // Make sure this import exists
import './pages/login_page.dart';
import './services/snackbar_service.dart';
import './pages/registration_page.dart';
import './services/navigation_service.dart';
import './services/db_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase with options for the current platform
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Get SnackbarService instance
    final snackbarService = SnackbarService();
    
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
      initialRoute: "/login",
      routes: {
       '/login': (context) => const LoginPage(),
        '/register': (context) => const RegistrationPage(),

      },
      // ✅ FIX: Use the service's scaffoldMessengerKey
      navigatorKey: NavigationService.instance.navigatorKey,
      scaffoldMessengerKey: snackbarService.scaffoldMessengerKey,
      debugShowCheckedModeBanner: false,
    );
  }
}