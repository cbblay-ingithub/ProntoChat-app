import 'package:flutter/material.dart';
import '../screens/auth/sign_in_screen.dart';

/// Legacy LoginPage wrapper delegating to the unified SignInScreen.
class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const SignInScreen();
  }
}