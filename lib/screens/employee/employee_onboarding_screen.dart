import 'package:flutter/material.dart';

class EmployeeOnboardingScreen extends StatelessWidget {
  final String firmId;

  const EmployeeOnboardingScreen({
    super.key,
    required this.firmId,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Joining Your Firm'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              color: primaryColor,
            ),
            const SizedBox(height: 24),
            const Text(
              'Connecting to Firm ID:',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              firmId,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Please wait while we set up your account…',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// TODO Phase 3: Trigger Firebase Anonymous Auth here
// TODO Phase 3: Create pending membership in Firestore
// TODO Phase 3: Navigate to PendingApprovalScreen on success
