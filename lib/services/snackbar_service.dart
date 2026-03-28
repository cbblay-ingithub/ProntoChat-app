import 'package:flutter/material.dart';

class SnackbarService {
  static final SnackbarService _instance = SnackbarService._internal();
  
  // Global key to access scaffold messenger from anywhere
  final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();
  
  // Factory constructor to return the same instance
  factory SnackbarService() {
    return _instance;
  }
  
  // Private constructor
  SnackbarService._internal();
  
  /// Show error snackbar
  void showSnackBarError(String message) {
    scaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 3),
        content: Text(
          message,
          style: const TextStyle(color: Colors.white, fontSize: 14),
        ),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }
  
  /// Show success snackbar
  void showSnackBarSuccess(String message) {
    scaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 3),
        content: Text(
          message,
          style: const TextStyle(color: Colors.white, fontSize: 14),
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }
  
  /// Show info snackbar
  void showSnackBarInfo(String message) {
    scaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 3),
        content: Text(
          message,
          style: const TextStyle(color: Colors.white, fontSize: 14),
        ),
        backgroundColor: Colors.blue,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }
}