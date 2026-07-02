import 'package:flutter/material.dart';

class NavigationService {
  
  late GlobalKey<NavigatorState> navigatorKey;

  // ── PRONTOCHAT ADDITION ──
  Future<dynamic> Function(String)? onNavigateTo;
  Future<dynamic> Function(String)? onNavigateToReplacement;
  // ─────────────────────────

  // Fixed: Singleton pattern with proper syntax
  static final NavigationService instance = NavigationService._internal();
  
  // Fixed: Private constructor
  NavigationService._internal() {
    navigatorKey = GlobalKey<NavigatorState>();
  }
  
  // Fixed: Added space between String and parameter name
  Future<dynamic> navigateToReplacement(String routeName) {
    // ── PRONTOCHAT ADDITION ──
    if (onNavigateToReplacement != null) {
      return onNavigateToReplacement!(routeName);
    }
    // ─────────────────────────
    return navigatorKey.currentState!.pushReplacementNamed(routeName);
  }
  
  // Fixed: Added space between String and parameter name
  Future<dynamic> navigateTo(String routeName) {
    // ── PRONTOCHAT ADDITION ──
    if (onNavigateTo != null) {
      return onNavigateTo!(routeName);
    }
    // ─────────────────────────
    return navigatorKey.currentState!.pushNamed(routeName);
  }
  
  // Fixed: Proper parameter type and name
  Future<dynamic> navigateToRoute(MaterialPageRoute route) {
    return navigatorKey.currentState!.push(route);
  }
  
}