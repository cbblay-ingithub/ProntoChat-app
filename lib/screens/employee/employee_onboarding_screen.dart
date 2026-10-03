import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class EmployeeOnboardingScreen extends StatefulWidget {
  final String firmId;

  const EmployeeOnboardingScreen({
    super.key,
    required this.firmId,
  });

  @override
  State<EmployeeOnboardingScreen> createState() => _EmployeeOnboardingScreenState();
}

class _EmployeeOnboardingScreenState extends State<EmployeeOnboardingScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;

      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null && !currentUser.isAnonymous) {
        try {
          final doc = await FirebaseFirestore.instance
              .collection('Memberships')
              .doc(currentUser.uid)
              .get();

          if (mounted && doc.exists) {
            final data = doc.data();
            final memberFirmId = data?['firmId'] as String?;
            final status = data?['status'] as String?;

            if (memberFirmId == widget.firmId) {
              if (status == 'approved' || status == 'active') {
                context.go('/home');
                return;
              } else if (status == 'pending') {
                context.go('/pending-approval?firmId=${widget.firmId}&uid=${currentUser.uid}');
                return;
              }
            }
          }
        } catch (e) {
          debugPrint('Error checking membership in onboarding screen: $e');
        }
      }

      if (mounted) {
        context.go('/employee-profile?firmId=${widget.firmId}');
      }
    });
  }

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
              widget.firmId,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Redirecting you to profile setup…',
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
