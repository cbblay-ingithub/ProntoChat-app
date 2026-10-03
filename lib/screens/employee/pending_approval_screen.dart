import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class PendingApprovalScreen extends StatelessWidget {
  final String firmId;
  final String uid;

  const PendingApprovalScreen({
    super.key,
    required this.firmId,
    required this.uid,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Joining Your Firm'),
        centerTitle: true,
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('Memberships')
            .doc(uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error: ${snapshot.error}',
                style: const TextStyle(color: Colors.red),
              ),
            );
          }

          final data = snapshot.data?.data();
          if (data == null) {
            return const Center(
              child: Text('No membership record found.'),
            );
          }

          final status = data['status'] as String? ?? 'pending';

          if (status == 'approved' || status == 'active') {
            // Automatically navigate the user to the HomePage on success
            WidgetsBinding.instance.addPostFrameCallback((_) {
              context.go('/home');
            });
          }

          if (status == 'rejected') {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.cancel_outlined, size: 64, color: Colors.red),
                    const SizedBox(height: 16),
                    const Text(
                      'Access Request Rejected',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Your request to join this firm has been rejected by the administrator.',
                      style: TextStyle(color: Colors.grey[400]),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    OutlinedButton.icon(
                      onPressed: () async {
                        await FirebaseAuth.instance.signOut();
                        if (context.mounted) context.go('/login');
                      },
                      icon: const Icon(Icons.arrow_back, size: 16),
                      label: const Text('Back to Login'),
                    ),
                  ],
                ),
              ),
            );
          }

          if (status == 'revoked') {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.block, size: 64, color: Colors.red),
                    const SizedBox(height: 16),
                    const Text(
                      'Access Revoked',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Your access to this firm has been revoked by the administrator.',
                      style: TextStyle(color: Colors.grey[400]),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    OutlinedButton.icon(
                      onPressed: () async {
                        await FirebaseAuth.instance.signOut();
                        if (context.mounted) context.go('/login');
                      },
                      icon: const Icon(Icons.arrow_back, size: 16),
                      label: const Text('Back to Login'),
                    ),
                  ],
                ),
              ),
            );
          }

          // Default: pending
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(
                    width: 64,
                    height: 64,
                    child: CircularProgressIndicator(strokeWidth: 4),
                  ),
                  const SizedBox(height: 32),
                  const Text(
                    'Waiting for your Admin to approve your request...',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'We will automatically connect you once approved.',
                    style: TextStyle(color: Colors.grey[500], fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  TextButton.icon(
                    onPressed: () async {
                      await FirebaseAuth.instance.signOut();
                      if (context.mounted) context.go('/login');
                    },
                    icon: const Icon(Icons.arrow_back, size: 16),
                    label: const Text('Cancel & Back to Login'),
                    style: TextButton.styleFrom(foregroundColor: Colors.grey[400]),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
