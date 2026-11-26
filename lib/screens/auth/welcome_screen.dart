import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../theme/pc_tokens.dart';

/// Mobile-first welcome screen for employees (also responsive if opened on tablet/web).
/// Contains no firm registration or admin setup.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final tokens = context.pcTokens;
    final width = MediaQuery.sizeOf(context).width;
    final isWide = !PcBreakpoints.isCompact(width);

    final content = Column(
      mainAxisSize: isWide ? MainAxisSize.min : MainAxisSize.max,
      mainAxisAlignment:
          isWide ? MainAxisAlignment.center : MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (!isWide) const SizedBox(height: 20),

        // Brand Hero Section
        Column(
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: tokens.primarySoft,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: tokens.primaryBorder,
                  width: 1.5,
                ),
              ),
              child: Icon(
                Icons.chat_bubble_outline_rounded,
                size: 40,
                color: tokens.primary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'ProntoChat',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w800,
                color: tokens.textPrimary,
                letterSpacing: -0.6,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your Secure Corporate Workspace',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15.5,
                color: tokens.textSecondary,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),

        if (isWide) const SizedBox(height: 36),

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
                  backgroundColor: tokens.primary,
                  foregroundColor: tokens.onPrimary,
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
            const SizedBox(height: 14),

            // Join Your Company Button (New employee onboarding)
            SizedBox(
              width: double.infinity,
              height: 52,
              child: OutlinedButton.icon(
                key: const Key('welcome_join_company_button'),
                onPressed: () => context.go('/join'),
                icon: Icon(
                  Icons.apartment_outlined,
                  size: 20,
                  color: tokens.primary,
                ),
                label: Text(
                  'Join Your Company',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: tokens.textPrimary,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  backgroundColor: tokens.surface,
                  foregroundColor: tokens.textPrimary,
                  side: BorderSide(
                    color: tokens.borderStrong,
                    width: 1.2,
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
              style: TextStyle(color: tokens.textMuted, fontSize: 12),
            ),
          ],
        ),
      ],
    );

    return Scaffold(
      backgroundColor: tokens.canvas,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: isWide
                  ? Container(
                      padding: const EdgeInsets.all(36),
                      decoration: BoxDecoration(
                        color: tokens.surface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: tokens.border),
                        boxShadow: [
                          BoxShadow(
                            color: tokens.textPrimary.withValues(alpha: 0.04),
                            blurRadius: 24,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: content,
                    )
                  : content,
            ),
          ),
        ),
      ),
    );
  }
}
