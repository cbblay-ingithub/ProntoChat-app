import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart' as provider;
import '../../models/firm.dart';
import '../../providers/auth_provider.dart';

class EmployeeProfileTab extends StatelessWidget {
  final String uid;
  final String userName;
  final String email;
  final Firm firm;

  const EmployeeProfileTab({
    super.key,
    required this.uid,
    required this.userName,
    required this.email,
    required this.firm,
  });

  Future<void> _handleLogout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: const Color.fromRGBO(34, 33, 33, 1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Log Out', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Are you sure you want to sign out of your workspace?',
          style: TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, true),
            child: const Text('Log Out', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      final auth = provider.Provider.of<AuthProvider>(context, listen: false);
      await auth.signOut();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;

    return Scaffold(
      backgroundColor: const Color.fromRGBO(28, 27, 27, 1),
      appBar: AppBar(
        backgroundColor: const Color.fromRGBO(28, 27, 27, 1),
        elevation: 0,
        title: const Text(
          'My Profile',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          children: [
            const SizedBox(height: 10),

            // ── Avatar & Name ────────────────────────────────────────────────
            Center(
              child: Stack(
                alignment: Alignment.bottomRight,
                children: [
                  CircleAvatar(
                    radius: 46,
                    backgroundColor: primaryColor.withValues(alpha: 0.25),
                    child: Text(
                      userName.isNotEmpty ? userName[0].toUpperCase() : 'U',
                      style: TextStyle(
                        color: primaryColor,
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Color.fromRGBO(28, 27, 27, 1),
                      shape: BoxShape.circle,
                    ),
                    child: const CircleAvatar(
                      radius: 8,
                      backgroundColor: Colors.greenAccent,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Text(
              userName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              email.isNotEmpty ? email : 'employee@workspace.com',
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 10),

            // Member Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: primaryColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: primaryColor.withValues(alpha: 0.3)),
              ),
              child: Text(
                'ACTIVE MEMBER',
                style: TextStyle(
                  color: primaryColor,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ),

            const SizedBox(height: 28),

            // ── Firm Organization Card ───────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color.fromRGBO(34, 33, 33, 1),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.business, color: primaryColor, size: 20),
                      const SizedBox(width: 8),
                      const Text(
                        'Workspace & Firm Details',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24, color: Colors.white12),
                  _buildProfileRow('Company Name', firm.name),
                  const SizedBox(height: 12),
                  _buildProfileRow(
                    'Firm ID',
                    firm.firmId,
                    trailing: IconButton(
                      icon: const Icon(Icons.copy, size: 16, color: Colors.grey),
                      tooltip: 'Copy Firm ID',
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: firm.firmId));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Firm ID copied to clipboard')),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildProfileRow('Role', 'Team Member / Employee'),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ── Security & Status Card ───────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color.fromRGBO(34, 33, 33, 1),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.shield_outlined, color: Colors.greenAccent, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Security & Privacy',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24, color: Colors.white12),
                  _buildProfileRow('Data Isolation', 'Firm Scoped (Multi-Tenant)'),
                  const SizedBox(height: 12),
                  _buildProfileRow('Encryption', 'Enterprise AES-256 in transit & at rest'),
                ],
              ),
            ),

            const SizedBox(height: 28),

            // ── Sign Out Button ──────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.redAccent,
                  side: const BorderSide(color: Colors.redAccent, width: 1.2),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                icon: const Icon(Icons.logout, size: 18),
                label: const Text(
                  'Sign Out',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
                onPressed: () => _handleLogout(context),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileRow(String label, String value, {Widget? trailing}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(color: Colors.grey[400], fontSize: 13),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (trailing != null) trailing,
          ],
        ),
      ],
    );
  }
}
