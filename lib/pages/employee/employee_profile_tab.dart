import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart' as provider;
import '../../models/firm.dart';
import '../../providers/auth_provider.dart';
import '../../services/chat_service.dart';
import '../../services/db_service.dart';
import '../../theme/pc_tokens.dart';
import '../../widgets/common/pc_avatar.dart';

class EmployeeProfileTab extends StatelessWidget {
  final String uid;
  final String userName;
  final String email;
  final Firm firm;
  final bool isWideLayout;

  const EmployeeProfileTab({
    super.key,
    required this.uid,
    required this.userName,
    required this.email,
    required this.firm,
    this.isWideLayout = false,
  });

  Future<void> _handleLogout(BuildContext context, PcTokens tokens) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: tokens.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Sign Out of This Device',
          style: TextStyle(
            color: tokens.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          'Are you sure you want to sign out of this device? This will clear your local session only and will not change your workspace membership or access status.',
          style: TextStyle(color: tokens.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: Text('Cancel', style: TextStyle(color: tokens.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: tokens.urgentText,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(dialogCtx, true),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      ChatService.instance.cancelAllSubscriptions();
      final auth = provider.Provider.of<AuthProvider>(context, listen: false);
      await auth.signOut();
      if (context.mounted) {
        context.go(kIsWeb ? '/sign-in' : '/welcome');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.pcTokens;
    final primaryColor = tokens.primary;

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: DBService.instance.streamMember(firm.firmId, uid),
      builder: (context, memberSnap) {
        final memberData = memberSnap.data?.data() ?? {};
        final role = memberData['role'] as String? ?? 'employee';
        final departmentId = memberData['departmentId'] as String?;

        String roleLabel = 'Employee';
        Color roleBadgeColor = primaryColor;
        Color roleBadgeSoft = tokens.primarySoft;
        String badgeText = 'ACTIVE MEMBER';

        if (role == 'lead') {
          roleLabel = 'Team Lead';
          roleBadgeColor = tokens.projectAccent;
          roleBadgeSoft = tokens.projectSoft;
          badgeText = 'TEAM LEAD';
        } else if (role == 'admin' || role == 'super_admin') {
          roleLabel = 'Firm Admin';
          roleBadgeColor = tokens.warningAccent;
          roleBadgeSoft = tokens.warningSoft;
          badgeText = 'FIRM ADMIN';
        }

        Widget body = SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: isWideLayout ? 28 : 20,
            vertical: 20,
          ),
          child: Column(
            children: [
              // Profile Hero Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: tokens.surface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: tokens.border),
                ),
                child: Column(
                  children: [
                    Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                          stream: FirebaseFirestore.instance
                              .collection('Users')
                              .doc(uid)
                              .snapshots(),
                          builder: (context, userSnap) {
                            final userData = userSnap.data?.data() ?? {};
                            final legacyImage = userData['image'] as String?;
                            MediaRef? avatarRef;
                            if (userData['avatar'] is Map) {
                              avatarRef = MediaRef.fromMap(
                                Map<String, dynamic>.from(
                                  userData['avatar'] as Map,
                                ),
                              );
                            }
                            return PcAvatar(
                              avatar: avatarRef,
                              legacyUrl: legacyImage,
                              name: userName,
                              radius: 44,
                              variant: MediaVariant.avatarLg,
                              backgroundColor: tokens.primarySoft,
                              foregroundColor: primaryColor,
                            );
                          },
                        ),
                        Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            color: tokens.surface,
                            shape: BoxShape.circle,
                          ),
                          child: CircleAvatar(
                            radius: 7,
                            backgroundColor: role == 'lead'
                                ? tokens.projectAccent
                                : tokens.online,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      userName,
                      style: TextStyle(
                        color: tokens.textPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      email.isNotEmpty ? email : 'employee@workspace.com',
                      style: TextStyle(
                        color: tokens.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: roleBadgeSoft,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        badgeText,
                        style: TextStyle(
                          color: roleBadgeColor,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Firm Organization Card
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: tokens.surface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: tokens.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.business_rounded, color: primaryColor, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Workspace & Firm Details',
                          style: TextStyle(
                            color: tokens.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Divider(height: 1, color: tokens.border),
                    ),
                    _buildProfileRow(tokens, 'Company Name', firm.name),
                    const SizedBox(height: 12),
                    _buildProfileRow(
                      tokens,
                      'Firm ID',
                      firm.firmId,
                      trailing: IconButton(
                        icon: Icon(
                          Icons.copy_rounded,
                          size: 16,
                          color: tokens.textMuted,
                        ),
                        tooltip: 'Copy Firm ID',
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: firm.firmId));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Firm ID copied to clipboard'),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildProfileRow(tokens, 'Role', roleLabel),
                    const SizedBox(height: 12),
                    if (departmentId != null && departmentId.isNotEmpty)
                      StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                        stream: FirebaseFirestore.instance
                            .collection('Firms')
                            .doc(firm.firmId)
                            .collection('departments')
                            .doc(departmentId)
                            .snapshots(),
                        builder: (ctx, dSnap) {
                          final dName = dSnap.data?.data()?['name'] as String? ??
                              'Loading...';
                          return _buildProfileRow(tokens, 'Department', dName);
                        },
                      )
                    else
                      _buildProfileRow(tokens, 'Department', 'None (Unassigned)'),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Security & Status Card
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: tokens.surface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: tokens.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.shield_outlined,
                          color: tokens.online,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Security & Privacy',
                          style: TextStyle(
                            color: tokens.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Divider(height: 1, color: tokens.border),
                    ),
                    _buildProfileRow(
                      tokens,
                      'Data Isolation',
                      'Firm Scoped (Multi-Tenant)',
                    ),
                    const SizedBox(height: 12),
                    _buildProfileRow(
                      tokens,
                      'Encryption',
                      'Enterprise AES-256 in transit & at rest',
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Sign Out Button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: tokens.urgentText,
                    side: BorderSide(color: tokens.urgentBorder, width: 1.4),
                    backgroundColor: tokens.urgentBg,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: const Icon(Icons.logout_rounded, size: 18),
                  label: const Text(
                    'Sign Out',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                  onPressed: () => _handleLogout(context, tokens),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        );

        if (isWideLayout) {
          body = Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 740),
              child: body,
            ),
          );
        }

        return Scaffold(
          backgroundColor: tokens.canvas,
          appBar: AppBar(
            backgroundColor: tokens.surface,
            elevation: 0,
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(1),
              child: Divider(height: 1, color: tokens.border),
            ),
            title: Text(
              'My Profile',
              style: TextStyle(
                color: tokens.textPrimary,
                fontSize: 19,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          body: body,
        );
      },
    );
  }

  Widget _buildProfileRow(
    PcTokens tokens,
    String label,
    String value, {
    Widget? trailing,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(color: tokens.textMuted, fontSize: 13),
        ),
        Flexible(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: tokens.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              ?trailing,
            ],
          ),
        ),
      ],
    );
  }
}
