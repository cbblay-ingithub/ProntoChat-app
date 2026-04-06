import 'package:flutter/material.dart';

class NavigationService {
  
  late GlobalKey<NavigatorState> navigatorKey;

  // Fixed: Singleton pattern with proper syntax
  static final NavigationService instance = NavigationService._internal();
  
  // Fixed: Private constructor
  NavigationService._internal() {
    navigatorKey = GlobalKey<NavigatorState>();
  }
  
  // Fixed: Added space between String and parameter name
  Future<dynamic> navigateToReplacement(String routeName) {
    return navigatorKey.currentState!.pushReplacementNamed(routeName);
  }
  
  // Fixed: Added space between String and parameter name
  Future<dynamic> navigateTo(String routeName) {
    return navigatorKey.currentState!.pushNamed(routeName);
  }
  
  // Fixed: Proper parameter type and name
  Future<dynamic> navigateToRoute(MaterialPageRoute route) {
    return navigatorKey.currentState!.push(route);
  }
  
}