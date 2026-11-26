import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import '../../providers/firm/providers.dart';
import '../../theme/pc_tokens.dart';

/// Loading splash screen while session and membership state are resolving.
/// Includes proactive timeout handling so users are never trapped on a permanent spinner.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  Timer? _timeoutTimer;
  bool _showTroubleshootOption = false;

  @override
  void initState() {
    super.initState();

    // Safety timeout: If routing has not transitioned within 5 seconds, reveal fallback actions
    _timeoutTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) {
        setState(() {
          _showTroubleshootOption = true;
        });
      }
    });

    // Check if user is not signed in right away
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (FirebaseAuth.instance.currentUser == null && mounted) {
        context.go(kIsWeb ? '/sign-in' : '/welcome');
      }
    });
  }

  @override
  void dispose() {
    _timeoutTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Watch membership stream reactively so router guards receive updates
    ref.watch(myMembershipStreamProvider);
    final tokens = context.pcTokens;

    return Scaffold(
      backgroundColor: tokens.canvas,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: tokens.primarySoft,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: tokens.primaryBorder),
                  ),
                  child: Icon(
                    Icons.chat_bubble_outline_rounded,
                    size: 36,
                    color: tokens.primary,
                  ),
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: 30,
                  height: 30,
                  child: CircularProgressIndicator(
                    color: tokens.primary,
                    strokeWidth: 2.8,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Connecting to workspace...',
                  style: TextStyle(
                    color: tokens.textSecondary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (_showTroubleshootOption) ...[
                  const SizedBox(height: 28),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: tokens.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: tokens.border),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'Connection is taking longer than expected.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: tokens.textMuted,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 12,
                          runSpacing: 8,
                          alignment: WrapAlignment.center,
                          children: [
                            TextButton.icon(
                              onPressed: () {
                                GoRouter.of(context).refresh();
                              },
                              icon: const Icon(Icons.refresh, size: 16),
                              label: const Text('Retry'),
                              style: TextButton.styleFrom(
                                foregroundColor: tokens.primary,
                              ),
                            ),
                            TextButton.icon(
                              onPressed: () async {
                                await FirebaseAuth.instance.signOut();
                                if (context.mounted) {
                                  context.go(kIsWeb ? '/sign-in' : '/welcome');
                                }
                              },
                              icon: const Icon(Icons.logout, size: 16),
                              label: const Text('Back to Login'),
                              style: TextButton.styleFrom(
                                foregroundColor: tokens.urgentText,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
