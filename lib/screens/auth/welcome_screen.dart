import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Mobile-only welcome screen for employees.
/// Contains no firm registration or admin setup.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color.fromRGBO(24, 23, 23, 1),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: size.width * 0.08, vertical: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 20),

              // Brand Hero Section
              Column(
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: const Color.fromRGBO(41, 116, 188, 0.15),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: const Color.fromRGBO(41, 116, 188, 0.4),
                        width: 1.5,
                      ),
                    ),
                    child: const Icon(
                      Icons.chat_bubble_outline_rounded,
                      size: 40,
                      color: Color.fromRGBO(41, 116, 188, 1),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'ProntoChat',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Your Secure Corporate Workspace',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[400],
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),

              // Action Buttons
              Column(
                children: [
                  // Sign In Button (Returning employees)
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      key: const Key('welcome_sign_in_button'),
                      onPressed: () => context.go('/sign-in'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color.fromRGBO(41, 116, 188, 1),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Sign In',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Join Your Company Button (New employee onboarding)
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: OutlinedButton.icon(
                      key: const Key('welcome_join_company_button'),
                      onPressed: () => context.go('/join'),
                      icon: const Icon(Icons.apartment_outlined, size: 20),
                      label: const Text(
                        'Join Your Company',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(
                          color: Color.fromRGBO(41, 116, 188, 0.8),
                          width: 1.5,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Employee mobile access only',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
