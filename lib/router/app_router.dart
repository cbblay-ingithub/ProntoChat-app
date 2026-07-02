import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../pages/auth_gate.dart';
import '../pages/login_page.dart';
import '../pages/registration_page.dart';
import '../pages/register_firm_page.dart';
import '../pages/home_page.dart';
import '../pages/admin_dashboard.dart';
import '../pages/search_page.dart';
import '../screens/employee/employee_onboarding_screen.dart';
import '../providers/deep_link_provider.dart';
import '../services/navigation_service.dart';

// ── PRONTOCHAT ADDITION ──
final goRouterProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    navigatorKey: NavigationService.instance.navigatorKey,
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const AuthGate(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginPage(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegistrationPage(),
      ),
      GoRoute(
        path: '/register-firm',
        builder: (context, state) => const RegisterFirmPage(),
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) => const HomePage(),
      ),
      GoRoute(
        path: '/admin-dashboard',
        builder: (context, state) => const AdminDashboard(),
      ),
      GoRoute(
        path: '/search',
        builder: (context, state) => const UserSearchPage(),
      ),
      GoRoute(
        path: '/employee-onboarding',
        builder: (context, state) {
          final firmId = state.uri.queryParameters['firmId'] ?? '';
          return EmployeeOnboardingScreen(firmId: firmId);
        },
      ),
    ],
  );

  ref.listen<AsyncValue<String>>(firmIdFromLinkProvider, (previous, next) {
    final firmId = next.value;
    if (firmId != null && firmId.isNotEmpty) {
      router.push('/employee-onboarding?firmId=$firmId');
    }
  });

  // Initialize NavigationService delegates to routing via GoRouter
  NavigationService.instance.onNavigateTo = (routeName) async {
    router.push(routeName);
  };
  NavigationService.instance.onNavigateToReplacement = (routeName) async {
    router.go(routeName);
  };

  return router;
});

// Top-level ProviderObserver to listen for deep link events
class AppRouteObserver extends ProviderObserver {
  @override
  void didUpdateProvider(
    ProviderBase<Object?> provider,
    Object? previousValue,
    Object? newValue,
    ProviderContainer container,
  ) {
    if (provider == firmIdFromLinkProvider) {
      final next = newValue as AsyncValue<String>;
      final firmId = next.value;
      if (firmId != null && firmId.isNotEmpty) {
        container.read(goRouterProvider).push('/employee-onboarding?firmId=$firmId');
      }
    }
  }
}
// ─────────────────────────
