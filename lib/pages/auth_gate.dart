import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/firm/providers.dart';
import '../screens/employee/pending_approval_screen.dart';
import 'admin_dashboard.dart';
import 'register_firm_page.dart';
import 'login_page.dart';
import 'home_page.dart';

/// AuthGate sits at the root of the widget tree and watches AuthProvider + Firm state.
///
/// Flow:
///   isInitializing (token validation + profile load) → splash
///   isAuthenticating (explicit login in progress)    → splash
///   Authenticated + no membership                    → RegisterFirmPage (first-time admin flow)
///   Authenticated + pending/revoked/rejected         → PendingApprovalScreen
///   Authenticated + approved/active + admin          → AdminDashboard
///   Authenticated + approved/active + employee       → HomePage (Chat conversation list)
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

    // Not authenticated — show login page
    if (!auth.isAuthenticated) {
      return const LoginPage();
    }

    // Authenticated — check if user has a valid UID
    final uid = auth.user?.uid;
    if (uid == null) {
      return const LoginPage();
    }

    // Watch the current user's membership stream
    final membershipAsync = ref.watch(myMembershipStreamProvider);

    return membershipAsync.when(
      loading: () => const Scaffold(
        backgroundColor: Color.fromRGBO(28, 27, 27, 1),
        body: Center(
          child: CircularProgressIndicator(
            color: Color.fromRGBO(41, 116, 188, 1),
          ),
        ),
      ),
      error: (err, stack) {
        debugPrint('Error loading membership: $err');
        return const LoginPage();
      },
      data: (doc) {
        if (doc == null || !doc.exists) {
          // No membership document — show firm registration (first-time admin flow)
          return const RegisterFirmPage();
        }

        final data = doc.data();
        if (data == null) {
          return const RegisterFirmPage();
        }

        final status = data['status'] as String? ?? 'pending';
        final role = data['role'] as String? ?? 'employee';
        final firmId = data['firmId'] as String? ?? '';

        // 1. If membership is pending, revoked, or rejected, show the PendingApprovalScreen
        if (status == 'pending' || status == 'revoked' || status == 'rejected') {
          return PendingApprovalScreen(firmId: firmId, uid: uid);
        }

        // 2. If approved/active, route based on role
        if (status == 'approved' || status == 'active') {
          // Preload the firm details reactively
          if (firmId.isNotEmpty) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              ref.read(firmNotifierProvider.notifier).loadFirm(firmId);
            });
          }

          if (role == 'admin' || role == 'super_admin') {
            return const AdminDashboard();
          } else {
            return const HomePage();
          }
        }

        // Fallback
        return const RegisterFirmPage();
      },
    );
  }
}

