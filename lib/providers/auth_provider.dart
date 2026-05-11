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
// CHANGES FROM PREVIOUS VERSION
//  1. Singleton removed — Provider package owns the single instance.
//     AuthProvider.instance conflicted with ChangeNotifierProvider: two
//     separate objects existed, so notifyListeners() on one never reached
//     the other's listeners and the UI never rebuilt.
//
//  2. registerUserWithEmailAndPassword now accepts name + imageURL and calls
//     DBService.createUserInDB immediately after the Auth account is created.
//     Previously, registration produced an Auth account with no matching
//     Firestore document, which silently broke every downstream feature
//     (search, conversations, avatars).
//
//  3. _userProfile (Map<String,dynamic>) is loaded from Firestore on every
//     auth state change and after every successful login/registration.
//     Convenience getters (currentUserName, currentUserImage) expose the data
//     so screens never need their own redundant Firestore reads.
//
//  4. DBService.updateLastSeen is called whenever a session is established,
//     keeping the lastSeen field current for future presence features.
// ---------------------------------------------------------------------------
class AuthProvider extends ChangeNotifier {
  // ── Firebase ───────────────────────────────────────────────────────────
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // ── State ──────────────────────────────────────────────────────────────
  User? user;
  AuthStatus status = AuthStatus.notAuthenticated;
  String? errorMessage;

  // Firestore profile for the signed-in user.
  // Populated after every successful auth; cleared on sign-out.
  Map<String, dynamic>? _userProfile;

  // ── Services ───────────────────────────────────────────────────────────
  final SnackbarService _snackbarService = SnackbarService();

  // ── Constructor ────────────────────────────────────────────────────────
  // Plain constructor — registered once via ChangeNotifierProvider in
  // main.dart. Do NOT add a static `instance` field here.
  AuthProvider() {
    _auth.authStateChanges().listen(_onAuthStateChanged);
  }

  // ── Auth-state listener ────────────────────────────────────────────────
  // Called automatically by Firebase when the session is established or
  // destroyed (app cold-start, sign-in, sign-out, token expiry).
  Future<void> _onAuthStateChanged(User? firebaseUser) async {
    if (firebaseUser != null) {
      user   = firebaseUser;
      status = AuthStatus.authenticated;
      errorMessage = null;

      // Load the Firestore profile so all screens can read name/image
      // from the provider without their own extra network calls.
      await _loadUserProfile(firebaseUser.uid);

      // Keep lastSeen current for presence / "last seen X minutes ago".
      await DBService.instance.updateLastSeen(firebaseUser.uid);

      debugPrint('[AuthProvider] session active: ${firebaseUser.email}');
    } else {
      user         = null;
      _userProfile = null;
      status       = AuthStatus.notAuthenticated;
      debugPrint('[AuthProvider] session ended');
    }
    notifyListeners();
  }

  // Fetches the Firestore user document and caches it in _userProfile.
  // Safe to call multiple times — simply overwrites the cache.
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
        // Profile + lastSeen are handled by _onAuthStateChanged, but we
        // load the profile here too so callers can read it synchronously
        // right after this method returns true.
        await _loadUserProfile(user!.uid);
        await DBService.instance.updateLastSeen(user!.uid);

        status = AuthStatus.authenticated;
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
  // Accepts name and imageURL so a Firestore document can be created
  // immediately. Pass an empty string or a default avatar URL for imageURL
  // if the registration screen doesn't have a photo picker yet.
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

      // Step 1: Create the Firebase Auth account.
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      user = credential.user;

      if (user != null) {
        // Step 2: Create the matching Firestore document.
        // This is the critical step that was missing before — without it
        // the user exists in Auth but not in the database, breaking search,
        // conversations, and every avatar/name lookup.
        await DBService.instance.createUserInDB(
          user!.uid,
          name,
          email.trim(),
          imageURL,
        );

        // Step 3: Cache the freshly created profile locally.
        await _loadUserProfile(user!.uid);
        await DBService.instance.updateLastSeen(user!.uid);

        status = AuthStatus.authenticated;
        errorMessage = null;
        _snackbarService.showSnackBarSuccess('Welcome, $name!');
        debugPrint('[AuthProvider] registered: ${user!.email}');
        notifyListeners();
        return true;
      }

      status = AuthStatus.error;
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
      // _onAuthStateChanged will fire and clear user + _userProfile.
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
  // Call this after the user updates their name or avatar so the provider
  // cache stays in sync without requiring a full sign-out/sign-in.
  Future<void> refreshUserProfile() async {
    if (user == null) return;
    await _loadUserProfile(user!.uid);
    notifyListeners();
  }

  // ── Getters ────────────────────────────────────────────────────────────
  String? get currentUserId    => user?.uid;
  String? get currentUserEmail => user?.email;

  // These read from the cached Firestore profile — no extra network call.
  String get currentUserName  => (_userProfile?['name']  as String?) ?? '';
  String get currentUserImage => (_userProfile?['image'] as String?) ?? '';

  // Full profile map — useful for createConversation() which needs both
  // fields at once. Returns an empty map rather than null so callers don't
  // need null checks.
  Map<String, dynamic> get currentUserProfile => _userProfile ?? {};

  bool get isAuthenticated  => status == AuthStatus.authenticated;
  bool get isAuthenticating => status == AuthStatus.authenticating;

  // ── Helpers ────────────────────────────────────────────────────────────
  void clearError() {
    errorMessage = null;
    notifyListeners();
  }

  // Centralised Firebase error handler used by login + registration.
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