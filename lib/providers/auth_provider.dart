import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/db_service.dart';
import '../services/snackbar_service.dart';

// ---------------------------------------------------------------------------
// AuthStatus
// ---------------------------------------------------------------------------
enum AuthStatus {
  notAuthenticated,  // No user session
  authenticating,    // Async op in-flight
  authenticated,     // Session active + Firestore profile loaded
  userNotFound,      // Firebase: 'user-not-found'
  error,             // Any other failure
}

// ---------------------------------------------------------------------------
// AuthProvider
// ---------------------------------------------------------------------------
// FIXES APPLIED (based on review):
//   1. Removed duplicate profile loading from loginUserWithEmailAndPassword.
//      _onAuthStateChanged is now the single source of truth for auth state.
//   2. Added a Completer (_initializationCompleter) so callers (like login)
//      can await the full initialization sequence (token validation + profile
//      load + lastSeen update) before proceeding.
//   3. Forced a fresh token refresh right after sign-in to ensure Firestore
//      permissions are ready.
//   4. loginUserWithEmailAndPassword now returns true only after the complete
//      initialization is finished, preventing race conditions where AuthGate
//      sees isInitializing = true and stays on loading spinner.
//   5. Improved error handling: token validation failure or profile load
//      failure will correctly set status = notAuthenticated and complete the
//      completer with an error (caller can handle).
// ---------------------------------------------------------------------------
class AuthProvider extends ChangeNotifier {
  // ── Firebase ───────────────────────────────────────────────────────────
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // ── State ──────────────────────────────────────────────────────────────
  User?       user;
  AuthStatus  status       = AuthStatus.notAuthenticated;
  String?     errorMessage;

  // true until _onAuthStateChanged fully resolves on first call or after
  // any auth state change. UI uses this to block Firestore queries.
  bool _isInitializing = true;

  // Firestore profile for the signed-in user.
  Map<String, dynamic>? _userProfile;

  // Completer that resolves when the current initialization sequence finishes.
  // Used by login/register to wait for the complete setup.
  Completer<void>? _initializationCompleter;

  // ── Services ───────────────────────────────────────────────────────────
  final SnackbarService _snackbarService = SnackbarService();

  // ── Constructor ────────────────────────────────────────────────────────
  AuthProvider() {
    _auth.authStateChanges().listen(_onAuthStateChanged);
  }

  // ── Auth-state listener (SINGLE SOURCE OF TRUTH) ───────────────────────
  Future<void> _onAuthStateChanged(User? firebaseUser) async {
    // Cancel any previous pending completer (e.g., if a new auth event
    // arrives before the previous one finished).
    _initializationCompleter?.completeError(
      'New auth event interrupted previous initialization',
    );
    _initializationCompleter = Completer<void>();
    _isInitializing = true;
    notifyListeners();

    try {
      if (firebaseUser != null) {
        // 1. Validate/refresh ID token – essential for Firestore permissions
        await firebaseUser.getIdToken(true); // force refresh

        user = firebaseUser;
        status = AuthStatus.authenticated;
        errorMessage = null;

        // 2. Load Firestore profile
        await _loadUserProfile(firebaseUser.uid);

        // 3. Update last seen timestamp
        await DBService.instance.updateLastSeen(firebaseUser.uid);

        debugPrint('[AuthProvider] session active: ${firebaseUser.email}');
      } else {
        // Signed out or no user
        user = null;
        _userProfile = null;
        status = AuthStatus.notAuthenticated;
        debugPrint('[AuthProvider] session ended');
      }
    } catch (e) {
      debugPrint('[AuthProvider] initialization error: $e');
      user = null;
      _userProfile = null;
      status = AuthStatus.notAuthenticated;
      errorMessage = 'Authentication initialization failed.';
      // Complete the completer with an error so waiting callers know.
      if (!_initializationCompleter!.isCompleted) {
        _initializationCompleter!.completeError(e);
      }
    } finally {
      _isInitializing = false;
      if (_initializationCompleter != null &&
          !_initializationCompleter!.isCompleted) {
        _initializationCompleter!.complete();
      }
      notifyListeners();
    }
  }

  // Fetches the Firestore user document and caches it in _userProfile.
  Future<void> _loadUserProfile(String uid) async {
    try {
      _userProfile = await DBService.instance.getUserData(uid);
      if (_userProfile == null) {
        debugPrint('[AuthProvider] User profile not found for uid: $uid');
      }
    } catch (e) {
      debugPrint('[AuthProvider] profile load failed: $e');
      _userProfile = null;
      rethrow; // Propagate so caller knows profile couldn't be loaded.
    }
  }

  // ── Login (now waits for full initialization) ─────────────────────────
  Future<bool> loginUserWithEmailAndPassword(
    String email,
    String password,
  ) async {
    try {
      status = AuthStatus.authenticating;
      errorMessage = null;
      notifyListeners();

      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final firebaseUser = credential.user;
      if (firebaseUser == null) {
        throw Exception('Sign-in succeeded but user object is null');
      }

      // Force a fresh token right away (defensive – _onAuthStateChanged also
      // does this, but we do it early to catch token issues immediately).
      await firebaseUser.getIdToken(true);

      // Wait for _onAuthStateChanged to complete its full initialization
      // (profile load, lastSeen, etc.). This ensures that when we return
      // true, the provider is completely ready and AuthGate will show HomePage.
      if (_initializationCompleter != null) {
        await _initializationCompleter!.future;
      }

      // At this point, user is fully initialized.
      _snackbarService.showSnackBarSuccess('Welcome back, $currentUserName!');
      return true;
    } on FirebaseAuthException catch (e) {
      _handleFirebaseAuthError(e);
      return false;
    } catch (e) {
      _handleUnexpectedError('login', e);
      return false;
    }
  }

  // ── Registration ───────────────────────────────────────────────────────
  Future<bool> registerUserWithEmailAndPassword({
    required String email,
    required String password,
    required String name,
    String imageURL = '',
  }) async {
    try {
      status = AuthStatus.authenticating;
      errorMessage = null;
      notifyListeners();

      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final firebaseUser = credential.user;
      if (firebaseUser == null) {
        throw Exception('Registration succeeded but user object is null');
      }

      // Create Firestore user document before loading profile
      await DBService.instance.createUserInDB(
        firebaseUser.uid,
        name,
        email.trim(),
        imageURL,
      );

      // Force token refresh
      await firebaseUser.getIdToken(true);

      // Wait for _onAuthStateChanged to finish (it will load the profile we
      // just created and update lastSeen).
      if (_initializationCompleter != null) {
        await _initializationCompleter!.future;
      }

      _snackbarService.showSnackBarSuccess('Welcome, $name!');
      debugPrint('[AuthProvider] registered: ${firebaseUser.email}');
      return true;
    } on FirebaseAuthException catch (e) {
      _handleFirebaseAuthError(e);
      return false;
    } catch (e) {
      _handleUnexpectedError('registration', e);
      return false;
    }
  }

  // ── Sign out ───────────────────────────────────────────────────────────
  Future<void> signOut() async {
    try {
      await _auth.signOut();
      _snackbarService.showSnackBarInfo('Signed out successfully');
      debugPrint('[AuthProvider] signed out');
    } catch (e) {
      debugPrint('[AuthProvider] sign-out error: $e');
      errorMessage = 'Failed to sign out. Please try again.';
      _snackbarService.showSnackBarError(errorMessage!);
      notifyListeners();
    }
  }

  // ── Password reset ─────────────────────────────────────────────────────
  Future<bool> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
      _snackbarService.showSnackBarSuccess('Password reset email sent to $email');
      debugPrint('[AuthProvider] reset email sent: $email');
      return true;
    } on FirebaseAuthException catch (e) {
      debugPrint('[AuthProvider] reset error: ${e.code}');
      errorMessage = e.code == 'user-not-found'
          ? 'No account found with that email address.'
          : 'Failed to send reset email. Please try again.';
      _snackbarService.showSnackBarError(errorMessage!);
      notifyListeners();
      return false;
    } catch (e) {
      _handleUnexpectedError('password reset', e);
      return false;
    }
  }

  // ── Profile refresh ────────────────────────────────────────────────────
  Future<void> refreshUserProfile() async {
    if (user == null) return;
    try {
      await _loadUserProfile(user!.uid);
      notifyListeners();
    } catch (e) {
      debugPrint('[AuthProvider] profile refresh failed: $e');
    }
  }

  // ── Getters ────────────────────────────────────────────────────────────
  String? get currentUserId    => user?.uid;
  String? get currentUserEmail => user?.email;

  String get currentUserName  => (_userProfile?['name']  as String?) ?? '';
  String get currentUserImage => (_userProfile?['image'] as String?) ?? '';

  Map<String, dynamic> get currentUserProfile => _userProfile ?? {};

  bool get isAuthenticated  => status == AuthStatus.authenticated;
  bool get isAuthenticating => status == AuthStatus.authenticating;
  bool get isInitializing   => _isInitializing;

  // Expose the completer's future for callers who need to wait for
  // initialization (used in login/register). For external consumers like
  // HomePage, they can simply check isInitializing.
  Future<void> get initializationComplete =>
      _initializationCompleter?.future ?? Future.value();

  // ── Helpers ────────────────────────────────────────────────────────────
  void clearError() {
    errorMessage = null;
    notifyListeners();
  }

  void _handleFirebaseAuthError(FirebaseAuthException e) {
    status = AuthStatus.error;

    switch (e.code) {
      case 'user-not-found':
        errorMessage = 'No account found with that email address.';
        status = AuthStatus.userNotFound;
        break;
      case 'wrong-password':
      case 'invalid-credential':
        errorMessage = 'Incorrect password. Please try again.';
        break;
      case 'invalid-email':
        errorMessage = 'Invalid email format.';
        break;
      case 'user-disabled':
        errorMessage = 'This account has been disabled. Please contact support.';
        break;
      case 'too-many-requests':
        errorMessage = 'Too many attempts. Please try again later.';
        break;
      case 'email-already-in-use':
        errorMessage = 'An account already exists with this email.';
        break;
      case 'weak-password':
        errorMessage = 'Password is too weak — use at least 6 characters.';
        break;
      case 'operation-not-allowed':
        errorMessage = 'Email/password sign-in is not enabled.';
        break;
      default:
        errorMessage = e.message ?? 'Authentication failed.';
    }

    _snackbarService.showSnackBarError(errorMessage!);
    debugPrint('[AuthProvider] Firebase error: ${e.code} — ${e.message}');
    notifyListeners();
  }

  void _handleUnexpectedError(String context, Object e) {
    status = AuthStatus.error;
    errorMessage = 'An unexpected error occurred. Please try again.';
    _snackbarService.showSnackBarError(errorMessage!);
    debugPrint('[AuthProvider] unexpected $context error: $e');
    notifyListeners();
  }
}