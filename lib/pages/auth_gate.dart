import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import 'home_page.dart';
import 'login_page.dart';

/// AuthGate sits at the root of the widget tree and watches AuthProvider.
///
/// Why this exists:
///   Firebase restores a previous session automatically on cold-start.
///   Without a gate, the app would always open on the login page and then
///   need to detect and redirect — causing a flash of the wrong screen.
///   AuthGate renders the correct screen immediately on every launch.
///
/// Flow:
///   Authenticating (profile loading)  → neutral splash
///   Authenticated                      → HomePage
///   NotAuthenticated / Error           → LoginPage
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    // While Firebase re-establishes a session on cold-start, show a branded
    // splash so there is no flash of the login page for returning users.
    if (auth.isAuthenticating) {
      return const Scaffold(
        backgroundColor: Color.fromRGBO(28, 27, 27, 1),
        body: Center(
          child: CircularProgressIndicator(
            color: Color.fromRGBO(41, 116, 188, 1),
          ),
        ),
      );
    }

    return auth.isAuthenticated ? const HomePage() : const LoginPage();
  }
}