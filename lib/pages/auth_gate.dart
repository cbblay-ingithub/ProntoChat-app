import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import 'home_page.dart';
import 'login_page.dart';

/// AuthGate sits at the root of the widget tree and watches AuthProvider.
///
/// Flow:
///   isInitializing (token validation + profile load) → splash
///   isAuthenticating (explicit login in progress)    → splash
///   Authenticated                                    → HomePage
///   NotAuthenticated / Error                         → LoginPage
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    // FIX: Check isInitializing (not just isAuthenticating) for the splash.
    //
    // isAuthenticating is only true during an explicit login() call.
    // On cold-start, Firebase restores a persisted session via
    // _onAuthStateChanged — status stays notAuthenticated until the full
    // async sequence completes, so the old isAuthenticating check was
    // ALWAYS false on app launch.
    //
    // isInitializing is true from the moment _onAuthStateChanged fires
    // until the ID token is validated + profile is loaded — exactly the
    // window we need to block to prevent premature Firestore streams.
    if (auth.isInitializing || auth.isAuthenticating) {
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