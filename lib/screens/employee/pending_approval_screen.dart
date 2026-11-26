import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../theme/pc_tokens.dart';

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
    final tokens = context.pcTokens;

    return Scaffold(
      backgroundColor: tokens.canvas,
      appBar: AppBar(
        title: const Text('Joining Your Firm'),
        centerTitle: true,
        backgroundColor: tokens.surface,
        shape: Border(bottom: BorderSide(color: tokens.border)),
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('Memberships')
            .doc(uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: CircularProgressIndicator(color: tokens.primary),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error: ${snapshot.error}',
                style: TextStyle(color: tokens.urgentText),
              ),
            );
          }

          final data = snapshot.data?.data();
          if (data == null) {
            return Center(
              child: Text(
                'No membership record found.',
                style: TextStyle(color: tokens.textSecondary),
              ),
            );
          }

          final status = data['status'] as String? ?? 'pending';

          if (status == 'approved' || status == 'active') {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (context.mounted) {
                context.go('/home');
              }
            });
          }

          if (status == 'rejected') {
            return _buildStatusCard(
              context: context,
              tokens: tokens,
              icon: Icons.cancel_outlined,
              iconColor: tokens.urgentText,
              iconBg: tokens.urgentBg,
              iconBorder: tokens.urgentBorder,
              title: 'Access Request Rejected',
              message:
                  'Your request to join this firm has been rejected by the administrator.',
            );
          }

          if (status == 'revoked') {
            return _buildStatusCard(
              context: context,
              tokens: tokens,
              icon: Icons.block,
              iconColor: tokens.urgentText,
              iconBg: tokens.urgentBg,
              iconBorder: tokens.urgentBorder,
              title: 'Access Revoked',
              message:
                  'Your access to this firm has been revoked by the administrator.',
            );
          }

          // Default: pending
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: tokens.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: tokens.border),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 56,
                        height: 56,
                        child: CircularProgressIndicator(
                          strokeWidth: 3.5,
                          color: tokens.primary,
                        ),
                      ),
                      const SizedBox(height: 28),
                      Text(
                        'Waiting for your Admin to approve your request...',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: tokens.textPrimary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'We will automatically connect you once approved.',
                        style: TextStyle(
                          color: tokens.textSecondary,
                          fontSize: 13,
                        ),
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
                        style: TextButton.styleFrom(
                          foregroundColor: tokens.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatusCard({
    required BuildContext context,
    required PcTokens tokens,
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required Color iconBorder,
    required String title,
    required String message,
  }) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: tokens.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: tokens.border),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 68,
                  height: 68,
                  decoration: BoxDecoration(
                    color: iconBg,
                    shape: BoxShape.circle,
                    border: Border.all(color: iconBorder),
                  ),
                  child: Icon(icon, size: 36, color: iconColor),
                ),
                const SizedBox(height: 18),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                    color: tokens.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  message,
                  style: TextStyle(color: tokens.textSecondary, fontSize: 13.5),
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
        ),
      ),
    );
  }
}
