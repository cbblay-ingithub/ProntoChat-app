import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/firm/providers.dart';
import '../services/db_service.dart';
import 'admin_dashboard.dart';
import 'register_firm_page.dart';

/// AuthGate sits at the root of the widget tree and watches AuthProvider + Firm state.
///
/// Flow:
///   isInitializing (token validation + profile load) → splash
///   isAuthenticating (explicit login in progress)    → splash
///   Authenticated + has firm                        → AdminDashboard
///   Authenticated + no firm                         → RegisterFirmPage (first-time)
///   NotAuthenticated / Error                        → LoginPage
class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = context.watch<AuthProvider>();

    // Check loading states
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

    // Not authenticated — show firm registration (entry point for new admins)
    // Returning admins can tap "Already have an account? Log In" inside this screen.
    if (!auth.isAuthenticated) {
      return const RegisterFirmPage();
    }

    // Authenticated — check if user has any firms
    final uid = auth.user?.uid;
    if (uid == null) {
      return const RegisterFirmPage();
    }

    // Load user's firms via Riverpod
    // For Phase 1, we assume the first firm is the admin's firm
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _getUserMemberships(uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Color.fromRGBO(28, 27, 27, 1),
            body: Center(
              child: CircularProgressIndicator(
                color: Color.fromRGBO(41, 116, 188, 1),
              ),
            ),
          );
        }

        if (snapshot.hasError) {
          debugPrint('Error loading user firms: ${snapshot.error}');
        }

        final memberships = snapshot.data ?? [];

        // Has firm membership(s) — show admin dashboard
        if (memberships.isNotEmpty) {
          // Load the firm for the dashboard
          WidgetsBinding.instance.addPostFrameCallback((_) {
            final firmId = memberships.first['firmId'] as String;
            ref.read(firmNotifierProvider.notifier).loadFirm(firmId);
          });
          return const AdminDashboard();
        }

        // No firm membership — show firm registration (first-time flow)
        return const RegisterFirmPage();
      },
    );
  }

  /// Helper to get user's memberships from Firestore
  Future<List<Map<String, dynamic>>> _getUserMemberships(String uid) async {
    try {
      final dbService = DBService.instance;
      final memberships = await dbService
          .getUserFirms(uid)
          .first; // Get first emission (current state)

      // Convert Firm objects back to maps with firmId
      return memberships
          .map((firm) => {'firmId': firm.firmId, 'name': firm.name})
          .toList();
    } catch (e) {
      debugPrint('Error getting user memberships: $e');
      return [];
    }
  }
}
