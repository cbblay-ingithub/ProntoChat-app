import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/firm/providers.dart';
import '../screens/auth/sign_in_screen.dart';
import '../screens/auth/no_access_screen.dart';
import '../screens/auth/access_revoked_screen.dart';
import 'admin_dashboard.dart';
import 'home_page.dart';

/// Legacy AuthGate fallback. All primary routing is handled by GoRouter's redirect logic.
class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = context.watch<AuthProvider>();

    // Check loading states
    if (auth.isInitializing || auth.isAuthenticating) {
      return const Scaffold(
        backgroundColor: Color.fromRGBO(24, 23, 23, 1),
        body: Center(
          child: CircularProgressIndicator(
            color: Color.fromRGBO(41, 116, 188, 1),
          ),
        ),
      );
    }

    // Not authenticated
    if (!auth.isAuthenticated || auth.user == null) {
      return const SignInScreen();
    }

    final membershipAsync = ref.watch(myMembershipStreamProvider);

    return membershipAsync.when(
      loading: () => const Scaffold(
        backgroundColor: Color.fromRGBO(24, 23, 23, 1),
        body: Center(
          child: CircularProgressIndicator(
            color: Color.fromRGBO(41, 116, 188, 1),
          ),
        ),
      ),
      error: (err, stack) {
        debugPrint('Error loading membership: $err');
        return const NoAccessScreen();
      },
      data: (doc) {
        if (doc == null || !doc.exists) {
          return const NoAccessScreen();
        }

        final data = doc.data();
        if (data == null) {
          return const NoAccessScreen();
        }

        final status = (data['status'] as String? ?? 'active').toLowerCase();
        final role = (data['role'] as String? ?? 'employee').toLowerCase();
        final firmId = data['firmId'] as String? ?? '';

        if (status == 'revoked') {
          return const AccessRevokedScreen();
        }

        if (firmId.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ref.read(firmNotifierProvider.notifier).loadFirm(firmId);
          });
        }

        if (kIsWeb && (role == 'admin' || role == 'super_admin')) {
          return const AdminDashboard();
        } else {
          return const HomePage();
        }
      },
    );
  }
}
