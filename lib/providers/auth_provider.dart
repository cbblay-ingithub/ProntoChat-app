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
// FIX APPLIED:
//   Added `isInitializing` bool (starts true) that remains true until
//   _onAuthStateChanged completes its FULL async sequence (profile load +
//   lastSeen stamp). Previously, notifyListeners() was called after two
//   awaited Firestore calls whose errors were silently swallowed — meaning
//   HomePage could wake up and fire a Firestore stream before the auth token
//   was validated, causing permission-denied.
//
//   HomePage now guards on `auth.isInitializing` in addition to uid == null,
//   so the stream never starts until auth is fully settled.
// ---------------------------------------------------------------------------
class AuthProvider extends ChangeNotifier {
  // ── Firebase ───────────────────────────────────────────────────────────
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // ── State ──────────────────────────────────────────────────────────────
  User?       user;
  AuthStatus  status       = AuthStatus.notAuthenticated;
  String?     errorMessage;

  // FIX: true until _onAuthStateChanged fully resolves on first call.
  // Starts true so the UI waits before firing any Firestore queries.
  bool _isInitializing = true;

  // Firestore profile for the signed-in user.
  Map<String, dynamic>? _userProfile;

  // ── Services ───────────────────────────────────────────────────────────
  final SnackbarService _snackbarService = SnackbarService();

  // ── Constructor ────────────────────────────────────────────────────────
  AuthProvider() {
    _auth.authStateChanges().listen(_onAuthStateChanged);
  }

  // ── Auth-state listener ────────────────────────────────────────────────
  Future<void> _onAuthStateChanged(User? firebaseUser) async {
    _isInitializing = true;
    notifyListeners();

    if (firebaseUser != null) {
      // FIX: Validate the ID token FIRST before touching Firestore.
      //
      // authStateChanges() fires when a persisted session is restored on
      // cold-start, but the ID token may not yet be accepted by Firestore
      // (it needs a round-trip to Google's auth servers to validate).
      // Without this, _loadUserProfile and updateLastSeen fail silently,
      // _isInitializing drops to false, HomePage starts the stream, and
      // Firestore rejects it with permission-denied.
      //
      // getIdToken() returns the cached token if fresh, or fetches a new
      // one if expired. If the network is down and the token is expired,
      // it throws — we catch it and bail to the login page cleanly.
      try {
        await firebaseUser.getIdToken();
      } catch (e) {
        debugPrint('[AuthProvider] token validation failed: $e');
        user         = null;
        _userProfile = null;
        status       = AuthStatus.notAuthenticated;
        _isInitializing = false;
        notifyListeners();
        return;
      }

      user         = firebaseUser;
      status       = AuthStatus.authenticated;
      errorMessage = null;

      await _loadUserProfile(firebaseUser.uid);
      await DBService.instance.updateLastSeen(firebaseUser.uid);

      debugPrint('[AuthProvider] session active: ${firebaseUser.email}');
    } else {
      user         = null;
      _userProfile = null;
      status       = AuthStatus.notAuthenticated;
      debugPrint('[AuthProvider] session ended');
    }

    _isInitializing = false;
    notifyListeners();
  }

  // Fetches the Firestore user document and caches it in _userProfile.
  Future<void> _loadUserProfile(String uid) async {
    try {
      _userProfile = await DBService.instance.getUserData(uid);
    } catch (e) {
      debugPrint('[AuthProvider] profile load failed: $e');
      _userProfile = null;
    }
  }

  // ── Login ──────────────────────────────────────────────────────────────
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

      user = credential.user;

      if (user != null) {
        // _onAuthStateChanged handles profile + lastSeen + notifyListeners.
        // We load profile here too so callers can read it synchronously
        // right after this method returns true.
        await _loadUserProfile(user!.uid);
        await DBService.instance.updateLastSeen(user!.uid);

        status       = AuthStatus.authenticated;
        errorMessage = null;
        _snackbarService.showSnackBarSuccess('Welcome back, $currentUserName!');
        notifyListeners();
        return true;
      }

      status = AuthStatus.error;
      _snackbarService.showSnackBarError('Authentication error. Please try again.');
      notifyListeners();
      return false;

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

      user = credential.user;

      if (user != null) {
        await DBService.instance.createUserInDB(
          user!.uid,
          name,
          email.trim(),
          imageURL,
        );

        await _loadUserProfile(user!.uid);
        await DBService.instance.updateLastSeen(user!.uid);

        status       = AuthStatus.authenticated;
        errorMessage = null;
        _snackbarService.showSnackBarSuccess('Welcome, $name!');
        debugPrint('[AuthProvider] registered: ${user!.email}');
        notifyListeners();
        return true;
      }

      status       = AuthStatus.error;
      errorMessage = 'Registration failed — user record not found.';
      _snackbarService.showSnackBarError(errorMessage!);
      notifyListeners();
      return false;

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
    await _loadUserProfile(user!.uid);
    notifyListeners();
  }

  // ── Getters ────────────────────────────────────────────────────────────
  String? get currentUserId    => user?.uid;
  String? get currentUserEmail => user?.email;

  String get currentUserName  => (_userProfile?['name']  as String?) ?? '';
  String get currentUserImage => (_userProfile?['image'] as String?) ?? '';

  Map<String, dynamic> get currentUserProfile => _userProfile ?? {};

  bool get isAuthenticated  => status == AuthStatus.authenticated;
  bool get isAuthenticating => status == AuthStatus.authenticating;

  // FIX: Consumers (HomePage) check this before firing Firestore queries.
  bool get isInitializing => _isInitializing;

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
    status       = AuthStatus.error;
    errorMessage = 'An unexpected error occurred. Please try again.';
    _snackbarService.showSnackBarError(errorMessage!);
    debugPrint('[AuthProvider] unexpected $context error: $e');
    notifyListeners();
  }
}