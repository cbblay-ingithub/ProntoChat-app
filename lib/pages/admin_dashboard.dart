import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pronto_chat/models/firm.dart';
import 'package:pronto_chat/models/membership.dart';
import 'package:pronto_chat/models/user.dart';
import 'package:pronto_chat/providers/firm/providers.dart';
import 'package:pronto_chat/services/db_service.dart';
import 'package:pronto_chat/services/snackbar_service.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'home_page.dart';
import 'bulk_onboarding_view.dart';
import 'package:pronto_chat/services/cloud_storage.dart';
// ── PRONTOCHAT ADDITION ──
import 'package:share_plus/share_plus.dart';
// ─────────────────────────

/// Custom Painter for dashed border around CSV upload area
class DashedBorderPainter extends CustomPainter {
  DashedBorderPainter({required this.color, this.strokeWidth = 2, this.gap = 4});
  final Color color;
  final double strokeWidth;
  final double gap;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.width, size.height),
        const Radius.circular(8),
      ));

    final metrics = path.computeMetrics();
    if (metrics.isNotEmpty) {
      final metric = metrics.first;
      for (double i = 0; i < metric.length; i += gap * 2) {
        canvas.drawPath(metric.extractPath(i, i + gap), paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Provider to fetch the current admin's name.
final adminNameProvider = FutureProvider<String?>((ref) async {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) {
    return null;
  }
  final dbService = DBService.instance;
  final userData = await dbService.getUserData(uid);
  return userData?['name'] as String?;
});

/// Admin Dashboard screen.
class AdminDashboard extends ConsumerStatefulWidget {
  const AdminDashboard({super.key});

  @override
  ConsumerState<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends ConsumerState<AdminDashboard> {
  // Track loading state for individual action buttons (e.g. key: 'approve_uid', value: true)
  final Map<String, bool> _actionLoading = {};

  @override
  void initState() {
    super.initState();
    // Start loading firm immediately in initState to prevent a frame with empty state
    _loadFirmIfNecessary();
  }



  Future<void> _loadFirmIfNecessary() async {
    final currentFirm = ref.read(currentFirmProvider);
    if (currentFirm == null) {
      ref.read(firmNotifierProvider.notifier).setLoading(true);

      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        try {
          final memberships = await DBService.instance.getUserFirms(uid).first;
          if (memberships.isNotEmpty) {
            final firmId = memberships.first.firmId;
            if (mounted) {
              await ref.read(firmNotifierProvider.notifier).loadFirm(firmId);
            }
          } else {
            // Check if there is a firm where they are the adminId
            final firmsQuery = await FirebaseFirestore.instance
                .collection('Firms')
                .where('adminId', isEqualTo: uid)
                .limit(1)
                .get();

            if (firmsQuery.docs.isNotEmpty) {
              final firmId = firmsQuery.docs.first.id;
              if (mounted) {
                await ref.read(firmNotifierProvider.notifier).loadFirm(firmId);
              }
            } else {
              if (mounted) {
                ref.read(firmNotifierProvider.notifier).setLoading(false);
              }
            }
          }
        } catch (e) {
          debugPrint('Error auto-loading firm: $e');
          if (mounted) {
            ref.read(firmNotifierProvider.notifier).setLoading(false);
          }
        }
      } else {
        if (mounted) {
          ref.read(firmNotifierProvider.notifier).setLoading(false);
        }
      }
    }
  }

  /// Handle logout
  Future<void> _handleLogout() async {
    if (!mounted) return;
    final navigator = Navigator.of(context);

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Log Out'),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              try {
                await FirebaseAuth.instance.signOut();
                navigator.pushReplacementNamed('/login');
              } catch (e) {
                if (mounted) {
                  SnackbarService().showSnackbar(
                    'Error logging out: ${e.toString()}',
                    isError: true,
                  );
                }
              }
            },
            child: const Text('Log Out'),
          ),
        ],
      ),
    );
  }

  /// Convert hex color string to Color object
  Color _hexToColor(String hexString) {
    String colorString = hexString.toUpperCase().replaceAll('#', '');
    if (colorString.length == 6) {
      colorString = 'FF$colorString';
    }
    if (colorString.length == 8) {
      final value = int.tryParse(colorString, radix: 16);
      if (value != null) {
        return Color(value);
      }
    }
    return const Color(0xFF295CB4); // Fallback color
  }

  @override
  Widget build(BuildContext context) {
    final firmAsync = ref.watch(currentFirmProvider);
    final isLoading = ref.watch(isFirmLoadingProvider);
    final error = ref.watch(firmErrorProvider);

    final primaryColor = firmAsync != null
        ? _hexToColor(firmAsync.primaryColor)
        : const Color(0xFF295CB4);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        centerTitle: true,
        backgroundColor: primaryColor, // Theming: AppBar background = primaryColor
        actions: [
          IconButton(
            icon: const Icon(Icons.chat),
            tooltip: 'Go to Chats',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const HomePage()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: _handleLogout,
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : error != null
              ? _buildErrorState(context, error)
              : firmAsync == null
                  ? _buildNoFirmState(context)
                  : _buildDashboardContent(context, firmAsync),
    );
  }

  /// Build dashboard content when firm data is loaded
  Widget _buildDashboardContent(BuildContext context, Firm firm) {
    final primaryColor = _hexToColor(firm.primaryColor);

    final adminNameAsync = ref.watch(adminNameProvider);
    final adminName = adminNameAsync.when(
      data: (name) => name ?? 'Not available',
      loading: () => 'Loading...',
      error: (e, st) => 'Error',
    );
    final adminEmail = FirebaseAuth.instance.currentUser?.email ?? 'No email';

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;

        return SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.all(isMobile ? 16 : 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Header Card
                _buildHeaderCard(context, firm, adminName, adminEmail, primaryColor),
                const SizedBox(height: 16),

                // 2 & 3. Stats Bar and QR Code Card (Row on desktop, Column on mobile)
                if (isMobile) ...[
                  _buildStatsBar(context, firm.firmId, primaryColor),
                  const SizedBox(height: 16),
                  // ── PRONTOCHAT ADDITION ──
                  _buildQrCard(),
                  // ─────────────────────────
                ] else ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _buildStatsBar(context, firm.firmId, primaryColor)),
                      const SizedBox(width: 16),
                      // ── PRONTOCHAT ADDITION ──
                      Expanded(child: _buildQrCard()),
                      // ─────────────────────────
                    ],
                  ),
                ],
                const SizedBox(height: 16),

                // 4 & 5. Tabbed Staff Management (Pending Requests vs Active Staff)
                _buildStaffTabs(context, firm.firmId, primaryColor),
                const SizedBox(height: 16),

                // 6. CSV Bulk Upload Card
                BulkOnboardingView(firmId: firm.firmId, primaryColor: primaryColor),
                const SizedBox(height: 16),

                // 7. Danger Zone
                _buildDangerZone(context, firm),
              ],
            ),
          ),
        );
      },
    );
  }

  /// 1. Header Card builder
  Widget _buildHeaderCard(
    BuildContext context,
    Firm firm,
    String adminName,
    String adminEmail,
    Color primaryColor,
  ) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Circular logo or color swatch (48x48)
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: firm.logoUrl != null ? Colors.white : primaryColor,
                shape: BoxShape.circle,
                image: firm.logoUrl != null
                    ? DecorationImage(
                        image: NetworkImage(firm.logoUrl!),
                        fit: BoxFit.contain,
                      )
                    : null,
                boxShadow: [
                  BoxShadow(
                    color: primaryColor.withOpacity(0.3),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    firm.name,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Admin: $adminName ($adminEmail)',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[400],
                        ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Created: ${_formatDate(firm.createdAt)}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[500],
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 2. Stats Bar builder
  Widget _buildStatsBar(BuildContext context, String firmId, Color primaryColor) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('Firms')
          .doc(firmId)
          .collection('members')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Card(
            elevation: 2,
            child: SizedBox(
              height: 120,
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }
        if (snapshot.hasError) {
          return Card(
            elevation: 2,
            child: SizedBox(
              height: 120,
              child: Center(
                child: Text(
                  'Error loading stats: ${snapshot.error}',
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            ),
          );
        }

        final docs = snapshot.data?.docs ?? [];
        final total = docs.length;
        final pending = docs.where((doc) => doc['status'] == 'pending').length;
        final active = docs.where((doc) => doc['status'] == 'active').length;
        final revoked = docs.where((doc) => doc['status'] == 'revoked').length;

        return LayoutBuilder(
          builder: (context, constraints) {
            final isMobile = constraints.maxWidth < 600;
            if (isMobile) {
              return GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                childAspectRatio: 1.4,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                children: [
                  _buildStatTile(context, Icons.people, primaryColor, total, 'Total Staff'),
                  _buildStatTile(context, Icons.hourglass_empty, primaryColor, pending, 'Pending'),
                  _buildStatTile(context, Icons.check_circle_outline, primaryColor, active, 'Active'),
                  _buildStatTile(context, Icons.block, Colors.red[600]!, revoked, 'Revoked'),
                ],
              );
            }
            return Row(
              children: [
                Expanded(child: _buildStatTile(context, Icons.people, primaryColor, total, 'Total Staff')),
                const SizedBox(width: 8),
                Expanded(child: _buildStatTile(context, Icons.hourglass_empty, primaryColor, pending, 'Pending')),
                const SizedBox(width: 8),
                Expanded(child: _buildStatTile(context, Icons.check_circle_outline, primaryColor, active, 'Active')),
                const SizedBox(width: 8),
                Expanded(child: _buildStatTile(context, Icons.block, Colors.red[600]!, revoked, 'Revoked')),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildStatTile(
    BuildContext context,
    IconData icon,
    Color color,
    int count,
    String label,
  ) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 6),
            Text(
              '$count',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[400],
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // ── PRONTOCHAT ADDITION ──
  Widget _buildQrCard() {
    final firm = ref.watch(currentFirmProvider);
    if (firm == null) {
      return const Card(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Center(
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }

    final firmId = firm.firmId;
    final primaryColor = _hexToColor(firm.primaryColor);
    final inviteUri = 'https://officespace.chottu.link/?firmId=$firmId';

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              'Onboard Your Team',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            QrImageView(
              data: inviteUri,
              size: 200,
              errorCorrectionLevel: QrErrorCorrectLevel.M,
              eyeStyle: QrEyeStyle(
                eyeShape: QrEyeShape.square,
                color: primaryColor,
              ),
              dataModuleStyle: QrDataModuleStyle(
                dataModuleShape: QrDataModuleShape.square,
                color: primaryColor,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: inviteUri));
                      SnackbarService().showSnackbar('Invite link copied!');
                    },
                    icon: const Icon(Icons.copy, size: 18),
                    label: const Text('Copy Link'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: primaryColor,
                      side: BorderSide(color: primaryColor),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      await Share.share(inviteUri);
                    },
                    icon: const Icon(Icons.share, size: 18),
                    label: const Text('Share'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  // ─────────────────────────

  /// 3. Onboarding QR Code Card builder
  Widget _buildQrCodeCard(BuildContext context, Firm firm, Color primaryColor) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('Firms').doc(firm.firmId).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Card(
            elevation: 2,
            child: SizedBox(
              height: 350,
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        final data = snapshot.data?.data() ?? {};
        final inviteToken = data['inviteToken'] as String? ?? 'default';
        final inviteLink = 'https://prontochat.app/join?firmId=${firm.firmId}&token=$inviteToken';

        return Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  'Employee Onboarding QR Code',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 16),
                // QR image container
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(
                      color: Colors.grey[300]!,
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: QrImageView(
                    data: inviteLink,
                    version: QrVersions.auto,
                    size: 150.0,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Share this QR code or link with employees to join your firm',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey[400],
                      ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () {
                        SnackbarService().showSnackbar(
                          'Download QR code is not supported on this platform.',
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                      ),
                      icon: const Icon(Icons.download, size: 18),
                      label: const Text('Download'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () async {
                        await Clipboard.setData(ClipboardData(text: inviteLink));
                        SnackbarService().showSnackbar('Invite link copied to clipboard!');
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: primaryColor,
                        side: BorderSide(color: primaryColor),
                      ),
                      icon: const Icon(Icons.copy, size: 18),
                      label: const Text('Copy Link'),
                    ),
                    TextButton.icon(
                      onPressed: () => _confirmRegenerateToken(context, firm.firmId),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.red[600],
                      ),
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('Regenerate'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _confirmRegenerateToken(BuildContext context, String firmId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Regenerate Invite Link?'),
        content: const Text(
          'This will invalidate the existing QR code and link. Any users trying to join using the old link will fail.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red[600]),
            child: const Text('Regenerate'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final newToken = DateTime.now().millisecondsSinceEpoch.toString();
        await FirebaseFirestore.instance.collection('Firms').doc(firmId).update({
          'inviteToken': newToken,
        });
        SnackbarService().showSnackbar('Invite link regenerated successfully!');
      } catch (e) {
        SnackbarService().showSnackbar(
          'Error regenerating invite link: $e',
          isError: true,
        );
      }
    }
  }

  /// Unified Tabbed Staff Management (Pending Requests vs Active Staff)
  Widget _buildStaffTabs(BuildContext context, String firmId, Color primaryColor) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: DefaultTabController(
        length: 2,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TabBar(
              labelColor: primaryColor,
              unselectedLabelColor: Colors.grey[400],
              indicatorColor: primaryColor,
              tabs: const [
                Tab(
                  icon: Icon(Icons.hourglass_empty),
                  text: 'Pending Requests',
                ),
                Tab(
                  icon: Icon(Icons.people),
                  text: 'Active Staff',
                ),
              ],
            ),
            SizedBox(
              height: 400, // Sized container for independent list scrolling
              child: TabBarView(
                children: [
                  _buildPendingRequestsTab(context, firmId, primaryColor),
                  _buildActiveStaffTab(context, firmId, primaryColor),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Step 2: The "Pending Requests" View
  Widget _buildPendingRequestsTab(
    BuildContext context,
    String firmId,
    Color primaryColor,
  ) {
    return StreamBuilder<List<Membership>>(
      stream: DBService.instance.getMembershipsByStatus(firmId, 'pending'),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error loading pending requests: ${snapshot.error}',
              style: const TextStyle(color: Colors.red),
            ),
          );
        }

        final memberships = snapshot.data ?? [];
        if (memberships.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.hourglass_empty, size: 48, color: Colors.grey[600]),
                  const SizedBox(height: 8),
                  Text(
                    'No pending requests',
                    style: TextStyle(color: Colors.grey[500], fontSize: 14),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: memberships.length,
          separatorBuilder: (context, index) => const Divider(),
          itemBuilder: (context, index) {
            final m = memberships[index];
            final isApproving = _actionLoading['approve_${m.membershipId}'] == true;

            return FutureBuilder<AppUser?>(
              future: DBService.instance.getUserDetails(m.uid),
              builder: (context, userSnapshot) {
                if (userSnapshot.connectionState == ConnectionState.waiting) {
                  return const ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                    title: Text('Loading user details...'),
                  );
                }
                if (userSnapshot.hasError || !userSnapshot.hasData || userSnapshot.data == null) {
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const CircleAvatar(child: Icon(Icons.error_outline)),
                    title: Text('Unknown User (${m.uid})'),
                  );
                }

                final appUser = userSnapshot.data!;
                final name = appUser.name;
                final email = appUser.email;
                final avatarUrl = appUser.image ??
                    'https://api.dicebear.com/7.x/avataaars/png?seed=${Uri.encodeComponent(name)}';

                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundImage: NetworkImage(avatarUrl),
                  ),
                  title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(
                    email,
                    style: TextStyle(color: Colors.grey[400], fontSize: 12),
                  ),
                  trailing: ElevatedButton(
                    onPressed: isApproving
                        ? null
                        : () => _approveMembership(context, m.membershipId, name),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: isApproving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Approve'),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  /// Step 3: The "Active Staff" View
  Widget _buildActiveStaffTab(
    BuildContext context,
    String firmId,
    Color primaryColor,
  ) {
    return StreamBuilder<List<Membership>>(
      stream: DBService.instance.getMembershipsByStatus(firmId, 'approved'),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error loading active staff: ${snapshot.error}',
              style: const TextStyle(color: Colors.red),
            ),
          );
        }

        final memberships = snapshot.data ?? [];
        if (memberships.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.people_outline, size: 48, color: Colors.grey[600]),
                  const SizedBox(height: 8),
                  Text(
                    'No active staff members',
                    style: TextStyle(color: Colors.grey[500], fontSize: 14),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: memberships.length,
          separatorBuilder: (context, index) => const Divider(),
          itemBuilder: (context, index) {
            final m = memberships[index];
            final isRevoking = _actionLoading['revoke_${m.membershipId}'] == true;

            return FutureBuilder<AppUser?>(
              future: DBService.instance.getUserDetails(m.uid),
              builder: (context, userSnapshot) {
                if (userSnapshot.connectionState == ConnectionState.waiting) {
                  return const ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                    title: Text('Loading user details...'),
                  );
                }
                if (userSnapshot.hasError || !userSnapshot.hasData || userSnapshot.data == null) {
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const CircleAvatar(child: Icon(Icons.error_outline)),
                    title: Text('Unknown User (${m.uid})'),
                  );
                }

                final appUser = userSnapshot.data!;
                final name = appUser.name;
                final email = appUser.email;
                final avatarUrl = appUser.image ??
                    'https://api.dicebear.com/7.x/avataaars/png?seed=${Uri.encodeComponent(name)}';

                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundImage: NetworkImage(avatarUrl),
                  ),
                  title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(
                    email,
                    style: TextStyle(color: Colors.grey[400], fontSize: 12),
                  ),
                  trailing: ElevatedButton(
                    onPressed: isRevoking
                        ? null
                        : () => _revokeMembership(context, m.membershipId, name),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red[600],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: isRevoking
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Revoke Access'),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Future<void> _approveMembership(
    BuildContext context,
    String membershipId,
    String name,
  ) async {
    setState(() => _actionLoading['approve_$membershipId'] = true);
    try {
      await DBService.instance.updateMembershipStatus(membershipId, 'approved');
      SnackbarService().showSnackbar('$name approved successfully!');
    } catch (e) {
      SnackbarService().showSnackbar('Error approving member: $e', isError: true);
    } finally {
      if (mounted) {
        setState(() => _actionLoading['approve_$membershipId'] = false);
      }
    }
  }

  Future<void> _revokeMembership(
    BuildContext context,
    String membershipId,
    String name,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Revoke Access?'),
        content: Text(
          'Are you sure you want to revoke $name\'s access to the firm? They will not be able to log in.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red[600]),
            child: const Text('Revoke'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _actionLoading['revoke_$membershipId'] = true);
    try {
      await DBService.instance.updateMembershipStatus(membershipId, 'revoked');
      SnackbarService().showSnackbar('$name revoked access successfully.');
    } catch (e) {
      SnackbarService().showSnackbar('Error revoking member: $e', isError: true);
    } finally {
      if (mounted) {
        setState(() => _actionLoading['revoke_$membershipId'] = false);
      }
    }
  }



  /// 7. Brand Settings & Danger Zone builder (collapsible)
  Widget _buildDangerZone(BuildContext context, Firm firm) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        title: const Text(
          'Brand Settings & Danger Zone',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        leading: const Icon(Icons.settings, color: Colors.blue),
        childrenPadding: const EdgeInsets.all(16),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Company Logo',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    firm.logoUrl != null ? 'Change your brand logo' : 'No logo uploaded yet',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
              Row(
                children: [
                  if (firm.logoUrl != null) ...[
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[800]!),
                        borderRadius: BorderRadius.circular(8),
                        image: DecorationImage(
                          image: NetworkImage(firm.logoUrl!),
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  ElevatedButton(
                    onPressed: () => _updateBrandLogo(context, firm),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[800],
                      foregroundColor: Colors.white,
                    ),
                    child: Text(firm.logoUrl != null ? 'Change Logo' : 'Upload Logo'),
                  ),
                ],
              ),
            ],
          ),
          const Divider(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Brand Accent Color',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'Customize the look and feel of the platform',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
              ElevatedButton(
                onPressed: () => _updateBrandColor(context, firm),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _hexToColor(firm.primaryColor),
                  foregroundColor: Colors.white,
                ),
                child: const Text('Update Color'),
              ),
            ],
          ),
          const Divider(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Delete Firm',
                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
                  ),
                  Text(
                    'Permanently erase this firm and all memberships',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
              ElevatedButton(
                onPressed: () => _deleteFirm(context, firm),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red[600],
                  foregroundColor: Colors.white,
                ),
                child: const Text('Delete Firm'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _updateBrandLogo(BuildContext context, Firm firm) async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.image,
        withData: true,
      );

      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      if (file.bytes == null) {
        SnackbarService().showSnackbar('Could not read image file bytes.', isError: true);
        return;
      }

      SnackbarService().showSnackbar('Uploading company logo...');
      final ext = file.extension ?? 'png';
      final downloadUrl = await CloudStorageService.instance.uploadFirmLogo(firm.firmId, file.bytes!, ext);

      // Update Firestore
      await FirebaseFirestore.instance.collection('Firms').doc(firm.firmId).update({
        'logoUrl': downloadUrl,
      });

      // Reload state
      await ref.read(firmNotifierProvider.notifier).loadFirm(firm.firmId);
      SnackbarService().showSnackbar('Brand logo updated successfully!');
    } catch (e) {
      SnackbarService().showSnackbar('Error uploading logo: $e', isError: true);
    }
  }

  void _updateBrandColor(BuildContext context, Firm firm) {
    Color pickerColor = _hexToColor(firm.primaryColor);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Pick Brand Color'),
        content: SingleChildScrollView(
          child: ColorPicker(
            pickerColor: pickerColor,
            onColorChanged: (color) {
              pickerColor = color;
            },
            labelTypes: const [],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final hexString =
                  '#${pickerColor.value.toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';
              try {
                await FirebaseFirestore.instance.collection('Firms').doc(firm.firmId).update({
                  'primaryColor': hexString,
                });
                await ref.read(firmNotifierProvider.notifier).loadFirm(firm.firmId);
                SnackbarService().showSnackbar('Brand color updated successfully!');
              } catch (e) {
                SnackbarService().showSnackbar(
                  'Error updating brand color: $e',
                  isError: true,
                );
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteFirm(BuildContext context, Firm firm) async {
    final firstConfirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Firm?'),
        content: const Text(
          'Are you sure you want to delete this firm? All staff memberships and associated data will be permanently erased. This is an irreversible action.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red[600]),
            child: const Text('Confirm Delete'),
          ),
        ],
      ),
    );

    if (firstConfirm != true) return;

    final nameController = TextEditingController();
    final doubleConfirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Double Confirmation Required'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('To confirm deletion, please type the name of the firm:'),
            const SizedBox(height: 8),
            Text(
              firm.name,
              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Enter firm name',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (nameController.text.trim() == firm.name) {
                Navigator.pop(dialogContext, true);
              } else {
                SnackbarService().showSnackbar('Firm name does not match!', isError: true);
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red[600]),
            child: const Text('DELETE PERMANENTLY'),
          ),
        ],
      ),
    );

    if (doubleConfirm == true) {
      try {
        await FirebaseFirestore.instance.collection('Firms').doc(firm.firmId).delete();
        await FirebaseAuth.instance.signOut();
        if (mounted) {
          Navigator.of(context).pushReplacementNamed('/register');
        }
      } catch (e) {
        SnackbarService().showSnackbar('Error deleting firm: $e', isError: true);
      }
    }
  }

  /// Build state when no firm is loaded
  Widget _buildNoFirmState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.business, size: 64, color: Colors.grey[600]),
          const SizedBox(height: 16),
          Text('No Firm Found', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
            'Please register a firm first',
            style: TextStyle(color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  /// Build error state
  Widget _buildErrorState(BuildContext context, String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
          const SizedBox(height: 16),
          Text(
            'Error Loading Firm',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            error,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.red[600]),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => ref.invalidate(currentFirmProvider),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  /// Format date to readable string DD/MM/YYYY
  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();
    return '$day/$month/$year';
  }
}
