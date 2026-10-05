import 'package:flutter/material.dart';
import '../auth/join_screen.dart';

/// Legacy EmployeeOnboardingScreen delegating to the unified JoinScreen.
class EmployeeOnboardingScreen extends StatelessWidget {
  final String firmId;

  const EmployeeOnboardingScreen({
    super.key,
    required this.firmId,
  });

  @override
  Widget build(BuildContext context) {
    return JoinScreen(initialFirmId: firmId);
  }
}
