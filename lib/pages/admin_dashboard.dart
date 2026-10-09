import 'dart:async';
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
import 'package:pronto_chat/models/department.dart';
import 'package:pronto_chat/models/project_group.dart';
import 'package:pronto_chat/providers/firm/providers.dart';
import 'package:pronto_chat/services/db_service.dart';
import 'package:pronto_chat/services/snackbar_service.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'home_page.dart';
import 'bulk_onboarding_view.dart';
import 'package:pronto_chat/services/cloud_storage.dart';
import 'dart:math';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:go_router/go_router.dart';
import 'package:pronto_chat/services/chat_service.dart';
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
  // Selected member UIDs for bulk operations on active staff
  final Set<String> _selectedActiveMemberIds = {};

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
                ChatService.instance.cancelAllSubscriptions();
                await FirebaseAuth.instance.signOut();
                if (mounted) {
                  context.go('/sign-in');
                }
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

                // Seat Meter Card (Trial Tier Caps)
                _buildSeatMeterCard(context, firm, primaryColor),
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

                // Departments & Department Chats Oversight Card
                _buildDepartmentsCard(context, firm.firmId, primaryColor),
                const SizedBox(height: 16),

                // Project Groups Metadata Oversight Card
                _buildProjectGroupsCard(context, firm.firmId, primaryColor),
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
                        onError: (exception, stackTrace) {
                          debugPrint('Notice: Firm logo could not be loaded: $exception');
                        },
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
        final pending = docs.where((doc) => (doc.data() as Map<String, dynamic>?)?['status'] == 'pending').length;
        final active = docs.where((doc) => (doc.data() as Map<String, dynamic>?)?['status'] == 'active').length;
        final revoked = docs.where((doc) => (doc.data() as Map<String, dynamic>?)?['status'] == 'revoked').length;

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
            const SizedBox(height: 12),
            QrImageView(
              data: inviteUri,
              size: 180,
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
            const SizedBox(height: 14),
            // Firm ID manual entry banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: primaryColor.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: primaryColor.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.vpn_key_outlined, color: primaryColor, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'FIRM ID (MANUAL JOIN CODE)',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[400],
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(height: 2),
                        SelectableText(
                          firmId,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy, size: 18),
                    color: primaryColor,
                    tooltip: 'Copy Firm ID',
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: firmId));
                      SnackbarService().showSnackbar('Firm ID copied to clipboard!');
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Employees can scan this QR code, tap the invite link, or enter this Firm ID in ProntoChat.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey[400]),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: firmId));
                    SnackbarService().showSnackbar('Firm ID copied to clipboard!');
                  },
                  icon: const Icon(Icons.tag, size: 16),
                  label: const Text('Copy Firm ID'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: primaryColor,
                    side: BorderSide(color: primaryColor),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: inviteUri));
                    SnackbarService().showSnackbar('Invite link copied!');
                  },
                  icon: const Icon(Icons.copy, size: 16),
                  label: const Text('Copy Link'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: primaryColor,
                    side: BorderSide(color: primaryColor),
                  ),
                ),
                if (!kIsWeb)
                  ElevatedButton.icon(
                    onPressed: () async {
                      await Share.share(
                        'Join our workspace on ProntoChat!\n\n'
                        'Option 1 (Link): $inviteUri\n'
                        'Option 2 (Manual): Open ProntoChat and enter Firm ID: $firmId',
                      );
                    },
                    icon: const Icon(Icons.share, size: 16),
                    label: const Text('Share'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
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

  /// Real-time Seat Meter Card against trial limits
  Widget _buildSeatMeterCard(BuildContext context, Firm firm, Color primaryColor) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('Firms').doc(firm.firmId).snapshots(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data() ?? {};
        final int seatCount = (data['seatCount'] as num?)?.toInt() ?? firm.seatCount;
        final int seatLimit = (data['seatLimit'] as num?)?.toInt() ?? firm.seatLimit;
        final double usagePercent = (seatCount / seatLimit).clamp(0.0, 1.0);
        final bool isLimitReached = seatCount >= seatLimit;

        return Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.workspace_premium_outlined, color: primaryColor, size: 22),
                        const SizedBox(width: 8),
                        Text(
                          'Trial Plan Seat Usage',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: isLimitReached ? Colors.red.withOpacity(0.2) : Colors.blue.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: isLimitReached ? Colors.redAccent : Colors.blueAccent),
                      ),
                      child: Text(
                        '$seatCount / $seatLimit Seats Used',
                        style: TextStyle(
                          color: isLimitReached ? Colors.redAccent : Colors.lightBlueAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: usagePercent,
                    minHeight: 10,
                    backgroundColor: Colors.grey[800],
                    valueColor: AlwaysStoppedAnimation<Color>(
                      isLimitReached ? Colors.redAccent : primaryColor,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  isLimitReached
                      ? '⚠️ Trial seat limit of $seatLimit reached. Remove unjoined invitations or upgrade plan to add more staff.'
                      : 'You have ${seatLimit - seatCount} available seat(s) remaining under the trial tier cap.',
                  style: TextStyle(
                    fontSize: 12,
                    color: isLimitReached ? Colors.redAccent : Colors.grey[400],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Unified Tabbed Staff Management (Pre-Authorized Staff, Active Staff, Revoked Staff, Pending)
  Widget _buildStaffTabs(BuildContext context, String firmId, Color primaryColor) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: DefaultTabController(
        length: 4,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TabBar(
              labelColor: primaryColor,
              unselectedLabelColor: Colors.grey[400],
              indicatorColor: primaryColor,
              tabs: const [
                Tab(
                  icon: Icon(Icons.assignment_ind_outlined),
                  text: 'Pre-Authorized',
                ),
                Tab(
                  icon: Icon(Icons.people),
                  text: 'Active',
                ),
                Tab(
                  icon: Icon(Icons.block),
                  text: 'Revoked',
                ),
                Tab(
                  icon: Icon(Icons.hourglass_empty),
                  text: 'Pending',
                ),
              ],
            ),
            SizedBox(
              height: 440,
              child: TabBarView(
                children: [
                  _buildPreAuthorizedStaffTab(context, firmId, primaryColor),
                  _buildActiveStaffTab(context, firmId, primaryColor),
                  _buildRevokedStaffTab(context, firmId, primaryColor),
                  _buildPendingRequestsTab(context, firmId, primaryColor),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// The "Pre-Authorized Staff" View
  Widget _buildPreAuthorizedStaffTab(
    BuildContext context,
    String firmId,
    Color primaryColor,
  ) {
    final firm = ref.watch(currentFirmProvider);
    final seatCount = firm?.seatCount ?? 1;
    final seatLimit = firm?.seatLimit ?? 5;
    final isLimitReached = seatCount >= seatLimit;

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: DBService.instance.streamPreApprovedStaff(firmId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final staffList = snapshot.data ?? [];

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Pre-Authorized Staff (${staffList.length})',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  ElevatedButton.icon(
                    onPressed: isLimitReached
                        ? () {
                            SnackbarService().showSnackbar(
                              'Trial seat limit reached ($seatLimit seats max). Upgrade required to add more.',
                              isError: true,
                            );
                          }
                        : () => _showAddPreApprovedStaffDialog(context, firmId),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add Staff Code'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isLimitReached ? Colors.grey[700] : primaryColor,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: staffList.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.assignment_ind_outlined, size: 48, color: Colors.grey[600]),
                          const SizedBox(height: 8),
                          Text('No pre-authorized staff yet.', style: TextStyle(color: Colors.grey[400])),
                          const SizedBox(height: 4),
                          Text('Add employees to generate one-time join codes.', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: staffList.length,
                      separatorBuilder: (_, __) => const Divider(),
                      itemBuilder: (context, index) {
                        final staff = staffList[index];
                        return _PreApprovedStaffTile(
                          key: ValueKey(staff['id'] ?? index),
                          staff: staff,
                          firmId: firmId,
                          primaryColor: primaryColor,
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  void _showAddPreApprovedStaffDialog(BuildContext context, String firmId) {
    final emailController = TextEditingController();
    final nameController = TextEditingController();
    MembershipRole selectedRole = MembershipRole.employee;
    String? selectedDeptId;

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color.fromRGBO(34, 33, 33, 1),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Add Pre-Authorized Staff', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Pre-authorizing an employee reserves 1 seat. A 5-minute staff code will be auto-generated and active as soon as you save.',
                  style: TextStyle(color: Colors.grey, fontSize: 13),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: nameController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Employee Name',
                    labelStyle: const TextStyle(color: Colors.grey),
                    filled: true,
                    fillColor: const Color.fromRGBO(24, 23, 23, 1),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: emailController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Employee Email',
                    labelStyle: const TextStyle(color: Colors.grey),
                    hintText: 'name@company.com',
                    hintStyle: TextStyle(color: Colors.grey[600]),
                    filled: true,
                    fillColor: const Color.fromRGBO(24, 23, 23, 1),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 12),
                // Role Dropdown
                DropdownButtonFormField<MembershipRole>(
                  value: selectedRole,
                  dropdownColor: const Color.fromRGBO(34, 33, 33, 1),
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Initial Role',
                    labelStyle: const TextStyle(color: Colors.grey),
                    filled: true,
                    fillColor: const Color.fromRGBO(24, 23, 23, 1),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: MembershipRole.employee,
                      child: Text('Employee (Standard)', style: TextStyle(color: Colors.white)),
                    ),
                    DropdownMenuItem(
                      value: MembershipRole.lead,
                      child: Text('Lead (Can manage project groups)', style: TextStyle(color: Colors.purpleAccent)),
                    ),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setDialogState(() => selectedRole = val);
                    }
                  },
                ),
                const SizedBox(height: 12),
                // Department Dropdown
                StreamBuilder<List<Department>>(
                  stream: DBService.instance.streamDepartments(firmId),
                  builder: (context, deptSnapshot) {
                    final departments = deptSnapshot.data?.where((d) => d.isActive).toList() ?? [];
                    return DropdownButtonFormField<String?>(
                      value: selectedDeptId,
                      dropdownColor: const Color.fromRGBO(34, 33, 33, 1),
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Department (Optional)',
                        labelStyle: const TextStyle(color: Colors.grey),
                        filled: true,
                        fillColor: const Color.fromRGBO(24, 23, 23, 1),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('None (Unassigned)', style: TextStyle(color: Colors.grey)),
                        ),
                        ...departments.map(
                          (d) => DropdownMenuItem<String?>(
                            value: d.deptId,
                            child: Text(d.name, style: const TextStyle(color: Colors.white)),
                          ),
                        ),
                      ],
                      onChanged: (val) {
                        setDialogState(() => selectedDeptId = val);
                      },
                    );
                  },
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color.fromRGBO(41, 116, 188, 0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color.fromRGBO(41, 116, 188, 0.3)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.autorenew, color: Color.fromRGBO(41, 116, 188, 1), size: 22),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Auto-Generated Staff Code', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                            SizedBox(height: 2),
                            Text(
                              'A 6-character code will be automatically issued. It will reset every 5 minutes until the employee onboards, and can also be manually reset at any time.',
                              style: TextStyle(fontSize: 11, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('Cancel', style: TextStyle(color: Colors.grey))),
            ElevatedButton(
              onPressed: () async {
                final email = emailController.text.trim();
                final name = nameController.text.trim();
                if (email.isEmpty || !email.contains('@')) {
                  SnackbarService().showSnackbar('Please enter a valid email address.', isError: true);
                  return;
                }
                Navigator.pop(dialogCtx);
                try {
                  final issuedCode = await DBService.instance.addPreApprovedStaff(
                    firmId: firmId,
                    email: email,
                    name: name.isEmpty ? email : name,
                    role: selectedRole,
                    departmentId: selectedDeptId,
                  );
                  SnackbarService().showSnackbar('Added $email! Code: $issuedCode (valid for 5 mins)');
                } catch (e) {
                  SnackbarService().showSnackbar('Error: ${e.toString().replaceAll('Exception:', '')}', isError: true);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color.fromRGBO(41, 116, 188, 1),
                foregroundColor: Colors.white,
              ),
              child: const Text('Save & Issue Code'),
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
            final isRejecting = _actionLoading['reject_${m.membershipId}'] == true;

            return FutureBuilder<AppUser?>(
              future: DBService.instance.getUserDetails(m.uid),
              builder: (context, userSnapshot) {
                final appUser = userSnapshot.data;
                final name = (appUser != null && appUser.name.isNotEmpty)
                    ? appUser.name
                    : 'Employee (${m.uid.substring(0, m.uid.length > 6 ? 6 : m.uid.length)})';
                final email = (appUser != null && appUser.email.isNotEmpty)
                    ? appUser.email
                    : 'UID: ${m.uid}';
                final avatarUrl = appUser?.image ??
                    'https://api.dicebear.com/7.x/avataaars/png?seed=${Uri.encodeComponent(name)}';

                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundImage: NetworkImage(avatarUrl),
                    onBackgroundImageError: (_, __) {},
                  ),
                  title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(
                    email,
                    style: TextStyle(color: Colors.grey[400], fontSize: 12),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      OutlinedButton(
                        onPressed: (isApproving || isRejecting)
                            ? null
                            : () => _rejectMembership(context, m.membershipId, name),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red[400],
                          side: BorderSide(color: Colors.red[400]!),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: isRejecting
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.red,
                                ),
                              )
                            : const Text('Reject'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: (isApproving || isRejecting)
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
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  /// Step 3: The "Active Staff" View (with Department & Role management, and Bulk Actions)
  Widget _buildActiveStaffTab(
    BuildContext context,
    String firmId,
    Color primaryColor,
  ) {
    return StreamBuilder<List<Department>>(
      stream: DBService.instance.streamDepartments(firmId),
      builder: (context, deptSnapshot) {
        final departments = deptSnapshot.data ?? [];
        final Map<String, String> deptMap = {
          for (final d in departments) d.deptId: d.name,
        };

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

            final currentUid = FirebaseAuth.instance.currentUser?.uid;

            return Column(
              children: [
                if (_selectedActiveMemberIds.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    color: primaryColor.withOpacity(0.12),
                    child: Row(
                      children: [
                        Text(
                          '${_selectedActiveMemberIds.length} staff selected',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        const Spacer(),
                        TextButton.icon(
                          icon: const Icon(Icons.corporate_fare, size: 16),
                          label: const Text('Assign Dept'),
                          onPressed: () => _showBulkAssignDeptDialog(
                            context,
                            firmId,
                            _selectedActiveMemberIds.toList(),
                            departments,
                          ),
                        ),
                        const SizedBox(width: 8),
                        TextButton.icon(
                          icon: const Icon(Icons.shield_outlined, size: 16),
                          label: const Text('Set Role'),
                          onPressed: () => _showBulkSetRoleDialog(
                            context,
                            firmId,
                            _selectedActiveMemberIds.toList(),
                          ),
                        ),
                        const SizedBox(width: 4),
                        IconButton(
                          icon: const Icon(Icons.close, size: 18),
                          tooltip: 'Clear selection',
                          onPressed: () => setState(() => _selectedActiveMemberIds.clear()),
                        ),
                      ],
                    ),
                  ),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: memberships.length,
                    separatorBuilder: (context, index) => const Divider(),
                    itemBuilder: (context, index) {
                      final m = memberships[index];
                      final isRevoking = _actionLoading['revoke_${m.membershipId}'] == true;
                      final isSelfAdmin = (currentUid != null && m.uid == currentUid) || m.role.name == 'admin';
                      final isSelected = _selectedActiveMemberIds.contains(m.uid);
                      final deptName = m.departmentId != null ? deptMap[m.departmentId] : null;

                      return FutureBuilder<AppUser?>(
                        future: DBService.instance.getUserDetails(m.uid),
                        builder: (context, userSnapshot) {
                          final appUser = userSnapshot.data;
                          final name = (appUser != null && appUser.name.isNotEmpty)
                              ? appUser.name
                              : 'Staff Member (${m.uid.substring(0, m.uid.length > 6 ? 6 : m.uid.length)})';
                          final email = (appUser != null && appUser.email.isNotEmpty)
                              ? appUser.email
                              : 'UID: ${m.uid}';
                          final avatarUrl = appUser?.image ??
                              'https://api.dicebear.com/7.x/avataaars/png?seed=${Uri.encodeComponent(name)}';

                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (!isSelfAdmin)
                                  Checkbox(
                                    value: isSelected,
                                    activeColor: primaryColor,
                                    onChanged: (checked) {
                                      setState(() {
                                        if (checked == true) {
                                          _selectedActiveMemberIds.add(m.uid);
                                        } else {
                                          _selectedActiveMemberIds.remove(m.uid);
                                        }
                                      });
                                    },
                                  )
                                else
                                  const SizedBox(width: 24),
                                CircleAvatar(
                                  backgroundImage: NetworkImage(avatarUrl),
                                  onBackgroundImageError: (_, __) {},
                                ),
                              ],
                            ),
                            title: Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    name,
                                    style: const TextStyle(fontWeight: FontWeight.w600),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                // Role Badge
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: isSelfAdmin
                                        ? Colors.blue.withOpacity(0.2)
                                        : (m.isLead
                                            ? Colors.purple.withOpacity(0.2)
                                            : Colors.grey.withOpacity(0.2)),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                      color: isSelfAdmin
                                          ? Colors.blueAccent
                                          : (m.isLead ? Colors.purpleAccent : Colors.grey[700]!),
                                      width: 0.5,
                                    ),
                                  ),
                                  child: Text(
                                    isSelfAdmin
                                        ? 'ADMIN'
                                        : (m.isLead ? 'LEAD' : 'EMPLOYEE'),
                                    style: TextStyle(
                                      color: isSelfAdmin
                                          ? Colors.blueAccent
                                          : (m.isLead ? Colors.purpleAccent : Colors.grey[400]),
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                // Department Badge
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: deptName != null
                                        ? primaryColor.withOpacity(0.15)
                                        : Colors.grey.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    deptName ?? 'No Dept',
                                    style: TextStyle(
                                      color: deptName != null ? Colors.white : Colors.grey[500],
                                      fontSize: 10,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            subtitle: Text(
                              email,
                              style: TextStyle(color: Colors.grey[400], fontSize: 12),
                            ),
                            trailing: isSelfAdmin
                                ? null
                                : PopupMenuButton<String>(
                                    icon: const Icon(Icons.more_vert, color: Colors.grey),
                                    onSelected: (action) {
                                      if (action == 'dept') {
                                        _showAssignMemberDeptDialog(
                                          context,
                                          firmId,
                                          m.membershipId,
                                          m.uid,
                                          m.departmentId,
                                          departments,
                                        );
                                      } else if (action == 'role') {
                                        _showChangeMemberRoleDialog(
                                          context,
                                          firmId,
                                          m.membershipId,
                                          m.uid,
                                          m.role,
                                          name,
                                        );
                                      } else if (action == 'revoke') {
                                        _revokeMembership(context, m.membershipId, name);
                                      }
                                    },
                                    itemBuilder: (ctx) => [
                                      const PopupMenuItem(
                                        value: 'dept',
                                        child: Row(
                                          children: [
                                            Icon(Icons.corporate_fare, size: 18),
                                            SizedBox(width: 8),
                                            Text('Assign Department'),
                                          ],
                                        ),
                                      ),
                                      PopupMenuItem(
                                        value: 'role',
                                        child: Row(
                                          children: [
                                            const Icon(Icons.shield_outlined, size: 18),
                                            const SizedBox(width: 8),
                                            Text(m.isLead ? 'Demote to Employee' : 'Promote to Lead'),
                                          ],
                                        ),
                                      ),
                                      const PopupMenuDivider(),
                                      const PopupMenuItem(
                                        value: 'revoke',
                                        child: Row(
                                          children: [
                                            Icon(Icons.block, color: Colors.redAccent, size: 18),
                                            SizedBox(width: 8),
                                            Text('Revoke Access', style: TextStyle(color: Colors.redAccent)),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // ROLE & DEPARTMENT MANAGEMENT DIALOGS
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> _showAssignMemberDeptDialog(
    BuildContext context,
    String firmId,
    String membershipId,
    String uid,
    String? currentDeptId,
    List<Department> departments,
  ) async {
    String? selectedDeptId = currentDeptId;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: const Color.fromRGBO(34, 33, 33, 1),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Assign Department', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Assigning a department grants automatic derived access to that department\'s group chat.',
                style: TextStyle(color: Colors.grey, fontSize: 13),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String?>(
                value: selectedDeptId,
                dropdownColor: const Color.fromRGBO(34, 33, 33, 1),
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Department',
                  labelStyle: const TextStyle(color: Colors.grey),
                  filled: true,
                  fillColor: const Color.fromRGBO(24, 23, 23, 1),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('None (Unassigned)', style: TextStyle(color: Colors.grey)),
                  ),
                  ...departments.where((d) => d.isActive).map(
                    (d) => DropdownMenuItem<String?>(
                      value: d.deptId,
                      child: Text(d.name, style: const TextStyle(color: Colors.white)),
                    ),
                  ),
                ],
                onChanged: (val) {
                  setDialogState(() => selectedDeptId = val);
                },
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: Colors.grey))),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                try {
                  await DBService.instance.assignMemberDepartment(
                    firmId,
                    uid,
                    selectedDeptId,
                  );
                  SnackbarService().showSnackbar('Department assignment updated successfully!');
                } catch (e) {
                  SnackbarService().showSnackbar('Error updating department: $e', isError: true);
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showChangeMemberRoleDialog(
    BuildContext context,
    String firmId,
    String membershipId,
    String uid,
    MembershipRole currentRole,
    String name,
  ) async {
    MembershipRole selectedRole = currentRole == MembershipRole.lead ? MembershipRole.employee : MembershipRole.lead;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color.fromRGBO(34, 33, 33, 1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          selectedRole == MembershipRole.lead ? 'Promote to Lead?' : 'Demote to Employee?',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              selectedRole == MembershipRole.lead
                  ? 'Promoting $name to Lead will grant permissions to create/manage project groups and post in #all-staff.\n\nNote: For all privileges to immediately reflect on the user\'s screen, an app restart is recommended.'
                  : 'Demoting $name to Employee will remove their permissions to create project groups.',
              style: const TextStyle(color: Colors.grey, fontSize: 13),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: selectedRole == MembershipRole.lead ? Colors.purple : Colors.blueGrey,
            ),
            child: Text(selectedRole == MembershipRole.lead ? 'Promote to Lead' : 'Demote to Employee'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await DBService.instance.updateMemberRole(firmId, uid, selectedRole);
        SnackbarService().showSnackbar(
          'Updated $name\'s role to ${selectedRole.name.toUpperCase()}.' +
              (selectedRole == MembershipRole.lead ? ' An app restart is recommended for full reflection.' : ''),
        );
      } catch (e) {
        SnackbarService().showSnackbar('Error updating role: $e', isError: true);
      }
    }
  }

  Future<void> _showBulkAssignDeptDialog(
    BuildContext context,
    String firmId,
    List<String> memberIds,
    List<Department> departments,
  ) async {
    String? selectedDeptId;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: const Color.fromRGBO(34, 33, 33, 1),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Bulk Assign Department (${memberIds.length} staff)', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Assign all selected staff to a department. Their access to the department chat will be automatically granted.',
                style: TextStyle(color: Colors.grey, fontSize: 13),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String?>(
                value: selectedDeptId,
                dropdownColor: const Color.fromRGBO(34, 33, 33, 1),
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Target Department',
                  labelStyle: const TextStyle(color: Colors.grey),
                  filled: true,
                  fillColor: const Color.fromRGBO(24, 23, 23, 1),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('None (Remove Department)', style: TextStyle(color: Colors.grey)),
                  ),
                  ...departments.where((d) => d.isActive).map(
                    (d) => DropdownMenuItem<String?>(
                      value: d.deptId,
                      child: Text(d.name, style: const TextStyle(color: Colors.white)),
                    ),
                  ),
                ],
                onChanged: (val) {
                  setDialogState(() => selectedDeptId = val);
                },
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: Colors.grey))),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                try {
                  await DBService.instance.bulkAssignDepartment(
                    firmId,
                    memberIds,
                    selectedDeptId,
                  );
                  setState(() => _selectedActiveMemberIds.clear());
                  SnackbarService().showSnackbar('Bulk assigned ${memberIds.length} members to department.');
                } catch (e) {
                  SnackbarService().showSnackbar('Error in bulk department assignment: $e', isError: true);
                }
              },
              child: const Text('Apply to All Selected'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showBulkSetRoleDialog(
    BuildContext context,
    String firmId,
    List<String> memberIds,
  ) async {
    MembershipRole selectedRole = MembershipRole.lead;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: const Color.fromRGBO(34, 33, 33, 1),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Bulk Set Role (${memberIds.length} staff)', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Change the role for all selected members simultaneously.',
                style: TextStyle(color: Colors.grey, fontSize: 13),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<MembershipRole>(
                value: selectedRole,
                dropdownColor: const Color.fromRGBO(34, 33, 33, 1),
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Target Role',
                  labelStyle: const TextStyle(color: Colors.grey),
                  filled: true,
                  fillColor: const Color.fromRGBO(24, 23, 23, 1),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                items: const [
                  DropdownMenuItem(
                    value: MembershipRole.lead,
                    child: Text('Lead (Manage Project Groups & Post #all-staff)', style: TextStyle(color: Colors.purpleAccent)),
                  ),
                  DropdownMenuItem(
                    value: MembershipRole.employee,
                    child: Text('Employee (Standard Member)', style: TextStyle(color: Colors.white)),
                  ),
                ],
                onChanged: (val) {
                  if (val != null) {
                    setDialogState(() => selectedRole = val);
                  }
                },
              ),
              const SizedBox(height: 12),
              const Text(
                'Note: When upgrading staff to Lead, affected users should restart their app for privileges to fully reflect.',
                style: TextStyle(color: Colors.orangeAccent, fontSize: 12),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: Colors.grey))),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                try {
                  await DBService.instance.bulkUpdateRoles(
                    firmId,
                    memberIds,
                    selectedRole,
                  );
                  setState(() => _selectedActiveMemberIds.clear());
                  SnackbarService().showSnackbar('Bulk updated ${memberIds.length} members to ${selectedRole.name}. Note: App restart recommended.');
                } catch (e) {
                  SnackbarService().showSnackbar('Error updating roles: $e', isError: true);
                }
              },
              child: const Text('Apply Role'),
            ),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // DEPARTMENTS OVERSIGHT CARD
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildDepartmentsCard(BuildContext context, String firmId, Color primaryColor) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.corporate_fare, color: primaryColor, size: 22),
                    const SizedBox(width: 8),
                    Text(
                      'Departments & Department Chats',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: () => _showCreateDepartmentDialog(context, firmId),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('New Department'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Access is derived automatically: assigning an employee to a department gives them access to its group chat without managing participant lists.',
              style: TextStyle(color: Colors.grey[400], fontSize: 12),
            ),
            const SizedBox(height: 16),
            StreamBuilder<List<Department>>(
              stream: DBService.instance.streamDepartments(firmId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: CircularProgressIndicator(),
                    ),
                  );
                }
                final departments = snapshot.data ?? [];
                if (departments.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        children: [
                          Icon(Icons.corporate_fare_outlined, size: 40, color: Colors.grey[600]),
                          const SizedBox(height: 8),
                          Text('No departments created yet', style: TextStyle(color: Colors.grey[400])),
                          const SizedBox(height: 4),
                          Text('Create a department to establish group channels and organize your team.',
                              style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: departments.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final dept = departments[index];

                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        backgroundColor: primaryColor.withOpacity(0.15),
                        child: Icon(Icons.folder_shared_outlined, color: primaryColor, size: 20),
                      ),
                      title: Row(
                        children: [
                          Text(dept.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: dept.isActive ? Colors.green.withOpacity(0.15) : Colors.grey.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              dept.status.toUpperCase(),
                              style: TextStyle(
                                color: dept.isActive ? Colors.greenAccent : Colors.grey,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      subtitle: Row(
                        children: [
                          // Headcount
                          FutureBuilder<int>(
                            future: DBService.instance.getDepartmentHeadcount(firmId, dept.deptId),
                            builder: (context, countSnapshot) {
                              final count = countSnapshot.data ?? 0;
                              return Text(
                                '$count active staff',
                                style: TextStyle(color: Colors.grey[400], fontSize: 12),
                              );
                            },
                          ),
                          const SizedBox(width: 12),
                          // Head label
                          if (dept.headUid != null)
                            FutureBuilder<AppUser?>(
                              future: DBService.instance.getUserDetails(dept.headUid!),
                              builder: (context, headSnap) {
                                final headName = headSnap.data?.name ?? 'Assigned Head';
                                return Text(
                                  '• Head: $headName',
                                  style: const TextStyle(color: Colors.amberAccent, fontSize: 12),
                                );
                              },
                            )
                          else
                            Text(
                              '• No Head Assigned',
                              style: TextStyle(color: Colors.grey[500], fontSize: 12),
                            ),
                        ],
                      ),
                      onTap: () => _showManageDepartmentMembersDialog(context, firmId, dept),
                      trailing: PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert, color: Colors.grey),
                        onSelected: (action) {
                          if (action == 'members') {
                            _showManageDepartmentMembersDialog(context, firmId, dept);
                          } else if (action == 'head') {
                            _showAssignDepartmentHeadDialog(context, firmId, dept);
                          } else if (action == 'rename') {
                            _showRenameDepartmentDialog(context, firmId, dept);
                          } else if (action == 'archive') {
                            _showArchiveDepartmentDialog(context, firmId, dept);
                          }
                        },
                        itemBuilder: (ctx) => [
                          const PopupMenuItem(
                            value: 'members',
                            child: Row(
                              children: [
                                Icon(Icons.people_outline, size: 16),
                                SizedBox(width: 8),
                                Text('Assign / Manage Employees'),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'head',
                            child: Row(
                              children: [
                                Icon(Icons.badge_outlined, size: 16),
                                SizedBox(width: 8),
                                Text('Assign Department Head (Lead)'),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'rename',
                            child: Row(
                              children: [
                                Icon(Icons.edit, size: 16),
                                SizedBox(width: 8),
                                Text('Rename Department'),
                              ],
                            ),
                          ),
                          if (dept.isActive) ...[
                            const PopupMenuDivider(),
                            const PopupMenuItem(
                              value: 'archive',
                              child: Row(
                                children: [
                                  Icon(Icons.archive_outlined, color: Colors.redAccent, size: 16),
                                  SizedBox(width: 8),
                                  Text('Archive Department', style: TextStyle(color: Colors.redAccent)),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showCreateDepartmentDialog(BuildContext context, String firmId) async {
    final nameCtrl = TextEditingController();
    String? selectedHeadUid;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: const Color.fromRGBO(34, 33, 33, 1),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Create Department', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'A dedicated group conversation will be automatically established for this department in the mobile app.',
                style: TextStyle(color: Colors.grey, fontSize: 13),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: nameCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Department Name',
                  hintText: 'e.g. Engineering, Sales, Marketing',
                  hintStyle: TextStyle(color: Colors.grey[600]),
                  labelStyle: const TextStyle(color: Colors.grey),
                  filled: true,
                  fillColor: const Color.fromRGBO(24, 23, 23, 1),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 14),
              StreamBuilder<List<Membership>>(
                stream: DBService.instance.getMembershipsByStatus(firmId, 'approved'),
                builder: (context, snapshot) {
                  final members = snapshot.data ?? [];
                  return DropdownButtonFormField<String?>(
                    value: selectedHeadUid,
                    dropdownColor: const Color.fromRGBO(34, 33, 33, 1),
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Department Head / Lead (Optional)',
                      labelStyle: const TextStyle(color: Colors.grey),
                      filled: true,
                      fillColor: const Color.fromRGBO(24, 23, 23, 1),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('Assign Later (No Head)', style: TextStyle(color: Colors.grey)),
                      ),
                      ...members.map(
                        (m) => DropdownMenuItem<String?>(
                          value: m.uid,
                          child: FutureBuilder<AppUser?>(
                            future: DBService.instance.getUserDetails(m.uid),
                            builder: (context, userSnap) {
                              final appUser = userSnap.data;
                              final name = (appUser != null && appUser.name.isNotEmpty)
                                  ? appUser.name
                                  : (appUser?.email.isNotEmpty == true ? appUser!.email : m.uid);
                              return Text(name, style: const TextStyle(color: Colors.white));
                            },
                          ),
                        ),
                      ),
                    ],
                    onChanged: (val) {
                      setDialogState(() => selectedHeadUid = val);
                    },
                  );
                },
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: Colors.grey))),
            ElevatedButton(
              onPressed: () async {
                final name = nameCtrl.text.trim();
                if (name.isEmpty) {
                  SnackbarService().showSnackbar('Please enter a department name.', isError: true);
                  return;
                }
                Navigator.pop(ctx);
                try {
                  await DBService.instance.createDepartment(
                    firmId: firmId,
                    name: name,
                    headUid: selectedHeadUid,
                  );
                  SnackbarService().showSnackbar('Department "$name" created successfully!');
                } catch (e) {
                  SnackbarService().showSnackbar('Error creating department: $e', isError: true);
                }
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showRenameDepartmentDialog(BuildContext context, String firmId, Department dept) async {
    final nameCtrl = TextEditingController(text: dept.name);
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color.fromRGBO(34, 33, 33, 1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Rename Department', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: nameCtrl,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            labelText: 'Department Name',
            labelStyle: const TextStyle(color: Colors.grey),
            filled: true,
            fillColor: const Color.fromRGBO(24, 23, 23, 1),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            onPressed: () async {
              final newName = nameCtrl.text.trim();
              if (newName.isEmpty) return;
              Navigator.pop(ctx);
              try {
                await DBService.instance.renameDepartment(firmId, dept.deptId, dept.conversationId, newName);
                SnackbarService().showSnackbar('Department renamed to "$newName".');
              } catch (e) {
                SnackbarService().showSnackbar('Error renaming department: $e', isError: true);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _showAssignDepartmentHeadDialog(BuildContext context, String firmId, Department dept) async {
    String? selectedHeadUid = dept.headUid;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: const Color.fromRGBO(34, 33, 33, 1),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Assign Head: ${dept.name}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Assigning a Department Head designates them as Team Lead, grants Lead privileges in the mobile application, and automatically assigns them to this department.',
                style: TextStyle(color: Colors.grey, fontSize: 13),
              ),
              const SizedBox(height: 16),
              StreamBuilder<List<Membership>>(
                stream: DBService.instance.getMembershipsByStatus(firmId, 'approved'),
                builder: (context, snapshot) {
                  final members = snapshot.data ?? [];
                  return DropdownButtonFormField<String?>(
                    value: selectedHeadUid,
                    dropdownColor: const Color.fromRGBO(34, 33, 33, 1),
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Department Head / Lead',
                      labelStyle: const TextStyle(color: Colors.grey),
                      filled: true,
                      fillColor: const Color.fromRGBO(24, 23, 23, 1),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('No Head (Clear Head)', style: TextStyle(color: Colors.grey)),
                      ),
                      ...members.map(
                        (m) => DropdownMenuItem<String?>(
                          value: m.uid,
                          child: FutureBuilder<AppUser?>(
                            future: DBService.instance.getUserDetails(m.uid),
                            builder: (context, userSnap) {
                              final appUser = userSnap.data;
                              final name = (appUser != null && appUser.name.isNotEmpty)
                                  ? appUser.name
                                  : (appUser?.email.isNotEmpty == true ? appUser!.email : m.uid);
                              return Text(name, style: const TextStyle(color: Colors.white));
                            },
                          ),
                        ),
                      ),
                    ],
                    onChanged: (val) {
                      setDialogState(() => selectedHeadUid = val);
                    },
                  );
                },
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: Colors.grey))),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                try {
                  await DBService.instance.updateDepartmentHead(firmId, dept.deptId, selectedHeadUid);
                  SnackbarService().showSnackbar('Department head updated. Lead privileges and department assigned.');
                } catch (e) {
                  SnackbarService().showSnackbar('Error updating department head: $e', isError: true);
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  /// Dialog to assign and manage employees directly from the department card.
  Future<void> _showManageDepartmentMembersDialog(
    BuildContext context,
    String firmId,
    Department dept,
  ) async {
    final searchCtrl = TextEditingController();
    Set<String>? selectedUids;
    Set<String>? initialUids;
    String searchQuery = '';
    final Map<String, AppUser> userCache = {};
    bool isFetchingUsers = false;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return StreamBuilder<List<Membership>>(
            stream: DBService.instance.getMembershipsByStatus(firmId, 'approved'),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting && selectedUids == null) {
                return const AlertDialog(
                  backgroundColor: Color.fromRGBO(34, 33, 33, 1),
                  content: SizedBox(
                    height: 120,
                    child: Center(child: CircularProgressIndicator()),
                  ),
                );
              }

              final allMembers = snapshot.data ?? [];
              if (selectedUids == null) {
                initialUids = allMembers
                    .where((m) => m.departmentId == dept.deptId || m.uid == dept.headUid)
                    .map((m) => m.uid)
                    .toSet();
                selectedUids = Set<String>.from(initialUids!);
              }

              if (!isFetchingUsers && userCache.length < allMembers.length) {
                isFetchingUsers = true;
                Future.wait(
                  allMembers.where((m) => !userCache.containsKey(m.uid)).map((m) async {
                    final u = await DBService.instance.getUserDetails(m.uid);
                    if (u != null) userCache[m.uid] = u;
                  }),
                ).then((_) {
                  if (ctx.mounted) {
                    setDialogState(() {});
                  }
                });
              }

              final filteredMembers = allMembers.where((m) {
                if (searchQuery.isEmpty) return true;
                final user = userCache[m.uid];
                final name = user?.name.toLowerCase() ?? '';
                final email = user?.email.toLowerCase() ?? '';
                return name.contains(searchQuery) ||
                    email.contains(searchQuery) ||
                    m.uid.toLowerCase().contains(searchQuery);
              }).toList();

              return AlertDialog(
                backgroundColor: const Color.fromRGBO(34, 33, 33, 1),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                title: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.group_outlined, color: Colors.blueAccent, size: 22),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Manage Members: ${dept.name}',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Assigned employees receive automatic access to the #${dept.name} department chat in the mobile app.',
                      style: TextStyle(color: Colors.grey[400], fontSize: 12),
                    ),
                  ],
                ),
                content: SizedBox(
                  width: double.maxFinite,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: searchCtrl,
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                        decoration: InputDecoration(
                          hintText: 'Search staff by name or email...',
                          hintStyle: TextStyle(color: Colors.grey[500], fontSize: 13),
                          prefixIcon: const Icon(Icons.search, color: Colors.grey, size: 20),
                          filled: true,
                          fillColor: const Color.fromRGBO(24, 23, 23, 1),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onChanged: (val) {
                          setDialogState(() => searchQuery = val.trim().toLowerCase());
                        },
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${selectedUids!.length} member(s) assigned',
                            style: const TextStyle(color: Colors.blueAccent, fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                          Row(
                            children: [
                              TextButton(
                                onPressed: () {
                                  setDialogState(() {
                                    selectedUids!.addAll(allMembers.map((m) => m.uid));
                                  });
                                },
                                style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                                child: const Text('Select All', style: TextStyle(fontSize: 12)),
                              ),
                              TextButton(
                                onPressed: () {
                                  setDialogState(() {
                                    selectedUids!.clear();
                                    if (dept.headUid != null) {
                                      selectedUids!.add(dept.headUid!);
                                    }
                                  });
                                },
                                style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                                child: const Text('Clear', style: TextStyle(fontSize: 12, color: Colors.grey)),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const Divider(color: Colors.white12, height: 16),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 280),
                        child: filteredMembers.isEmpty
                            ? const Padding(
                                padding: EdgeInsets.all(24.0),
                                child: Center(
                                  child: Text('No members found', style: TextStyle(color: Colors.grey)),
                                ),
                              )
                            : ListView.builder(
                                shrinkWrap: true,
                                itemCount: filteredMembers.length,
                                itemBuilder: (ctx, idx) {
                                  final m = filteredMembers[idx];
                                  final isHead = m.uid == dept.headUid;
                                  final isSelected = selectedUids!.contains(m.uid);
                                  final isOtherDept = m.departmentId != null &&
                                      m.departmentId != dept.deptId &&
                                      !isSelected;
                                  final user = userCache[m.uid];
                                  final displayName = (user != null && user.name.isNotEmpty)
                                      ? user.name
                                      : (user != null && user.email.isNotEmpty
                                          ? user.email
                                          : 'Staff (${m.uid.substring(0, m.uid.length > 6 ? 6 : m.uid.length)})');
                                  final displayEmail = (user != null && user.email.isNotEmpty)
                                      ? user.email
                                      : 'UID: ${m.uid}';

                                  return CheckboxListTile(
                                    value: isSelected,
                                    activeColor: Colors.blueAccent,
                                    checkColor: Colors.white,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                                    controlAffinity: ListTileControlAffinity.leading,
                                    onChanged: isHead
                                        ? null
                                        : (bool? checked) {
                                            setDialogState(() {
                                              if (checked == true) {
                                                selectedUids!.add(m.uid);
                                              } else {
                                                selectedUids!.remove(m.uid);
                                              }
                                            });
                                          },
                                    title: Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            displayName,
                                            style: const TextStyle(color: Colors.white, fontSize: 14),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        if (isHead) ...[
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: Colors.amber.withOpacity(0.2),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: const Text(
                                              'HEAD / LEAD',
                                              style: TextStyle(color: Colors.amberAccent, fontSize: 9, fontWeight: FontWeight.bold),
                                            ),
                                          ),
                                        ],
                                        if (isOtherDept) ...[
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: Colors.grey.withOpacity(0.2),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: const Text(
                                              'Other Dept',
                                              style: TextStyle(color: Colors.grey, fontSize: 9),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    subtitle: Text(
                                      displayEmail,
                                      style: TextStyle(color: Colors.grey[500], fontSize: 11),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      Navigator.pop(ctx);
                      try {
                        final assigned = selectedUids!.toList();
                        final unassigned = initialUids!.difference(selectedUids!).toList();
                        await DBService.instance.updateDepartmentMembers(
                          firmId: firmId,
                          deptId: dept.deptId,
                          assignedUids: assigned,
                          unassignedUids: unassigned,
                        );
                        SnackbarService().showSnackbar('Updated department members for ${dept.name} successfully.');
                      } catch (e) {
                        SnackbarService().showSnackbar('Error updating members: $e', isError: true);
                      }
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
                    child: const Text('Save Members'),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _showArchiveDepartmentDialog(BuildContext context, String firmId, Department dept) async {
    final count = await DBService.instance.getDepartmentHeadcount(firmId, dept.deptId);
    if (!context.mounted) return;

    if (count > 0) {
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color.fromRGBO(34, 33, 33, 1),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Cannot Archive Department', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          content: Text(
            'This department currently has $count active staff members assigned to it. '
            'Please reassign or unassign all members before archiving.',
            style: const TextStyle(color: Colors.grey, fontSize: 13),
          ),
          actions: [
            ElevatedButton(onPressed: () => Navigator.pop(ctx), child: const Text('Understood')),
          ],
        ),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color.fromRGBO(34, 33, 33, 1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Archive ${dept.name}?', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: const Text(
          'Archiving this department will freeze its group conversation.',
          style: TextStyle(color: Colors.grey, fontSize: 13),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Archive'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await DBService.instance.archiveDepartment(firmId, dept.deptId);
        SnackbarService().showSnackbar('Department "${dept.name}" archived.');
      } catch (e) {
        SnackbarService().showSnackbar('Error: ${e.toString().replaceAll('Exception:', '')}', isError: true);
      }
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // PROJECT GROUPS METADATA OVERSIGHT CARD
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildProjectGroupsCard(BuildContext context, String firmId, Color primaryColor) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.work_outline, color: primaryColor, size: 22),
                const SizedBox(width: 8),
                Text(
                  'Project Groups (Metadata Oversight)',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Zero-message oversight: Admins observe project names, owners, and headcount without reading private project messages.',
              style: TextStyle(color: Colors.grey[400], fontSize: 12),
            ),
            const SizedBox(height: 16),
            StreamBuilder<List<ProjectGroup>>(
              stream: DBService.instance.streamProjectGroupsForAdmin(firmId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: CircularProgressIndicator(),
                    ),
                  );
                }
                final projects = snapshot.data ?? [];
                if (projects.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        children: [
                          Icon(Icons.work_off_outlined, size: 40, color: Colors.grey[600]),
                          const SizedBox(height: 8),
                          Text('No project groups created yet', style: TextStyle(color: Colors.grey[400])),
                          const SizedBox(height: 4),
                          Text('Leads can create project groups for cross-functional collaboration.',
                              style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: projects.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final p = projects[index];

                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        backgroundColor: Colors.purple.withOpacity(0.15),
                        child: const Icon(Icons.group_work, color: Colors.purpleAccent, size: 20),
                      ),
                      title: Row(
                        children: [
                          Text(p.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: p.isActive ? Colors.purple.withOpacity(0.2) : Colors.grey.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              p.status.toUpperCase(),
                              style: TextStyle(
                                color: p.isActive ? Colors.purpleAccent : Colors.grey,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      subtitle: Row(
                        children: [
                          Text(
                            '${p.memberCount} member(s)',
                            style: TextStyle(color: Colors.grey[400], fontSize: 12),
                          ),
                          const SizedBox(width: 12),
                          FutureBuilder<AppUser?>(
                            future: DBService.instance.getUserDetails(p.ownerUid),
                            builder: (context, ownerSnap) {
                              final ownerName = ownerSnap.data?.name ?? p.ownerUid;
                              return Text(
                                '• Owner: $ownerName',
                                style: TextStyle(color: Colors.grey[400], fontSize: 12),
                              );
                            },
                          ),
                        ],
                      ),
                      trailing: p.isActive
                          ? OutlinedButton.icon(
                              onPressed: () async {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    backgroundColor: const Color.fromRGBO(34, 33, 33, 1),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                    title: Text('Archive Project ${p.name}?'),
                                    content: const Text(
                                      'Archiving will freeze this project group.',
                                      style: TextStyle(color: Colors.grey, fontSize: 13),
                                    ),
                                    actions: [
                                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                                      ElevatedButton(
                                        onPressed: () => Navigator.pop(ctx, true),
                                        style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                                        child: const Text('Archive'),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirm == true) {
                                  try {
                                    await DBService.instance.archiveProjectGroup(
                                      firmId: firmId,
                                      projectId: p.projectId,
                                      conversationId: p.conversationId,
                                    );
                                    SnackbarService().showSnackbar('Project "${p.name}" archived.');
                                  } catch (e) {
                                    SnackbarService().showSnackbar('Error archiving project: $e', isError: true);
                                  }
                                }
                              },
                              icon: const Icon(Icons.archive_outlined, size: 14),
                              label: const Text('Archive'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.grey[400],
                                side: BorderSide(color: Colors.grey[700]!),
                              ),
                            )
                          : null,
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
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

  Future<void> _rejectMembership(
    BuildContext context,
    String membershipId,
    String name,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Access Request?'),
        content: Text(
          'Are you sure you want to reject $name\'s request to join the firm?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red[600]),
            child: const Text('Reject'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _actionLoading['reject_$membershipId'] = true);
    try {
      await DBService.instance.updateMembershipStatus(membershipId, 'rejected');
      SnackbarService().showSnackbar('$name\'s access request was rejected.');
    } catch (e) {
      SnackbarService().showSnackbar('Error rejecting member: $e', isError: true);
    } finally {
      if (mounted) {
        setState(() => _actionLoading['reject_$membershipId'] = false);
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
      SnackbarService().showSnackbar('$name access revoked successfully.');
    } catch (e) {
      SnackbarService().showSnackbar('Error revoking member: $e', isError: true);
    } finally {
      if (mounted) {
        setState(() => _actionLoading['revoke_$membershipId'] = false);
      }
    }
  }

  /// Step 4: The "Revoked Staff" View
  Widget _buildRevokedStaffTab(
    BuildContext context,
    String firmId,
    Color primaryColor,
  ) {
    return StreamBuilder<List<Membership>>(
      stream: DBService.instance.getMembershipsByStatus(firmId, 'revoked'),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error loading revoked staff: ${snapshot.error}',
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
                  Icon(Icons.check_circle_outline, size: 48, color: Colors.grey[600]),
                  const SizedBox(height: 8),
                  Text(
                    'No revoked staff members',
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
            final isRestoring = _actionLoading['restore_${m.membershipId}'] == true;

            return FutureBuilder<AppUser?>(
              future: DBService.instance.getUserDetails(m.uid),
              builder: (context, userSnapshot) {
                final appUser = userSnapshot.data;
                final name = (appUser != null && appUser.name.isNotEmpty)
                    ? appUser.name
                    : 'Staff Member (${m.uid.substring(0, m.uid.length > 6 ? 6 : m.uid.length)})';
                final email = (appUser != null && appUser.email.isNotEmpty)
                    ? appUser.email
                    : 'UID: ${m.uid}';
                final avatarUrl = appUser?.image ??
                    'https://api.dicebear.com/7.x/avataaars/png?seed=${Uri.encodeComponent(name)}';

                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundImage: NetworkImage(avatarUrl),
                    onBackgroundImageError: (_, __) {},
                  ),
                  title: Row(
                    children: [
                      Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'Revoked',
                          style: TextStyle(color: Colors.redAccent, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  subtitle: Text(
                    email,
                    style: TextStyle(color: Colors.grey[400], fontSize: 12),
                  ),
                  trailing: ElevatedButton.icon(
                    onPressed: isRestoring
                        ? null
                        : () => _restoreMembership(context, m.membershipId, name),
                    icon: const Icon(Icons.restore, size: 16),
                    label: isRestoring
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Restore Access'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green[700],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Future<void> _restoreMembership(
    BuildContext context,
    String membershipId,
    String name,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restore Access?'),
        content: Text(
          'Are you sure you want to restore workspace access for $name?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green[700],
              foregroundColor: Colors.white,
            ),
            child: const Text('Restore'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _actionLoading['restore_$membershipId'] = true);
    try {
      await DBService.instance.updateMembershipStatus(membershipId, 'approved');
      SnackbarService().showSnackbar('$name access restored successfully.');
    } catch (e) {
      SnackbarService().showSnackbar('Error restoring member: $e', isError: true);
    } finally {
      if (mounted) {
        setState(() => _actionLoading['restore_$membershipId'] = false);
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
                          onError: (exception, stackTrace) {
                            debugPrint('Notice: Brand logo could not be loaded: $exception');
                          },
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
        ChatService.instance.cancelAllSubscriptions();
        await FirebaseAuth.instance.signOut();
        if (mounted) {
          context.go('/register-firm');
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

/// Tile for a pre-approved staff member.
/// Handles:
/// - Auto-reset of staff code every 5 minutes when pending
/// - Live countdown indicator
/// - Manual code reset button
/// - Hiding staff code entirely if the employee has already onboarded
class _PreApprovedStaffTile extends StatefulWidget {
  final Map<String, dynamic> staff;
  final String firmId;
  final Color primaryColor;

  const _PreApprovedStaffTile({
    super.key,
    required this.staff,
    required this.firmId,
    required this.primaryColor,
  });

  @override
  State<_PreApprovedStaffTile> createState() => _PreApprovedStaffTileState();
}

class _PreApprovedStaffTileState extends State<_PreApprovedStaffTile> {
  Timer? _countdownTimer;
  bool _isResetting = false;
  DateTime? _lastAutoResetAttempt;

  @override
  void initState() {
    super.initState();
    _startTimerIfNeeded();
  }

  @override
  void didUpdateWidget(covariant _PreApprovedStaffTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    _startTimerIfNeeded();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _startTimerIfNeeded() {
    final status = widget.staff['status'] as String? ?? 'invited';
    if (status == 'joined') {
      _countdownTimer?.cancel();
      _countdownTimer = null;
      return;
    }

    if (_countdownTimer == null || !_countdownTimer!.isActive) {
      _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }
        _checkAndHandleCountdown();
      });
    }
  }

  DateTime? get _expiresAt {
    final exp = widget.staff['codeExpiresAt'];
    if (exp is Timestamp) return exp.toDate();
    return null;
  }

  int get _remainingSeconds {
    final expires = _expiresAt;
    if (expires == null) return 0;
    final diff = expires.difference(DateTime.now()).inSeconds;
    return diff > 0 ? diff : 0;
  }

  void _checkAndHandleCountdown() {
    final status = widget.staff['status'] as String? ?? 'invited';
    if (status == 'joined') return;

    final remaining = _remainingSeconds;
    setState(() {});

    // If expired or missing, auto-reset every 5 minutes
    if (remaining <= 0 && !_isResetting) {
      final now = DateTime.now();
      if (_lastAutoResetAttempt == null ||
          now.difference(_lastAutoResetAttempt!).inSeconds >= 10) {
        _lastAutoResetAttempt = now;
        _triggerReset(isManual: false);
      }
    }
  }

  Future<void> _triggerReset({required bool isManual}) async {
    if (_isResetting || !mounted) return;
    setState(() => _isResetting = true);

    final staffId = widget.staff['id'] as String? ?? '';
    final email = widget.staff['email'] as String? ?? '';
    if (staffId.isEmpty) {
      if (mounted) setState(() => _isResetting = false);
      return;
    }

    try {
      final newCode = await DBService.instance.resetStaffCode(
        firmId: widget.firmId,
        staffDocId: staffId,
      );
      if (mounted && isManual) {
        SnackbarService().showSnackbar('New code for $email: $newCode (valid for 5 mins)');
      }
    } catch (e) {
      debugPrint('Error resetting code for $staffId: $e');
      if (mounted && isManual) {
        SnackbarService().showSnackbar('Failed to reset code: $e', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isResetting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final staffId = widget.staff['id'] as String? ?? '';
    final email = widget.staff['email'] as String? ?? '';
    final name = widget.staff['name'] as String? ?? email;
    final code = widget.staff['code'] as String? ?? '';
    final status = widget.staff['status'] as String? ?? 'invited';
    final isJoined = status == 'joined';
    final remaining = _remainingSeconds;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: isJoined
            ? Colors.green.withOpacity(0.2)
            : widget.primaryColor.withOpacity(0.2),
        child: Icon(
          isJoined ? Icons.check : Icons.key,
          color: isJoined ? Colors.greenAccent : widget.primaryColor,
          size: 18,
        ),
      ),
      title: Row(
        children: [
          Flexible(
            child: Text(
              name,
              style: const TextStyle(fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: isJoined
                  ? Colors.green.withOpacity(0.2)
                  : Colors.orange.withOpacity(0.2),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              isJoined ? 'ONBOARDED' : 'PENDING ONBOARDING',
              style: TextStyle(
                color: isJoined ? Colors.greenAccent : Colors.orangeAccent,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(email, style: TextStyle(color: Colors.grey[400], fontSize: 12)),
          const SizedBox(height: 4),
          if (isJoined)
            // Note: NO staff code for already onboarded users
            Row(
              children: [
                Icon(Icons.verified_outlined, size: 14, color: Colors.greenAccent.withOpacity(0.8)),
                const SizedBox(width: 4),
                Text(
                  'Onboarded (Active Member)',
                  style: TextStyle(
                    color: Colors.greenAccent.withOpacity(0.9),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            )
          else ...[
            // Staff code with 5-minute auto-reset and manual reset option
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color.fromRGBO(24, 23, 23, 1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.grey.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Code: ', style: TextStyle(color: Colors.grey, fontSize: 11)),
                      Text(
                        code.isNotEmpty ? code : '...',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.copy, size: 14, color: Colors.grey),
                  tooltip: 'Copy Code',
                  onPressed: code.isEmpty
                      ? null
                      : () async {
                          await Clipboard.setData(ClipboardData(text: code));
                          SnackbarService().showSnackbar('Code $code copied!');
                        },
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 6),
                // Remaining time indicator
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: remaining < 60
                        ? Colors.red.withOpacity(0.15)
                        : Colors.blue.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.timer_outlined,
                        size: 11,
                        color: remaining < 60 ? Colors.redAccent : Colors.lightBlueAccent,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        remaining > 0
                            ? '${remaining ~/ 60}:${(remaining % 60).toString().padLeft(2, '0')}'
                            : 'Resetting...',
                        style: TextStyle(
                          color: remaining < 60 ? Colors.redAccent : Colors.lightBlueAccent,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                // Manual Reset Button
                if (_isResetting)
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  IconButton(
                    icon: const Icon(Icons.refresh, size: 16, color: Colors.blueAccent),
                    tooltip: 'Reset code manually',
                    onPressed: () => _triggerReset(isManual: true),
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    constraints: const BoxConstraints(),
                  ),
              ],
            ),
          ],
        ],
      ),
      trailing: isJoined
          ? null
          : IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
              tooltip: 'Remove',
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Remove Staff Entry?'),
                    content: Text('Remove $email from pre-approved staff? This will free 1 trial seat.'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
                        child: const Text('Remove'),
                      ),
                    ],
                  ),
                );
                if (confirm == true) {
                  await DBService.instance.removePreApprovedStaff(
                    firmId: widget.firmId,
                    staffDocId: staffId,
                  );
                  if (context.mounted) {
                    SnackbarService().showSnackbar('Pre-authorized staff entry removed.');
                  }
                }
              },
            ),
    );
  }
}

