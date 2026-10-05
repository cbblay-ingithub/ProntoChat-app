import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../providers/firm/providers.dart';
import '../providers/deep_link_provider.dart';
import '../services/navigation_service.dart';

// Screens
import '../screens/auth/splash_screen.dart';
import '../screens/auth/welcome_screen.dart';
import '../screens/auth/sign_in_screen.dart';
import '../screens/auth/join_screen.dart';
import '../screens/auth/access_revoked_screen.dart';
import '../screens/auth/firm_suspended_screen.dart';
import '../screens/auth/select_firm_screen.dart';
import '../screens/auth/no_access_screen.dart';
import '../pages/register_firm_page.dart';
import '../pages/home_page.dart';
import '../pages/admin_dashboard.dart';
import '../pages/search_page.dart';
import '../screens/employee/firm_chat_screen.dart';
import '../screens/employee/pending_approval_screen.dart';

/// Reactive notifier that informs GoRouter whenever auth state or membership state changes.
class RouterNotifier extends ChangeNotifier {
  final Ref _ref;
  StreamSubscription<User?>? _authSub;

  RouterNotifier(this._ref) {
    // 1. Listen to Firebase Auth changes (login, logout, token refresh)
    _authSub = FirebaseAuth.instance.authStateChanges().listen((_) {
      notifyListeners();
    });

    // 2. Listen to membership changes in Riverpod
    _ref.listen<AsyncValue<DocumentSnapshot<Map<String, dynamic>>?>>(
      myMembershipStreamProvider,
      (previous, next) {
        notifyListeners();
      },
    );
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }
}

final routerNotifierProvider = Provider<RouterNotifier>((ref) {
  final notifier = RouterNotifier(ref);
  ref.onDispose(() => notifier.dispose());
  return notifier;
});

/// Centralized Router configuration for ProntoChat.
/// Implements unified redirect state machine across Mobile and Web.
final goRouterProvider = Provider<GoRouter>((ref) {
  final routerNotifier = ref.watch(routerNotifierProvider);

  final router = GoRouter(
    navigatorKey: NavigationService.instance.navigatorKey,
    initialLocation: '/splash',
    refreshListenable: routerNotifier,
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/welcome',
        builder: (context, state) => const WelcomeScreen(),
      ),
      GoRoute(
        path: '/sign-in',
        builder: (context, state) => const SignInScreen(),
      ),
      GoRoute(
        path: '/login',
        redirect: (context, state) => '/sign-in',
      ),
      GoRoute(
        path: '/join',
        builder: (context, state) {
          final firmId = state.uri.queryParameters['firmId'];
          final code = state.uri.queryParameters['code'];
          return JoinScreen(initialFirmId: firmId, initialCode: code);
        },
      ),
      GoRoute(
        path: '/employee-onboarding',
        redirect: (context, state) {
          final firmId = state.uri.queryParameters['firmId'] ?? '';
          return '/join?firmId=$firmId';
        },
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
        path: '/access-revoked',
        builder: (context, state) => const AccessRevokedScreen(),
      ),
      GoRoute(
        path: '/firm-suspended',
        builder: (context, state) => const FirmSuspendedScreen(),
      ),
      GoRoute(
        path: '/select-firm',
        builder: (context, state) => const SelectFirmScreen(),
      ),
      GoRoute(
        path: '/no-access',
        builder: (context, state) => const NoAccessScreen(),
      ),
      GoRoute(
        path: '/pending-approval',
        builder: (context, state) {
          final firmId = state.uri.queryParameters['firmId'] ?? '';
          final uid = state.uri.queryParameters['uid'] ?? '';
          return PendingApprovalScreen(firmId: firmId, uid: uid);
        },
      ),
      GoRoute(
        path: '/search',
        builder: (context, state) => const UserSearchPage(),
      ),
      GoRoute(
        path: '/firm-chat',
        builder: (context, state) {
          final firmId = state.uri.queryParameters['firmId'] ?? '';
          final uid = state.uri.queryParameters['uid'] ?? '';
          final name = state.uri.queryParameters['name'] ?? '';
          return FirmChatScreen(
            firmId: firmId,
            uid: uid,
            name: name,
          );
        },
      ),
    ],

    // ── Single Centralized Redirect State Machine ───────────────────────────
    redirect: (BuildContext context, GoRouterState state) {
      final authUser = FirebaseAuth.instance.currentUser;
      final path = state.uri.path;

      // 1. SIGNED-OUT STATE
      if (authUser == null) {
        if (kIsWeb) {
          if (path == '/sign-in' || path == '/register-firm') {
            return null;
          }
          return '/sign-in';
        } else {
          // Mobile only allows: /welcome, /sign-in, /join
          if (path == '/welcome' || path == '/sign-in' || path == '/join') {
            return null;
          }
          return '/welcome';
        }
      }

      // 2. SIGNED-IN STATE
      // Resolve membership
      final membershipAsync = ref.read(myMembershipStreamProvider);
      final membershipDoc = membershipAsync.value;

      // If membership stream is still loading on initial launch, stay on splash
      if (membershipDoc == null && membershipAsync.isLoading) {
        return path == '/splash' ? null : '/splash';
      }

      // No membership found
      if (membershipDoc == null || !membershipDoc.exists) {
        if (kIsWeb && path == '/register-firm') {
          return null; // Allow admin in wizard to complete firm creation
        }
        if (path == '/join') {
          return null; // Allow onboarding with code
        }
        return path == '/no-access' ? null : '/no-access';
      }

      final data = membershipDoc.data() ?? {};
      final status = (data['status'] as String? ?? 'active').toLowerCase();
      final role = (data['role'] as String? ?? 'employee').toLowerCase();
      final firmId = data['firmId'] as String? ?? '';

      // Check if access was revoked
      if (status == 'revoked') {
        return path == '/access-revoked' ? null : '/access-revoked';
      }

      // Check if pending approval
      if (status == 'pending') {
        return path == '/pending-approval'
            ? null
            : '/pending-approval?firmId=$firmId&uid=${authUser.uid}';
      }

      // Preload firm details reactively if needed
      if (firmId.isNotEmpty) {
        final currentFirm = ref.read(currentFirmProvider);
        if (currentFirm == null || currentFirm.firmId != firmId) {
          Future.microtask(() {
            ref.read(firmNotifierProvider.notifier).loadFirm(firmId);
          });
        }

        // Check if firm is suspended
        if (currentFirm != null && currentFirm.isSuspended) {
          return path == '/firm-suspended' ? null : '/firm-suspended';
        }
      }

      // User has active membership:
      final isAuthScreen = path == '/welcome' ||
          path == '/sign-in' ||
          path == '/login' ||
          path == '/splash' ||
          path == '/no-access' ||
          path == '/pending-approval';

      if (isAuthScreen) {
        if (kIsWeb && (role == 'admin' || role == 'super_admin')) {
          return '/admin-dashboard';
        }
        return '/home';
      }

      // Guard /admin-dashboard on mobile (mobile is strictly for employees)
      if (!kIsWeb && path == '/admin-dashboard') {
        return '/home';
      }

      // Guard /register-firm on mobile
      if (!kIsWeb && path == '/register-firm') {
        return '/home';
      }

      return null;
    },
  );

  // Deep Link listener for QR scans or universal links
  ref.listen<AsyncValue<String>>(firmIdFromLinkProvider, (previous, next) {
    final firmId = next.value;
    if (firmId != null && firmId.isNotEmpty) {
      router.push('/join?firmId=$firmId');
    }
  });

  // NavigationService delegates
  NavigationService.instance.onNavigateTo = (routeName) async {
    router.push(routeName);
  };
  NavigationService.instance.onNavigateToReplacement = (routeName) async {
    router.go(routeName);
  };

  return router;
});

/// Observer for deep-link updates
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
        container.read(goRouterProvider).push('/join?firmId=$firmId');
      }
    }
  }
}
