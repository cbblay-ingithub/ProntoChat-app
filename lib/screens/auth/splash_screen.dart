import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import '../../providers/firm/providers.dart';

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
    // Watch membership stream reactively
    final membershipAsync = ref.watch(myMembershipStreamProvider);

    return Scaffold(
      backgroundColor: const Color.fromRGBO(24, 23, 23, 1),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: const Color.fromRGBO(41, 116, 188, 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color.fromRGBO(41, 116, 188, 0.35),
                  ),
                ),
                child: const Icon(
                  Icons.chat_bubble_outline_rounded,
                  size: 36,
                  color: Color.fromRGBO(41, 116, 188, 1),
                ),
              ),
              const SizedBox(height: 32),
              const SizedBox(
                width: 32,
                height: 32,
                child: CircularProgressIndicator(
                  color: Color.fromRGBO(41, 116, 188, 1),
                  strokeWidth: 3,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Connecting to workspace...',
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (_showTroubleshootOption) ...[
                const SizedBox(height: 32),
                Text(
                  'Connection is taking longer than expected.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey[500], fontSize: 13),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextButton.icon(
                      onPressed: () {
                        // Refresh router
                        GoRouter.of(context).refresh();
                      },
                      icon: const Icon(Icons.refresh, size: 16),
                      label: const Text('Retry'),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color.fromRGBO(41, 116, 188, 1),
                      ),
                    ),
                    const SizedBox(width: 12),
                    TextButton.icon(
                      onPressed: () async {
                        await FirebaseAuth.instance.signOut();
                        if (context.mounted) {
                          context.go(kIsWeb ? '/sign-in' : '/welcome');
                        }
                      },
                      icon: const Icon(Icons.logout, size: 16),
                      label: const Text('Back to Login'),
                      style: TextButton.styleFrom(foregroundColor: Colors.red[300]),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
