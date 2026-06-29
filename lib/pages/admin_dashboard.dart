import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:pronto_chat/models/firm.dart';
import 'package:pronto_chat/providers/firm/providers.dart';
import 'package:pronto_chat/services/db_service.dart';
import 'package:pronto_chat/services/snackbar_service.dart';

/// Provider to fetch the current admin's name.
/// This encapsulates the data fetching logic and makes it available to the UI.
final adminNameProvider = FutureProvider<String?>((ref) async {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) {
    return null; // No user logged in
  }
  final dbService = DBService.instance;
  final userData = await dbService.getUserData(uid);
  // Return the name, or null if not found
  return userData?['name'] as String?;
});

/// Admin Dashboard screen.
/// Displays firm information, QR code for onboarding, and staff management placeholders.
class AdminDashboard extends ConsumerStatefulWidget {
  const AdminDashboard({super.key});

  @override
  ConsumerState<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends ConsumerState<AdminDashboard> {
  @override
  void initState() {
    super.initState();
    // Start loading firm immediately in initState to prevent a frame with empty state
    _loadFirmIfNecessary();
  }

  Future<void> _loadFirmIfNecessary() async {
    final currentFirm = ref.read(currentFirmProvider);
    if (currentFirm == null) {
      // FIX C: Call setLoading(true) synchronously before the Firestore await
      ref.read(firmNotifierProvider.notifier).setLoading(true);

      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        try {
          final memberships = await DBService.instance.getUserFirms(uid).first;
          if (memberships.isNotEmpty) {
            final firmId = memberships.first.firmId;
            if (mounted) {
              // loadFirm will asynchronously fetch the firm and set isLoading back to false when done or on error.
              await ref.read(firmNotifierProvider.notifier).loadFirm(firmId);
            }
          } else {
            // FIX C: No memberships found, so we must stop loading
            if (mounted) {
              ref.read(firmNotifierProvider.notifier).setLoading(false);
            }
          }
        } catch (e) {
          debugPrint('Error auto-loading firm: $e');
          // FIX C: An error occurred, so we must stop loading
          if (mounted) {
            ref.read(firmNotifierProvider.notifier).setLoading(false);
          }
        }
      } else {
        // No logged-in user, so we cannot load a firm
        if (mounted) {
          ref.read(firmNotifierProvider.notifier).setLoading(false);
        }
      }
    }
  }

  /// Handle logout
  Future<void> _handleLogout() async {
    // It's good practice to check if the widget is still mounted before showing a dialog
    if (!mounted) return;

    // Capture the Navigator before the async gap to avoid using BuildContext across async gaps.
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
              // Pop the dialog
              Navigator.pop(dialogContext);

              try {
                await FirebaseAuth.instance.signOut();
                // Use the captured navigator to push the new route
                navigator.pushReplacementNamed('/login');
              } catch (e) {
                // For showing a snackbar, we should still check if the widget is mounted
                // as it depends on the Scaffold context.
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        centerTitle: true,
        actions: [
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
  Widget _buildDashboardContent(BuildContext context, Firm? firm) {
    final adminNameAsync = ref.watch(adminNameProvider);
    final adminName = adminNameAsync.when(
      data: (name) => name ?? 'Not available',
      loading: () => 'Loading...',
      error: (e, st) {
        debugPrint('Error loading admin name: $e');
        return 'Error';
      },
    );
    if (firm == null) {
      return _buildNoFirmState(context);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;

        return SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.all(isMobile ? 16 : 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Text(
                  firm.name,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Admin Dashboard',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(color: Colors.grey[600]),
                ),
                const SizedBox(height: 32),

                // Firm Profile Card
                Card(
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Firm Information',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 16),
                                  _buildInfoRow('Firm Name:', firm.name),
                                  _buildInfoRow('Admin:', adminName),
                                  _buildInfoRow(
                                    'Created:',
                                    _formatDate(firm.createdAt),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            // Color swatch
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Container(
                                  width: 80,
                                  height: 80,
                                  decoration: BoxDecoration(
                                    color: _hexToColor(firm.primaryColor),
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: _hexToColor(
                                          firm.primaryColor,
                                        ).withOpacity(0.3),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Brand Color',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                                Text(
                                  firm.primaryColor,
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // QR Code Section
                Card(
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          'Employee Onboarding QR Code',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 16),
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
                            data: 'pronto://firm/join?firmId=${firm.firmId}',
                            version: QrVersions.auto,
                            size: 200.0,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Share this QR code with employees to join your firm',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: Colors.grey[600]),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            ElevatedButton.icon(
                              onPressed: () {
                                // TODO: Implement in Phase 2
                                SnackbarService().showSnackbar(
                                  'Download QR coming in Phase 2',
                                );
                              },
                              icon: const Icon(Icons.download),
                              label: const Text('Download'),
                            ),
                            const SizedBox(width: 16),
                            OutlinedButton.icon(
                              onPressed: () {
                                // TODO: Implement in Phase 2
                                SnackbarService().showSnackbar(
                                  'Copy link coming in Phase 2',
                                );
                              },
                              icon: const Icon(Icons.copy),
                              label: const Text('Copy Link'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // Staff Section (empty for Phase 1)
                _buildStaffSection(context),
                const SizedBox(height: 32),

                // Pending Requests Section (empty for Phase 1)
                _buildPendingRequestsSection(context),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Build the active staff section
  Widget _buildStaffSection(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Active Staff (0)',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    // TODO: Phase 2
                    SnackbarService().showSnackbar('Add staff in Phase 2');
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Add Staff'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              height: 150,
              decoration: BoxDecoration(
                color: Colors.grey[50],
                border: Border.all(color: Colors.grey[300]!, width: 1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: ListView(
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  SizedBox(
                    height: 148,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.people, size: 48, color: Colors.grey[400]),
                          const SizedBox(height: 8),
                          Text(
                            'Staff will appear here after approval',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey[600], fontSize: 14),
                          ),
                        ],
                      ),
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

  /// Build the pending requests section
  Widget _buildPendingRequestsSection(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Pending Requests (0)',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Container(
              height: 150,
              decoration: BoxDecoration(
                color: Colors.grey[50],
                border: Border.all(color: Colors.grey[300]!, width: 1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: ListView(
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  SizedBox(
                    height: 148,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.schedule, size: 48, color: Colors.grey[400]),
                          const SizedBox(height: 8),
                          Text(
                            'Pending employees will appear here',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey[600], fontSize: 14),
                          ),
                        ],
                      ),
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

  /// Build state when no firm is loaded
  Widget _buildNoFirmState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.business, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text('No Firm Found', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
            'Please register a firm first',
            style: TextStyle(color: Colors.grey[600]),
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

  /// Helper to build info rows
  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
          const SizedBox(width: 12),
          Text(value),
        ],
      ),
    );
  }

  /// Format date to readable string
  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();
    return '$day/$month/$year';
  }
}
