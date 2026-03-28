import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/snackbar_service.dart';

// Enum to track authentication status throughout the app
enum AuthStatus {
  NotAuthenticated,  // User is not logged in
  Authenticating,    // Currently processing login
  Authenticated,     // User is successfully logged in
  UserNotFound,      // Email not found in Firebase
  Error,             // Some error occurred during authentication
}

class AuthProvider extends ChangeNotifier {
  // Current authenticated user (null if not authenticated)
  User? user;
  
  // Current authentication status
  AuthStatus status = AuthStatus.NotAuthenticated;
  
  // Firebase Auth instance
  final FirebaseAuth _auth;
  
  // Error message for displaying to users
  String? errorMessage;
  
  // Snackbar service instance
  final SnackbarService _snackbarService = SnackbarService();

  // Singleton instance
  static final AuthProvider instance = AuthProvider._internal();

  // Private constructor
  AuthProvider._internal() : _auth = FirebaseAuth.instance {
    // Listen to auth state changes
    _auth.authStateChanges().listen(_onAuthStateChanged);
  }

  // Handle auth state changes from Firebase
  void _onAuthStateChanged(User? firebaseUser) {
    if (firebaseUser != null) {
      // User is signed in
      user = firebaseUser;
      status = AuthStatus.Authenticated;
      errorMessage = null;
      debugPrint('User authenticated: ${firebaseUser.email}');
    } else {
      // User is signed out
      user = null;
      status = AuthStatus.NotAuthenticated;
      debugPrint('User signed out');
    }
    notifyListeners();
  }

  /// Login user with email and password
  /// Returns true if login successful, false otherwise
  Future<bool> loginUserWithEmailAndPassword(String email, String password) async {
    try {
      // Set authenticating status
      status = AuthStatus.Authenticating;
      errorMessage = null;
      notifyListeners();
      
      debugPrint('Attempting login for: $email');
      
      // Attempt to sign in with Firebase
      UserCredential credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      
      // Get the user from credential
      user = credential.user;
      
      if (user != null) {
        // Login successful
        status = AuthStatus.Authenticated;
        errorMessage = null;
        // ✅ Success message with SnackbarService's success color (green)
        _snackbarService.showSnackBarSuccess("Welcome ${user!.email}!");
        notifyListeners();
        return true;
      } else {
        // User is null (shouldn't happen, but handle anyway)
        status = AuthStatus.Error;
        // ✅ Error message with SnackbarService's error color (red accent)
        _snackbarService.showSnackBarError("Authentication error. Please try again.");
        notifyListeners();
        return false;
      }
      
    } on FirebaseAuthException catch (e) {
      // Handle Firebase specific authentication errors
      status = AuthStatus.Error;
      
      // ✅ All error messages use SnackbarService's error styling
      switch (e.code) {
        case 'user-not-found':
          errorMessage = 'No user found with this email address.';
          _snackbarService.showSnackBarError(errorMessage!);
          status = AuthStatus.UserNotFound;
          break;
        case 'wrong-password':
          errorMessage = 'Incorrect password. Please try again.';
          _snackbarService.showSnackBarError(errorMessage!);
          break;
        case 'invalid-email':
          errorMessage = 'Invalid email format. Please enter a valid email.';
          _snackbarService.showSnackBarError(errorMessage!);
          break;
        case 'user-disabled':
          errorMessage = 'This account has been disabled. Please contact support.';
          _snackbarService.showSnackBarError(errorMessage!);
          break;
        case 'too-many-requests':
          errorMessage = 'Too many failed attempts. Please try again later.';
          _snackbarService.showSnackBarError(errorMessage!);
          break;
        default:
          errorMessage = 'Login failed: ${e.message}';
          _snackbarService.showSnackBarError(errorMessage!);
      }
      
      debugPrint('Login error: ${e.code} - ${e.message}');
      notifyListeners();
      return false;
      
    } catch (e) {
      // Handle any other unexpected errors
      status = AuthStatus.Error;
      errorMessage = 'An unexpected error occurred. Please try again.';
      // ✅ Generic error with SnackbarService's error styling
      _snackbarService.showSnackBarError(errorMessage!);
      debugPrint('Unexpected login error: $e');
      notifyListeners();
      return false;
    }
  }

  /// Register a new user with email and password
  Future<bool> registerUserWithEmailAndPassword(String email, String password) async {
    try {
      // Set authenticating status
      status = AuthStatus.Authenticating;
      errorMessage = null;
      notifyListeners();
      
      debugPrint('Attempting registration for: $email');
      
      // Attempt to create user with Firebase
      UserCredential credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      
      // Get the user from credential
      user = credential.user;
      
      if (user != null) {
        // Registration successful
        status = AuthStatus.Authenticated;
        errorMessage = null;
        // ✅ Success message with SnackbarService's success color
        _snackbarService.showSnackBarSuccess("Account created successfully! Welcome ${user!.email}!");
        debugPrint('Registration successful for: ${user!.email}');
        notifyListeners();
        return true;
      } else {
        status = AuthStatus.Error;
        errorMessage = 'Registration failed - user data not found';
        // ✅ Error message with SnackbarService's error styling
        _snackbarService.showSnackBarError(errorMessage!);
        notifyListeners();
        return false;
      }
      
    } on FirebaseAuthException catch (e) {
      // Handle Firebase specific registration errors
      status = AuthStatus.Error;
      
      // ✅ All registration errors use SnackbarService's error styling
      switch (e.code) {
        case 'email-already-in-use':
          errorMessage = 'An account already exists with this email address.';
          _snackbarService.showSnackBarError(errorMessage!);
          break;
        case 'invalid-email':
          errorMessage = 'Invalid email format. Please enter a valid email.';
          _snackbarService.showSnackBarError(errorMessage!);
          break;
        case 'weak-password':
          errorMessage = 'Password is too weak. Please use at least 6 characters.';
          _snackbarService.showSnackBarError(errorMessage!);
          break;
        case 'operation-not-allowed':
          errorMessage = 'Email/password accounts are not enabled.';
          _snackbarService.showSnackBarError(errorMessage!);
          break;
        default:
          errorMessage = 'Registration failed: ${e.message}';
          _snackbarService.showSnackBarError(errorMessage!);
      }
      
      debugPrint('Registration error: ${e.code} - ${e.message}');
      notifyListeners();
      return false;
      
    } catch (e) {
      // Handle any other unexpected errors
      status = AuthStatus.Error;
      errorMessage = 'An unexpected error occurred. Please try again.';
      // ✅ Generic error with SnackbarService's error styling
      _snackbarService.showSnackBarError(errorMessage!);
      debugPrint('Unexpected registration error: $e');
      notifyListeners();
      return false;
    }
  }

  /// Sign out the current user
  Future<void> signOut() async {
    try {
      await _auth.signOut();
      user = null;
      status = AuthStatus.NotAuthenticated;
      errorMessage = null;
      // ✅ Info message with SnackbarService's info color (blue)
      _snackbarService.showSnackBarInfo("Signed out successfully");
      debugPrint('User signed out successfully');
      notifyListeners();
    } catch (e) {
      debugPrint('Sign out error: $e');
      errorMessage = 'Failed to sign out. Please try again.';
      // ✅ Error message with SnackbarService's error styling
      _snackbarService.showSnackBarError(errorMessage!);
      notifyListeners();
    }
  }

  /// Send password reset email
  Future<bool> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
      // ✅ Success message with SnackbarService's success color
      _snackbarService.showSnackBarSuccess("Password reset email sent to $email");
      debugPrint('Password reset email sent to: $email');
      return true;
    } on FirebaseAuthException catch (e) {
      debugPrint('Password reset error: ${e.code} - ${e.message}');
      
      if (e.code == 'user-not-found') {
        errorMessage = 'No user found with this email address.';
      } else {
        errorMessage = 'Failed to send reset email. Please try again.';
      }
      
      // ✅ Error message with SnackbarService's error styling
      _snackbarService.showSnackBarError(errorMessage!);
      notifyListeners();
      return false;
    } catch (e) {
      debugPrint('Unexpected password reset error: $e');
      errorMessage = 'An unexpected error occurred. Please try again.';
      // ✅ Error message with SnackbarService's error styling
      _snackbarService.showSnackBarError(errorMessage!);
      notifyListeners();
      return false;
    }
  }

  /// Get current user ID (returns null if not authenticated)
  String? get currentUserId => user?.uid;
  
  /// Get current user email (returns null if not authenticated)
  String? get currentUserEmail => user?.email;
  
  /// Check if user is authenticated
  bool get isAuthenticated => status == AuthStatus.Authenticated;
  
  /// Check if authentication is in progress
  bool get isAuthenticating => status == AuthStatus.Authenticating;

  /// Clear error message
  void clearError() {
    errorMessage = null;
    notifyListeners();
  }
}