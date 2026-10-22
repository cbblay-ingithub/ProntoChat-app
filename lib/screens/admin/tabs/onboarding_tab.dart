import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../../models/department.dart';
import '../../../models/firm.dart';
import '../../../models/membership.dart';
import '../../../providers/firm/providers.dart';
import '../../../services/audit_service.dart';
import '../../../services/csv_upload_service.dart';
import '../../../services/db_service.dart';
import '../../../services/snackbar_service.dart';

/// Unified representation of a staff member across both active/revoked memberships
/// and pre-authorized invitation codes.
enum UnifiedStaffType { member, preApproved }

class UnifiedStaffItem {
  final UnifiedStaffType type;
  final String id;
  final String? uid;
  final String name;
  final String email;
  final String role; // 'admin', 'lead', 'employee'
  final String? departmentId;
  final String status; // 'active', 'code_pending', 'invited', 'pending_approval', 'revoked', 'rejected'
  final String? code;
  final DateTime? codeExpiresAt;
  final DateTime? createdAt;
  final String? avatarUrl;
  final Membership? rawMembership;
  final Map<String, dynamic>? rawPreApproved;

  const UnifiedStaffItem({
    required this.type,
    required this.id,
    this.uid,
    required this.name,
    required this.email,
    required this.role,
    this.departmentId,
    required this.status,
    this.code,
    this.codeExpiresAt,
    this.createdAt,
    this.avatarUrl,
    this.rawMembership,
    this.rawPreApproved,
  });
}

class OnboardingTab extends ConsumerStatefulWidget {
  final String? initialFilter;

  const OnboardingTab({
    super.key,
    this.initialFilter,
  });

  @override
  ConsumerState<OnboardingTab> createState() => _OnboardingTabState();
}

class _OnboardingTabState extends ConsumerState<OnboardingTab> {
  // Current tab filter: 'all', 'active', 'pending', 'revoked'
  late String _activeFilter;
  String _searchQuery = '';
  String? _selectedDeptFilter;

  // Multi-select for active staff bulk actions
  final Set<String> _selectedActiveUids = {};

  // Action loading tracker
  final Map<String, bool> _actionLoading = {};

  // Copy feedback state
  bool _copiedFirmId = false;
  bool _copiedInviteLink = false;
  final Set<String> _copiedCodes = {};

  // CSV Import Modal / Stepper State
  bool _showCsvStepper = false;
  int _csvStep = 0;
  List<Map<String, dynamic>> _csvParsedStaff = [];
  List<String> _csvMissingDepts = [];
  bool _csvAutoCreateDepts = true;
  bool _csvIsUploading = false;
  String? _csvErrorMessage;
  bool _isDraggingFile = false;

  @override
  void initState() {
    super.initState();
    _activeFilter = widget.initialFilter ?? 'all';
  }

  @override
  void didUpdateWidget(covariant OnboardingTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialFilter != null && widget.initialFilter != oldWidget.initialFilter) {
      setState(() {
        _activeFilter = widget.initialFilter!;
      });
    }
  }

  Color _hexToColor(String hexString, [Color fallback = const Color(0xFF295CB4)]) {
    try {
      String clean = hexString.toUpperCase().replaceAll('#', '');
      if (clean.length == 6) clean = 'FF$clean';
      if (clean.length == 8) {
        final val = int.tryParse(clean, radix: 16);
        if (val != null) return Color(val);
      }
    } catch (_) {}
    return fallback;
  }

  @override
  Widget build(BuildContext context) {
    final firm = ref.watch(currentFirmProvider);
    if (firm == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final primaryColor = _hexToColor(firm.primaryColor);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 800;

        return SingleChildScrollView(
          padding: EdgeInsets.all(isMobile ? 14 : 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Header: Quick Join / QR Code & Manual Firm ID
              _buildOnboardingHeaderCard(context, firm, primaryColor, isMobile),
              const SizedBox(height: 18),

              // 2. CSV Bulk Import Section (Collapsible Stepper)
              if (_showCsvStepper) ...[
                _buildCsvStepperCard(context, firm, primaryColor, isMobile),
                const SizedBox(height: 18),
              ],

              // 3. Unified Staff Management Hub
              _buildUnifiedStaffHub(context, firm, primaryColor, isMobile),
            ],
          ),
        );
      },
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // 1. ONBOARDING HEADER & QR CARD
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildOnboardingHeaderCard(
    BuildContext context,
    Firm firm,
    Color primaryColor,
    bool isMobile,
  ) {
    final firmId = firm.firmId;
    final inviteUri = 'https://officespace.chottu.link/?firmId=$firmId';

    return Material(
      color: const Color(0xFF1E1D1D),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.white.withOpacity(0.06)),
      ),
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 16 : 22),
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: primaryColor.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.qr_code_2_rounded, color: primaryColor, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Invite & Onboard Team Members',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Staff can onboard instantly using your Firm ID, QR code, or direct invite link.',
                      style: TextStyle(color: Colors.grey[400], fontSize: 13),
                    ),
                  ],
                ),
              ),
              if (!_showCsvStepper && !isMobile) ...[
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      _showCsvStepper = true;
                      _csvStep = 0;
                      _csvErrorMessage = null;
                      _csvParsedStaff = [];
                      _csvMissingDepts = [];
                    });
                  },
                  icon: const Icon(Icons.upload_file, size: 16),
                  label: const Text('Bulk Import CSV'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white.withOpacity(0.08),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ],
          ),
          if (!_showCsvStepper && isMobile) ...[
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  _showCsvStepper = true;
                  _csvStep = 0;
                  _csvErrorMessage = null;
                  _csvParsedStaff = [];
                  _csvMissingDepts = [];
                });
              },
              icon: const Icon(Icons.upload_file, size: 16),
              label: const Text('Bulk Import CSV'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white.withOpacity(0.08),
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
          const SizedBox(height: 18),
          Divider(color: Colors.white.withOpacity(0.06), height: 1),
          const SizedBox(height: 18),

          // Content: QR side-by-side with Manual code & links
          if (isMobile) ...[
            Center(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: SizedBox(
                  width: 150,
                  height: 150,
                  child: QrImageView(
                    data: inviteUri.isNotEmpty ? inviteUri : 'https://officespace.chottu.link',
                    size: 150,
                    eyeStyle: QrEyeStyle(eyeShape: QrEyeShape.square, color: primaryColor),
                    dataModuleStyle: QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: primaryColor),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            _buildJoinCodeBanner(firmId, inviteUri, primaryColor),
          ] else ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: SizedBox(
                    width: 130,
                    height: 130,
                    child: QrImageView(
                      data: inviteUri.isNotEmpty ? inviteUri : 'https://officespace.chottu.link',
                      size: 130,
                      eyeStyle: QrEyeStyle(eyeShape: QrEyeShape.square, color: primaryColor),
                      dataModuleStyle: QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: primaryColor),
                    ),
                  ),
                ),
                const SizedBox(width: 22),
                Expanded(
                  child: _buildJoinCodeBanner(firmId, inviteUri, primaryColor),
                ),
              ],
            ),
          ],
        ],
      ),
    ),
  );
  }

  Widget _buildJoinCodeBanner(String firmId, String inviteUri, Color primaryColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Firm ID Box
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF161515),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: primaryColor.withOpacity(0.35)),
          ),
          child: Row(
            children: [
              Icon(Icons.vpn_key_rounded, color: primaryColor, size: 20),
              const SizedBox(width: 12),
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
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              OutlinedButton.icon(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: firmId));
                  setState(() => _copiedFirmId = true);
                  SnackbarService().showSnackbar('Firm ID copied to clipboard!');
                  Future.delayed(const Duration(seconds: 2), () {
                    if (mounted) setState(() => _copiedFirmId = false);
                  });
                },
                icon: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: _copiedFirmId
                      ? const Icon(Icons.check, color: Colors.greenAccent, size: 16, key: ValueKey('c_id_ok'))
                      : Icon(Icons.copy, color: primaryColor, size: 16, key: const ValueKey('c_id_copy')),
                ),
                label: Text(
                  _copiedFirmId ? 'Copied' : 'Copy Code',
                  style: TextStyle(
                    color: _copiedFirmId ? Colors.greenAccent : primaryColor,
                    fontSize: 12,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: _copiedFirmId ? Colors.greenAccent : primaryColor.withOpacity(0.5)),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Action Buttons Row
        Wrap(
          spacing: 10,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: inviteUri));
                setState(() => _copiedInviteLink = true);
                SnackbarService().showSnackbar('Invite link copied!');
                Future.delayed(const Duration(seconds: 2), () {
                  if (mounted) setState(() => _copiedInviteLink = false);
                });
              },
              icon: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: _copiedInviteLink
                    ? const Icon(Icons.check, color: Colors.greenAccent, size: 16, key: ValueKey('c_link_ok'))
                    : const Icon(Icons.link, size: 16, key: ValueKey('c_link_copy')),
              ),
              label: Text(_copiedInviteLink ? 'Link Copied!' : 'Copy Direct Link'),
              style: OutlinedButton.styleFrom(
                foregroundColor: _copiedInviteLink ? Colors.greenAccent : Colors.white,
                side: BorderSide(
                  color: _copiedInviteLink ? Colors.greenAccent : Colors.white.withOpacity(0.2),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              ),
            ),
            if (!kIsWeb)
              ElevatedButton.icon(
                onPressed: () async {
                  await Share.share(
                    'Join our workspace on ProntoChat!\n\n'
                    'Link: $inviteUri\n'
                    'Manual Firm ID: $firmId',
                  );
                },
                icon: const Icon(Icons.share, size: 16),
                label: const Text('Share Invite'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
              ),
          ],
        ),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // 2. CSV BULK IMPORT STEPPER
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildCsvStepperCard(BuildContext context, Firm firm, Color primaryColor, bool isMobile) {
    return Material(
      color: const Color(0xFF1E1D1D),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: primaryColor.withOpacity(0.4)),
      ),
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 16 : 22),
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.badge_outlined, color: primaryColor, size: 20),
                  const SizedBox(width: 10),
                  const Text(
                    'CSV Bulk Onboarding Stepper',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.grey, size: 20),
                onPressed: () => setState(() => _showCsvStepper = false),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Stepper Header
          Row(
            children: [
              _buildStepIndicator(0, '1. Upload CSV', _csvStep == 0, _csvStep > 0, primaryColor),
              _buildStepDivider(_csvStep > 0, primaryColor),
              _buildStepIndicator(1, '2. Validate & Preview', _csvStep == 1, _csvStep > 1, primaryColor),
              _buildStepDivider(_csvStep > 1, primaryColor),
              _buildStepIndicator(2, '3. Confirm & Issue', _csvStep == 2, false, primaryColor),
            ],
          ),
          const SizedBox(height: 20),

          if (_csvErrorMessage != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.redAccent.withOpacity(0.5)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.redAccent, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _csvErrorMessage!,
                      style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Step 1: Upload CSV
          if (_csvStep == 0) _buildCsvStepUpload(context, firm, primaryColor),

          // Step 2: Validate & Preview
          if (_csvStep == 1) _buildCsvStepPreview(context, firm, primaryColor),

          // Step 3: Complete confirmation
          if (_csvStep == 2) _buildCsvStepComplete(context, firm, primaryColor),
        ],
      ),
    ),
  );
  }

  Widget _buildStepIndicator(int step, String label, bool isActive, bool isDone, Color primaryColor) {
    return Row(
      children: [
        Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isDone
                ? Colors.green
                : (isActive ? primaryColor : Colors.grey[800]),
          ),
          child: Center(
            child: isDone
                ? const Icon(Icons.check, size: 16, color: Colors.white)
                : Text(
                    '${step + 1}',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            color: isActive ? Colors.white : Colors.grey[400],
            fontSize: 12,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  Widget _buildStepDivider(bool isDone, Color primaryColor) {
    return Expanded(
      child: Container(
        height: 2,
        margin: const EdgeInsets.symmetric(horizontal: 10),
        color: isDone ? Colors.green : Colors.grey[800],
      ),
    );
  }

  Widget _buildCsvStepUpload(BuildContext context, Firm firm, Color primaryColor) {
    return DropTarget(
      onDragEntered: (_) => setState(() => _isDraggingFile = true),
      onDragExited: (_) => setState(() => _isDraggingFile = false),
      onDragDone: (details) async {
        setState(() => _isDraggingFile = false);
        if (details.files.isNotEmpty) {
          final file = details.files.first;
          if (file.name.toLowerCase().endsWith('.csv') || file.name.toLowerCase().endsWith('.txt')) {
            final bytes = await file.readAsBytes();
            _processCsvBytes(bytes, firm);
          } else {
            setState(() => _csvErrorMessage = 'Please drop a valid .csv file.');
          }
        }
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
        decoration: BoxDecoration(
          color: _isDraggingFile ? primaryColor.withOpacity(0.08) : const Color(0xFF161515),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _isDraggingFile ? primaryColor : Colors.white.withOpacity(0.12),
            width: 1.5,
          ),
        ),
        child: Column(
          children: [
            Icon(
              Icons.cloud_upload_outlined,
              size: 44,
              color: _isDraggingFile ? primaryColor : Colors.grey[400],
            ),
            const SizedBox(height: 12),
            const Text(
              'Drag and drop your CSV file here',
              style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              'Supported columns: Name, Email, Department (optional), Role (optional: employee/lead)',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[400], fontSize: 12),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () async {
                try {
                  setState(() => _csvErrorMessage = null);
                  final staffList = await CsvUploadService.instance.pickAndParseCsv();
                  if (staffList.isNotEmpty) {
                    await _validateAndTransitionParsedCsv(staffList, firm);
                  }
                } catch (e) {
                  setState(() => _csvErrorMessage = e.toString().replaceAll('Exception:', ''));
                }
              },
              icon: const Icon(Icons.folder_open, size: 16),
              label: const Text('Choose File from Computer'),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _processCsvBytes(Uint8List bytes, Firm firm) async {
    try {
      setState(() => _csvErrorMessage = null);
      // Fallback parsing via pickAndParseCsv logic or service
      // Let pickAndParseCsv run or trigger via standard flow
      final staffList = await CsvUploadService.instance.pickAndParseCsv();
      if (staffList.isNotEmpty) {
        await _validateAndTransitionParsedCsv(staffList, firm);
      }
    } catch (e) {
      setState(() => _csvErrorMessage = e.toString().replaceAll('Exception:', ''));
    }
  }

  Future<void> _validateAndTransitionParsedCsv(List<Map<String, dynamic>> staffList, Firm firm) async {
    // 1. Check departments
    final deptsSnapshot = await FirebaseFirestore.instance
        .collection('Firms')
        .doc(firm.firmId)
        .collection('departments')
        .get();

    final existingDeptNames = deptsSnapshot.docs
        .map((d) => (d.data()['name'] as String? ?? '').toLowerCase().trim())
        .toSet();

    final missing = <String>{};
    for (final s in staffList) {
      final dept = (s['department'] as String?)?.trim() ?? '';
      if (dept.isNotEmpty && !existingDeptNames.contains(dept.toLowerCase())) {
        missing.add(dept);
      }
    }

    setState(() {
      _csvParsedStaff = staffList;
      _csvMissingDepts = missing.toList();
      _csvStep = 1;
    });
  }

  Widget _buildCsvStepPreview(BuildContext context, Firm firm, Color primaryColor) {
    final seatCount = firm.seatCount;
    final seatLimit = firm.seatLimit;
    final willExceed = seatCount + _csvParsedStaff.length > seatLimit;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${_csvParsedStaff.length} Employees Parsed from CSV',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: willExceed ? Colors.red.withOpacity(0.2) : Colors.green.withOpacity(0.15),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: willExceed ? Colors.redAccent : Colors.greenAccent),
              ),
              child: Text(
                willExceed
                    ? '⚠️ Seat limit exceeded (${seatCount + _csvParsedStaff.length}/$seatLimit)'
                    : 'Seat check: $seatCount + ${_csvParsedStaff.length} of $seatLimit used',
                style: TextStyle(
                  color: willExceed ? Colors.redAccent : Colors.greenAccent,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        if (_csvMissingDepts.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.amber.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.amber.withOpacity(0.4)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: Colors.amber, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Found ${_csvMissingDepts.length} new departments in CSV: ${_csvMissingDepts.join(', ')}.',
                    style: const TextStyle(color: Colors.amber, fontSize: 12),
                  ),
                ),
                Checkbox(
                  value: _csvAutoCreateDepts,
                  activeColor: primaryColor,
                  onChanged: (val) => setState(() => _csvAutoCreateDepts = val ?? true),
                ),
                const Text('Auto-create', style: TextStyle(color: Colors.white, fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],

        // Table preview
        Container(
          height: 200,
          decoration: BoxDecoration(
            color: const Color(0xFF161515),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white.withOpacity(0.06)),
          ),
          child: ListView.separated(
            padding: const EdgeInsets.all(8),
            itemCount: _csvParsedStaff.length,
            separatorBuilder: (_, __) => Divider(color: Colors.white.withOpacity(0.04), height: 1),
            itemBuilder: (ctx, idx) {
              final item = _csvParsedStaff[idx];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 12,
                      backgroundColor: primaryColor.withOpacity(0.2),
                      child: Text(
                        (item['name'] as String? ?? 'S').substring(0, 1).toUpperCase(),
                        style: TextStyle(color: primaryColor, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: Text(
                        item['name'] ?? '',
                        style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: Text(
                        item['email'] ?? '',
                        style: TextStyle(color: Colors.grey[400], fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        (item['department'] as String?)?.isNotEmpty == true ? item['department'] : 'Unassigned',
                        style: TextStyle(color: Colors.grey[400], fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        (item['role'] as String? ?? 'employee').toUpperCase(),
                        style: const TextStyle(color: Colors.blueAccent, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 16),

        // Actions
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: () => setState(() => _csvStep = 0),
              child: const Text('Back', style: TextStyle(color: Colors.grey)),
            ),
            const SizedBox(width: 12),
            ElevatedButton(
              onPressed: willExceed || _csvIsUploading ? null : () => _executeCsvImport(context, firm),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              ),
              child: _csvIsUploading
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Confirm & Issue Codes'),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _executeCsvImport(BuildContext context, Firm firm) async {
    setState(() {
      _csvIsUploading = true;
      _csvErrorMessage = null;
    });

    try {
      final deptMap = <String, String>{};
      final deptsSnapshot = await FirebaseFirestore.instance
          .collection('Firms')
          .doc(firm.firmId)
          .collection('departments')
          .get();

      for (final doc in deptsSnapshot.docs) {
        final name = (doc.data()['name'] as String? ?? '').trim();
        deptMap[name] = doc.id;
      }

      if (_csvAutoCreateDepts) {
        for (final missingDept in _csvMissingDepts) {
          final newId = await DBService.instance.createDepartment(
            firmId: firm.firmId,
            name: missingDept,
          );
          deptMap[missingDept] = newId;
        }
      }

      await CsvUploadService.instance.uploadPreApprovedStaff(
        firm.firmId,
        _csvParsedStaff,
        departmentNameToIdMap: deptMap,
      );

      // Audit log
      await AuditService.instance.logAction(
        firmId: firm.firmId,
        action: 'bulk_csv_import',
        targetType: 'staff_list',
        targetId: firm.firmId,
        targetLabel: '${_csvParsedStaff.length} employees imported',
      );

      ref.read(firmNotifierProvider.notifier).loadFirm(firm.firmId);

      setState(() {
        _csvStep = 2;
        _csvIsUploading = false;
      });
      SnackbarService().showSnackbar('Successfully imported ${_csvParsedStaff.length} staff records!');
    } catch (e) {
      setState(() {
        _csvIsUploading = false;
        _csvErrorMessage = e.toString().replaceAll('Exception:', '');
      });
    }
  }

  Widget _buildCsvStepComplete(BuildContext context, Firm firm, Color primaryColor) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.greenAccent, size: 48),
            const SizedBox(height: 12),
            const Text(
              'Import Completed Successfully!',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              '${_csvParsedStaff.length} staff codes generated. They appear below with active 5-minute countdowns.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[400], fontSize: 13),
            ),
            const SizedBox(height: 18),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _showCsvStepper = false;
                  _csvParsedStaff = [];
                  _csvStep = 0;
                });
              },
              style: ElevatedButton.styleFrom(backgroundColor: primaryColor, foregroundColor: Colors.white),
              child: const Text('Return to Staff Table'),
            ),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // 3. UNIFIED STAFF MANAGEMENT HUB
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildUnifiedStaffHub(
    BuildContext context,
    Firm firm,
    Color primaryColor,
    bool isMobile,
  ) {
    return StreamBuilder<List<Department>>(
      stream: DBService.instance.streamDepartments(firm.firmId),
      builder: (context, deptSnapshot) {
        final departments = deptSnapshot.data ?? [];
        final Map<String, String> deptMap = {for (final d in departments) d.deptId: d.name};

        // Combine PreApprovedStaff and Members
        return StreamBuilder<List<Map<String, dynamic>>>(
          stream: DBService.instance.streamPreApprovedStaff(firm.firmId),
          builder: (context, preAuthSnap) {
            final preAuthList = preAuthSnap.data ?? [];

            return StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('Firms')
                  .doc(firm.firmId)
                  .collection('members')
                  .snapshots(),
              builder: (context, membersSnap) {
                if (preAuthSnap.connectionState == ConnectionState.waiting &&
                    membersSnap.connectionState == ConnectionState.waiting) {
                  return const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()));
                }

                final memberDocs = membersSnap.data?.docs ?? [];
                final List<UnifiedStaffItem> allStaffItems = [];

                // Track emails already represented in members
                final Set<String> activeMemberEmails = {};

                for (final doc in memberDocs) {
                  final data = doc.data() as Map<String, dynamic>;
                  final email = (data['email'] as String? ?? '').toLowerCase();
                  if (email.isNotEmpty) activeMemberEmails.add(email);

                  final rawStatus = data['status'] as String? ?? 'approved';
                  String mappedStatus = 'active';
                  if (rawStatus == 'pending') mappedStatus = 'pending_approval';
                  if (rawStatus == 'revoked') mappedStatus = 'revoked';
                  if (rawStatus == 'rejected') mappedStatus = 'rejected';

                  allStaffItems.add(UnifiedStaffItem(
                    type: UnifiedStaffType.member,
                    id: doc.id,
                    uid: data['uid'] as String? ?? doc.id,
                    name: (data['name'] as String?)?.isNotEmpty == true ? data['name'] : (email.isNotEmpty ? email : doc.id),
                    email: email,
                    role: data['role'] as String? ?? 'employee',
                    departmentId: data['departmentId'] as String?,
                    status: mappedStatus,
                    createdAt: (data['joinedAt'] as Timestamp?)?.toDate(),
                    avatarUrl: data['avatarUrl'] as String?,
                    rawMembership: Membership(
                      membershipId: doc.id,
                      uid: data['uid'] as String? ?? doc.id,
                      firmId: firm.firmId,
                      role: (data['role'] as String? ?? '') == 'admin'
                          ? MembershipRole.admin
                          : ((data['role'] as String? ?? '') == 'lead' ? MembershipRole.lead : MembershipRole.employee),
                      status: rawStatus == 'revoked'
                          ? MembershipStatus.revoked
                          : (rawStatus == 'pending'
                              ? MembershipStatus.pending
                              : (rawStatus == 'rejected' ? MembershipStatus.rejected : MembershipStatus.active)),
                      departmentId: data['departmentId'] as String?,
                    ),
                  ));
                }

                // Add Pre-Approved Staff (only if not already an active member)
                for (final p in preAuthList) {
                  final email = (p['email'] as String? ?? '').toLowerCase();
                  final pStatus = p['status'] as String? ?? 'invited';
                  if (pStatus == 'joined' && activeMemberEmails.contains(email)) {
                    continue; // Already shown in members list as Active
                  }

                  final exp = p['codeExpiresAt'];
                  DateTime? expDate;
                  if (exp is Timestamp) expDate = exp.toDate();

                  allStaffItems.add(UnifiedStaffItem(
                    type: UnifiedStaffType.preApproved,
                    id: p['id'] as String? ?? '',
                    name: p['name'] as String? ?? email,
                    email: email,
                    role: p['role'] as String? ?? 'employee',
                    departmentId: p['departmentId'] as String?,
                    status: 'code_pending',
                    code: p['code'] as String?,
                    codeExpiresAt: expDate,
                    createdAt: (p['createdAt'] as Timestamp?)?.toDate(),
                    rawPreApproved: p,
                  ));
                }

                // Apply Filters
                final filteredItems = allStaffItems.where((item) {
                  // Status filter
                  if (_activeFilter == 'active' && item.status != 'active') return false;
                  if (_activeFilter == 'pending' && item.status != 'code_pending' && item.status != 'pending_approval') {
                    return false;
                  }
                  if (_activeFilter == 'revoked' && item.status != 'revoked') return false;

                  // Department filter
                  if (_selectedDeptFilter != null && _selectedDeptFilter!.isNotEmpty) {
                    if (item.departmentId != _selectedDeptFilter) return false;
                  }

                  // Search query
                  if (_searchQuery.isNotEmpty) {
                    final q = _searchQuery.toLowerCase();
                    final matchName = item.name.toLowerCase().contains(q);
                    final matchEmail = item.email.toLowerCase().contains(q);
                    final matchCode = item.code?.toLowerCase().contains(q) ?? false;
                    if (!matchName && !matchEmail && !matchCode) return false;
                  }

                  return true;
                }).toList();

                return Material(
                  color: const Color(0xFF1E1D1D),
                  clipBehavior: Clip.antiAlias,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(color: Colors.white.withOpacity(0.06)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header & Filter bar
                      _buildStaffFilterBar(
                        context,
                        firm,
                        primaryColor,
                        departments,
                        allStaffItems,
                        isMobile,
                      ),

                      // Bulk Action Banner (when active rows are checked)
                      if (_selectedActiveUids.isNotEmpty)
                        _buildBulkActionToolbar(firm.firmId, departments, primaryColor),

                      // Content: Responsive DataTable2 or Card list
                      if (filteredItems.isEmpty)
                        _buildEmptyStaffState()
                      else if (isMobile)
                        _buildMobileStaffList(context, firm, primaryColor, filteredItems, deptMap, departments)
                      else
                        _buildDesktopStaffTable(context, firm, primaryColor, filteredItems, deptMap, departments),
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

  // ══════════════════════════════════════════════════════════════════════════
  // FILTER BAR & EMPTY STATE
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildStaffFilterBar(
    BuildContext context,
    Firm firm,
    Color primaryColor,
    List<Department> departments,
    List<UnifiedStaffItem> allItems,
    bool isMobile,
  ) {
    final activeCount = allItems.where((i) => i.status == 'active').length;
    final pendingCount = allItems.where((i) => i.status == 'code_pending' || i.status == 'pending_approval').length;
    final revokedCount = allItems.where((i) => i.status == 'revoked').length;

    final seatCount = firm.seatCount;
    final seatLimit = firm.seatLimit;
    final isLimitReached = seatCount >= seatLimit;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Staff Directory & Access',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: isLimitReached
                    ? () {
                        SnackbarService().showSnackbar(
                          'Seat limit of $seatLimit reached. Remove unjoined codes or upgrade plan to add staff.',
                          isError: true,
                        );
                      }
                    : () => _showAddPreApprovedStaffDialog(context, firm.firmId, departments),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add Staff Code'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isLimitReached ? Colors.grey[700] : primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Filters row: Status tabs + Search box + Dept dropdown
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _buildFilterChip('all', 'All (${allItems.length})', primaryColor),
              _buildFilterChip('active', 'Active ($activeCount)', primaryColor),
              _buildFilterChip('pending', 'Pending ($pendingCount)', primaryColor),
              _buildFilterChip('revoked', 'Revoked ($revokedCount)', primaryColor),

              const SizedBox(width: 8),

              // Search field
              SizedBox(
                width: 200,
                height: 36,
                child: TextField(
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Search name, email...',
                    hintStyle: TextStyle(color: Colors.grey[500], fontSize: 12),
                    prefixIcon: const Icon(Icons.search, size: 16, color: Colors.grey),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 10),
                    filled: true,
                    fillColor: const Color(0xFF161515),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
                    ),
                  ),
                  onChanged: (val) => setState(() => _searchQuery = val.trim()),
                ),
              ),

              // Department dropdown filter
              SizedBox(
                width: 170,
                height: 36,
                child: DropdownButtonFormField<String?>(
                  value: _selectedDeptFilter,
                  dropdownColor: const Color(0xFF222121),
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                    filled: true,
                    fillColor: const Color(0xFF161515),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
                    ),
                  ),
                  hint: Text('All Departments', style: TextStyle(color: Colors.grey[400], fontSize: 12)),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('All Departments', style: TextStyle(fontSize: 12)),
                    ),
                    ...departments.map((d) => DropdownMenuItem<String?>(
                          value: d.deptId,
                          child: Text(d.name, style: const TextStyle(fontSize: 12)),
                        )),
                  ],
                  onChanged: (val) => setState(() => _selectedDeptFilter = val),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String filterId, String label, Color primaryColor) {
    final isSelected = _activeFilter == filterId;
    return InkWell(
      onTap: () => setState(() => _activeFilter = filterId),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? primaryColor.withOpacity(0.18) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? primaryColor : Colors.white.withOpacity(0.12),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey[400],
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildBulkActionToolbar(String firmId, List<Department> departments, Color primaryColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: primaryColor.withOpacity(0.14),
      child: Row(
        children: [
          Text(
            '${_selectedActiveUids.length} staff selected',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
          ),
          const Spacer(),
          TextButton.icon(
            icon: const Icon(Icons.corporate_fare, size: 16),
            label: const Text('Bulk Assign Dept'),
            style: TextButton.styleFrom(foregroundColor: Colors.white),
            onPressed: () => _showBulkAssignDeptDialog(context, firmId, _selectedActiveUids.toList(), departments),
          ),
          const SizedBox(width: 8),
          TextButton.icon(
            icon: const Icon(Icons.shield_outlined, size: 16),
            label: const Text('Bulk Set Role'),
            style: TextButton.styleFrom(foregroundColor: Colors.white),
            onPressed: () => _showBulkSetRoleDialog(context, firmId, _selectedActiveUids.toList()),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.close, size: 18, color: Colors.grey),
            tooltip: 'Clear selection',
            onPressed: () => setState(() => _selectedActiveUids.clear()),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyStaffState() {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.people_outline, size: 48, color: Colors.grey[600]),
            const SizedBox(height: 12),
            const Text(
              'No staff members match the selected filter',
              style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              'Adjust the filter or add new staff codes to invite teammates.',
              style: TextStyle(color: Colors.grey[400], fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // DESKTOP DATA TABLE 2
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildDesktopStaffTable(
    BuildContext context,
    Firm firm,
    Color primaryColor,
    List<UnifiedStaffItem> items,
    Map<String, String> deptMap,
    List<Department> departments,
  ) {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minWidth: constraints.maxWidth < 900 ? 900 : constraints.maxWidth,
            ),
            child: DataTable(
              columnSpacing: 20,
              horizontalMargin: 16,
              dataRowMinHeight: 52,
              dataRowMaxHeight: 64,
              headingRowColor: MaterialStateProperty.all(const Color(0xFF161515)),
              headingTextStyle: TextStyle(
                color: Colors.grey[400],
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
              columns: const [
                DataColumn(label: Text('EMPLOYEE')),
                DataColumn(label: Text('DEPARTMENT')),
                DataColumn(label: Text('ROLE')),
                DataColumn(label: Text('STATUS / CODE')),
                DataColumn(label: Text('ACTIONS')),
              ],
              rows: items.map((item) {
                final isSelf = currentUid != null && item.uid == currentUid;
                final deptName = item.departmentId != null ? deptMap[item.departmentId] : null;
                final isSelected = item.uid != null && _selectedActiveUids.contains(item.uid);

                return DataRow(
                  selected: isSelected,
                  onSelectChanged: (item.status == 'active' && !isSelf && item.uid != null)
                      ? (checked) {
                          setState(() {
                            if (checked == true) {
                              _selectedActiveUids.add(item.uid!);
                            } else {
                              _selectedActiveUids.remove(item.uid);
                            }
                          });
                        }
                      : null,
                  cells: [
                    // 1. Employee Name & Email
                    DataCell(
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircleAvatar(
                              radius: 15,
                              backgroundColor: primaryColor.withOpacity(0.18),
                              backgroundImage: item.avatarUrl != null ? NetworkImage(item.avatarUrl!) : null,
                              child: item.avatarUrl == null
                                  ? Text(
                                      item.name.isNotEmpty ? item.name[0].toUpperCase() : '?',
                                      style: TextStyle(color: primaryColor, fontSize: 12, fontWeight: FontWeight.bold),
                                    )
                                  : null,
                            ),
                            const SizedBox(width: 10),
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      item.name,
                                      style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                                    ),
                                    if (isSelf) ...[
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                        decoration: BoxDecoration(
                                          color: Colors.blue.withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: const Text('YOU', style: TextStyle(color: Colors.blueAccent, fontSize: 9, fontWeight: FontWeight.bold)),
                                      ),
                                    ],
                                  ],
                                ),
                                Text(
                                  item.email,
                                  style: TextStyle(color: Colors.grey[400], fontSize: 11),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                    // 2. Department
                    DataCell(
                      Text(
                        deptName ?? 'Unassigned',
                        style: TextStyle(color: deptName != null ? Colors.white : Colors.grey[500], fontSize: 12),
                      ),
                    ),

                    // 3. Role
                    DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: item.role == 'admin'
                              ? Colors.blue.withOpacity(0.18)
                              : (item.role == 'lead' ? Colors.purple.withOpacity(0.18) : Colors.grey.withOpacity(0.15)),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          item.role.toUpperCase(),
                          style: TextStyle(
                            color: item.role == 'admin'
                                ? Colors.blueAccent
                                : (item.role == 'lead' ? Colors.purpleAccent : Colors.grey[400]),
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),

                    // 4. Status / Visual Countdown Ring for codes
                    DataCell(
                      _buildStatusCell(context, item, firm.firmId, primaryColor),
                    ),

                    // 5. Action buttons / Menu
                    DataCell(
                      _buildRowActions(context, item, firm.firmId, primaryColor, departments),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // MOBILE CARD VIEW
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildMobileStaffList(
    BuildContext context,
    Firm firm,
    Color primaryColor,
    List<UnifiedStaffItem> items,
    Map<String, String> deptMap,
    List<Department> departments,
  ) {
    return Material(
      color: Colors.transparent,
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(12),
        itemCount: items.length,
        separatorBuilder: (_, __) => Divider(color: Colors.white.withOpacity(0.04), height: 1),
        itemBuilder: (ctx, idx) {
          final item = items[idx];
          final deptName = item.departmentId != null ? deptMap[item.departmentId] : null;

          return ListTile(
            contentPadding: const EdgeInsets.symmetric(vertical: 4),
            leading: CircleAvatar(
              backgroundColor: primaryColor.withOpacity(0.18),
              child: Text(
                item.name.isNotEmpty ? item.name[0].toUpperCase() : '?',
                style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold),
              ),
            ),
            title: Row(
              children: [
                Flexible(
                  child: Text(
                    item.name,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: item.role == 'lead' ? Colors.purple.withOpacity(0.2) : Colors.grey.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    item.role.toUpperCase(),
                    style: TextStyle(
                      color: item.role == 'lead' ? Colors.purpleAccent : Colors.grey[400],
                      fontSize: 9,
                    ),
                  ),
                ),
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.email, style: TextStyle(color: Colors.grey[400], fontSize: 12)),
                const SizedBox(height: 3),
                Text('Dept: ${deptName ?? "None"}', style: TextStyle(color: Colors.grey[500], fontSize: 11)),
                const SizedBox(height: 6),
                _buildStatusCell(context, item, firm.firmId, primaryColor),
              ],
            ),
            trailing: _buildRowActions(context, item, firm.firmId, primaryColor, departments),
          );
        },
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // STATUS CELL & VISUAL 5-MINUTE COUNTDOWN RING
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildStatusCell(
    BuildContext context,
    UnifiedStaffItem item,
    String firmId,
    Color primaryColor,
  ) {
    if (item.status == 'active') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.green.withOpacity(0.15),
          borderRadius: BorderRadius.circular(4),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle, size: 12, color: Colors.greenAccent),
            SizedBox(width: 4),
            Text('Active', style: TextStyle(color: Colors.greenAccent, fontSize: 11, fontWeight: FontWeight.bold)),
          ],
        ),
      );
    }

    if (item.status == 'revoked') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.15),
          borderRadius: BorderRadius.circular(4),
        ),
        child: const Text('Revoked', style: TextStyle(color: Colors.redAccent, fontSize: 11, fontWeight: FontWeight.bold)),
      );
    }

    if (item.status == 'pending_approval') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.orange.withOpacity(0.15),
          borderRadius: BorderRadius.circular(4),
        ),
        child: const Text('Pending Approval', style: TextStyle(color: Colors.orangeAccent, fontSize: 11, fontWeight: FontWeight.bold)),
      );
    }

    // Code Pending: Visual 5-minute Countdown Ring
    if (item.status == 'code_pending' && item.code != null) {
      return _StaffCodeCountdownRing(
        firmId: firmId,
        staffId: item.id,
        email: item.email,
        code: item.code!,
        expiresAt: item.codeExpiresAt,
        primaryColor: primaryColor,
        onCopyFeedback: () {
          setState(() => _copiedCodes.add(item.id));
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted) setState(() => _copiedCodes.remove(item.id));
          });
        },
        hasCopied: _copiedCodes.contains(item.id),
      );
    }

    return Text(item.status, style: TextStyle(color: Colors.grey[400], fontSize: 12));
  }

  // ══════════════════════════════════════════════════════════════════════════
  // ROW ACTIONS & OFFBOARDING CHECKLIST
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildRowActions(
    BuildContext context,
    UnifiedStaffItem item,
    String firmId,
    Color primaryColor,
    List<Department> departments,
  ) {
    final isActionActive = _actionLoading[item.id] == true;
    if (isActionActive) {
      return const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2));
    }

    // Pre-Approved / Code Pending: Remove option
    if (item.type == UnifiedStaffType.preApproved) {
      return IconButton(
        icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 18),
        tooltip: 'Remove Invite',
        onPressed: () => _confirmRemovePreApproved(context, firmId, item),
      );
    }

    // Pending Approval: Approve / Reject buttons
    if (item.status == 'pending_approval') {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.close, color: Colors.redAccent, size: 18),
            tooltip: 'Reject',
            onPressed: () => _rejectMembership(context, firmId, item),
          ),
          IconButton(
            icon: const Icon(Icons.check, color: Colors.greenAccent, size: 18),
            tooltip: 'Approve',
            onPressed: () => _approveMembership(context, firmId, item),
          ),
        ],
      );
    }

    // Revoked: Restore option
    if (item.status == 'revoked') {
      return ElevatedButton.icon(
        onPressed: () => _restoreMembership(context, firmId, item),
        icon: const Icon(Icons.restore, size: 14),
        label: const Text('Restore', style: TextStyle(fontSize: 11)),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green[700],
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        ),
      );
    }

    // Active Staff: Menu with Assign Dept, Change Role, Revoke (with offboarding checklist)
    if (item.status == 'active' && item.role != 'admin') {
      return PopupMenuButton<String>(
        icon: const Icon(Icons.more_vert, color: Colors.grey, size: 18),
        color: const Color(0xFF222121),
        onSelected: (action) {
          if (action == 'dept') {
            _showAssignMemberDeptDialog(context, firmId, item, departments);
          } else if (action == 'role') {
            _showChangeMemberRoleDialog(context, firmId, item);
          } else if (action == 'revoke') {
            _showOffboardingChecklistAndRevoke(context, firmId, item);
          }
        },
        itemBuilder: (ctx) => [
          const PopupMenuItem(
            value: 'dept',
            child: Row(
              children: [
                Icon(Icons.corporate_fare, size: 16, color: Colors.white),
                SizedBox(width: 8),
                Text('Assign Department', style: TextStyle(color: Colors.white, fontSize: 13)),
              ],
            ),
          ),
          PopupMenuItem(
            value: 'role',
            child: Row(
              children: [
                const Icon(Icons.shield_outlined, size: 16, color: Colors.white),
                const SizedBox(width: 8),
                Text(item.role == 'lead' ? 'Demote to Employee' : 'Promote to Lead',
                    style: const TextStyle(color: Colors.white, fontSize: 13)),
              ],
            ),
          ),
          const PopupMenuDivider(),
          const PopupMenuItem(
            value: 'revoke',
            child: Row(
              children: [
                Icon(Icons.block, color: Colors.redAccent, size: 16),
                SizedBox(width: 8),
                Text('Revoke Access', style: TextStyle(color: Colors.redAccent, fontSize: 13)),
              ],
            ),
          ),
        ],
      );
    }

    return const SizedBox(width: 24);
  }

  // ══════════════════════════════════════════════════════════════════════════
  // OFFBOARDING CHECKLIST DIALOG (PRE-REVOKE VERIFICATION)
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> _showOffboardingChecklistAndRevoke(
    BuildContext context,
    String firmId,
    UnifiedStaffItem item,
  ) async {
    final uid = item.uid;
    if (uid == null) return;

    // Check 1: Is member Department Head?
    final deptsSnap = await FirebaseFirestore.instance
        .collection('Firms')
        .doc(firmId)
        .collection('departments')
        .where('headUid', isEqualTo: uid)
        .where('status', isEqualTo: 'active')
        .get();

    final headedDeptNames = deptsSnap.docs.map((d) => d.data()['name'] as String? ?? 'Dept').toList();

    // Check 2: Is member Owner of any Project Group?
    final projectsSnap = await FirebaseFirestore.instance
        .collection('Firms')
        .doc(firmId)
        .collection('projects')
        .where('ownerUid', isEqualTo: uid)
        .where('status', isEqualTo: 'active')
        .get();

    final ownedProjectNames = projectsSnap.docs.map((p) => p.data()['name'] as String? ?? 'Project').toList();

    final hasLeadershipRoles = headedDeptNames.isNotEmpty || ownedProjectNames.isNotEmpty;

    if (!context.mounted) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF222121),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(
              hasLeadershipRoles ? Icons.warning_amber_rounded : Icons.block,
              color: hasLeadershipRoles ? Colors.amber : Colors.redAccent,
              size: 22,
            ),
            const SizedBox(width: 10),
            Text(
              hasLeadershipRoles ? 'Offboarding Leadership Warning' : 'Revoke Workspace Access?',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Revoking access for ${item.name} (${item.email}) will immediately prevent them from logging in.',
              style: TextStyle(color: Colors.grey[300], fontSize: 13),
            ),
            if (hasLeadershipRoles) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.amber.withOpacity(0.4)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '⚠️ Active Responsibilities Detected:',
                      style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                    const SizedBox(height: 6),
                    if (headedDeptNames.isNotEmpty)
                      Text(
                        '• Department Head of: ${headedDeptNames.join(", ")}',
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    if (ownedProjectNames.isNotEmpty)
                      Text(
                        '• Owner of Project Group(s): ${ownedProjectNames.join(", ")}',
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    const SizedBox(height: 8),
                    Text(
                      'Revoking now will leave these areas without a leader. Consider reassigning their roles first in the Notices & Groups tab.',
                      style: TextStyle(color: Colors.grey[400], fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red[700]),
            child: const Text('Revoke Access'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _actionLoading[item.id] = true);
      try {
        await DBService.instance.updateMembershipStatus(item.id, 'revoked');

        // Audit log
        await AuditService.instance.logAction(
          firmId: firmId,
          action: 'revoke_staff',
          targetType: 'membership',
          targetId: item.id,
          targetLabel: '${item.name} (${item.email})',
        );

        SnackbarService().showSnackbar('${item.name} access revoked.');
      } catch (e) {
        SnackbarService().showSnackbar('Error revoking member: $e', isError: true);
      } finally {
        if (mounted) setState(() => _actionLoading[item.id] = false);
      }
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // ROLE, DEPT, REMOVE, APPROVE & REJECT HANDLERS
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> _approveMembership(BuildContext context, String firmId, UnifiedStaffItem item) async {
    setState(() => _actionLoading[item.id] = true);
    try {
      await DBService.instance.updateMembershipStatus(item.id, 'approved');
      await AuditService.instance.logAction(
        firmId: firmId,
        action: 'approve_staff',
        targetType: 'membership',
        targetId: item.id,
        targetLabel: '${item.name} (${item.email})',
      );
      SnackbarService().showSnackbar('${item.name} approved!');
    } catch (e) {
      SnackbarService().showSnackbar('Error approving: $e', isError: true);
    } finally {
      if (mounted) setState(() => _actionLoading[item.id] = false);
    }
  }

  Future<void> _rejectMembership(BuildContext context, String firmId, UnifiedStaffItem item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF222121),
        title: const Text('Reject Access Request?'),
        content: Text('Reject access request for ${item.name}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
            child: const Text('Reject'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _actionLoading[item.id] = true);
    try {
      await DBService.instance.updateMembershipStatus(item.id, 'rejected');
      await AuditService.instance.logAction(
        firmId: firmId,
        action: 'reject_staff',
        targetType: 'membership',
        targetId: item.id,
        targetLabel: '${item.name} (${item.email})',
      );
      SnackbarService().showSnackbar('${item.name} request rejected.');
    } catch (e) {
      SnackbarService().showSnackbar('Error rejecting: $e', isError: true);
    } finally {
      if (mounted) setState(() => _actionLoading[item.id] = false);
    }
  }

  Future<void> _restoreMembership(BuildContext context, String firmId, UnifiedStaffItem item) async {
    setState(() => _actionLoading[item.id] = true);
    try {
      await DBService.instance.updateMembershipStatus(item.id, 'approved');
      await AuditService.instance.logAction(
        firmId: firmId,
        action: 'restore_staff',
        targetType: 'membership',
        targetId: item.id,
        targetLabel: '${item.name} (${item.email})',
      );
      SnackbarService().showSnackbar('${item.name} access restored.');
    } catch (e) {
      SnackbarService().showSnackbar('Error restoring: $e', isError: true);
    } finally {
      if (mounted) setState(() => _actionLoading[item.id] = false);
    }
  }

  Future<void> _confirmRemovePreApproved(BuildContext context, String firmId, UnifiedStaffItem item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF222121),
        title: const Text('Remove Pre-Authorized Staff?'),
        content: Text('Remove ${item.email} from pre-approved staff? This frees 1 trial seat.'),
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
      try {
        await DBService.instance.removePreApprovedStaff(
          firmId: firmId,
          staffDocId: item.id,
        );
        await AuditService.instance.logAction(
          firmId: firmId,
          action: 'remove_invite',
          targetType: 'pre_approved',
          targetId: item.id,
          targetLabel: item.email,
        );
        ref.read(firmNotifierProvider.notifier).loadFirm(firmId);
        SnackbarService().showSnackbar('Removed ${item.email}. 1 seat returned.');
      } catch (e) {
        SnackbarService().showSnackbar('Error removing: $e', isError: true);
      }
    }
  }

  Future<void> _showAssignMemberDeptDialog(
    BuildContext context,
    String firmId,
    UnifiedStaffItem item,
    List<Department> departments,
  ) async {
    String? selectedDeptId = item.departmentId;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF222121),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Assign Department: ${item.name}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String?>(
                value: selectedDeptId,
                dropdownColor: const Color(0xFF222121),
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Department',
                  filled: true,
                  fillColor: const Color(0xFF161515),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                items: [
                  const DropdownMenuItem<String?>(value: null, child: Text('None (Unassigned)')),
                  ...departments.where((d) => d.isActive).map(
                        (d) => DropdownMenuItem<String?>(value: d.deptId, child: Text(d.name)),
                      ),
                ],
                onChanged: (val) => setDialogState(() => selectedDeptId = val),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                try {
                  await DBService.instance.assignMemberDepartment(firmId, item.uid!, selectedDeptId);
                  await AuditService.instance.logAction(
                    firmId: firmId,
                    action: 'assign_department',
                    targetType: 'membership',
                    targetId: item.id,
                    targetLabel: '${item.name} -> ${selectedDeptId ?? "None"}',
                  );
                  SnackbarService().showSnackbar('Department updated.');
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

  Future<void> _showChangeMemberRoleDialog(BuildContext context, String firmId, UnifiedStaffItem item) async {
    final newRole = item.role == 'lead' ? MembershipRole.employee : MembershipRole.lead;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF222121),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(newRole == MembershipRole.lead ? 'Promote to Lead?' : 'Demote to Employee?'),
        content: Text(
          newRole == MembershipRole.lead
              ? 'Promoting ${item.name} to Lead grants permissions to create/manage project groups and post in #all-staff.'
              : 'Demoting ${item.name} to Employee will remove their permissions to create project groups.',
          style: const TextStyle(color: Colors.grey, fontSize: 13),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: newRole == MembershipRole.lead ? Colors.purple : Colors.blueGrey),
            child: Text(newRole == MembershipRole.lead ? 'Promote to Lead' : 'Demote to Employee'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await DBService.instance.updateMemberRole(firmId, item.uid!, newRole);
        await AuditService.instance.logAction(
          firmId: firmId,
          action: 'change_role',
          targetType: 'membership',
          targetId: item.id,
          targetLabel: '${item.name} -> ${newRole.name}',
        );
        SnackbarService().showSnackbar('Updated role to ${newRole.name.toUpperCase()}.');
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
    String? targetDeptId;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF222121),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Bulk Assign Department (${memberIds.length} staff)'),
          content: DropdownButtonFormField<String?>(
            value: targetDeptId,
            dropdownColor: const Color(0xFF222121),
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'Target Department',
              filled: true,
              fillColor: const Color(0xFF161515),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
            items: [
              const DropdownMenuItem<String?>(value: null, child: Text('None (Remove Department)')),
              ...departments.where((d) => d.isActive).map(
                    (d) => DropdownMenuItem<String?>(value: d.deptId, child: Text(d.name)),
                  ),
            ],
            onChanged: (val) => setDialogState(() => targetDeptId = val),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                try {
                  await DBService.instance.bulkAssignDepartment(firmId, memberIds, targetDeptId);
                  await AuditService.instance.logAction(
                    firmId: firmId,
                    action: 'bulk_assign_dept',
                    targetType: 'membership_list',
                    targetId: firmId,
                    targetLabel: '${memberIds.length} members assigned to ${targetDeptId ?? "None"}',
                  );
                  setState(() => _selectedActiveUids.clear());
                  SnackbarService().showSnackbar('Bulk assigned ${memberIds.length} members.');
                } catch (e) {
                  SnackbarService().showSnackbar('Error in bulk assignment: $e', isError: true);
                }
              },
              child: const Text('Apply to All Selected'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showBulkSetRoleDialog(BuildContext context, String firmId, List<String> memberIds) async {
    MembershipRole targetRole = MembershipRole.lead;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF222121),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Bulk Set Role (${memberIds.length} staff)'),
          content: DropdownButtonFormField<MembershipRole>(
            value: targetRole,
            dropdownColor: const Color(0xFF222121),
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'Target Role',
              filled: true,
              fillColor: const Color(0xFF161515),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
            items: const [
              DropdownMenuItem(value: MembershipRole.lead, child: Text('Lead (Manage Groups & #all-staff)', style: TextStyle(color: Colors.purpleAccent))),
              DropdownMenuItem(value: MembershipRole.employee, child: Text('Employee (Standard Member)')),
            ],
            onChanged: (val) {
              if (val != null) setDialogState(() => targetRole = val);
            },
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                try {
                  await DBService.instance.bulkUpdateRoles(firmId, memberIds, targetRole);
                  await AuditService.instance.logAction(
                    firmId: firmId,
                    action: 'bulk_set_role',
                    targetType: 'membership_list',
                    targetId: firmId,
                    targetLabel: '${memberIds.length} members set to ${targetRole.name}',
                  );
                  setState(() => _selectedActiveUids.clear());
                  SnackbarService().showSnackbar('Bulk updated ${memberIds.length} roles to ${targetRole.name}.');
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

  void _showAddPreApprovedStaffDialog(BuildContext context, String firmId, List<Department> departments) {
    final emailController = TextEditingController();
    final nameController = TextEditingController();
    MembershipRole selectedRole = MembershipRole.employee;
    String? selectedDeptId;

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF222121),
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
                    filled: true,
                    fillColor: const Color(0xFF161515),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: emailController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Employee Email',
                    hintText: 'name@company.com',
                    filled: true,
                    fillColor: const Color(0xFF161515),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<MembershipRole>(
                  value: selectedRole,
                  dropdownColor: const Color(0xFF222121),
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Initial Role',
                    filled: true,
                    fillColor: const Color(0xFF161515),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  items: const [
                    DropdownMenuItem(value: MembershipRole.employee, child: Text('Employee (Standard)')),
                    DropdownMenuItem(value: MembershipRole.lead, child: Text('Lead (Manage Groups)', style: TextStyle(color: Colors.purpleAccent))),
                  ],
                  onChanged: (val) {
                    if (val != null) setDialogState(() => selectedRole = val);
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String?>(
                  value: selectedDeptId,
                  dropdownColor: const Color(0xFF222121),
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Department (Optional)',
                    filled: true,
                    fillColor: const Color(0xFF161515),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  items: [
                    const DropdownMenuItem<String?>(value: null, child: Text('None (Unassigned)')),
                    ...departments.where((d) => d.isActive).map(
                          (d) => DropdownMenuItem<String?>(value: d.deptId, child: Text(d.name)),
                        ),
                  ],
                  onChanged: (val) => setDialogState(() => selectedDeptId = val),
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
                  await AuditService.instance.logAction(
                    firmId: firmId,
                    action: 'add_pre_approved_staff',
                    targetType: 'pre_approved',
                    targetId: firmId,
                    targetLabel: '$name ($email) [Code: $issuedCode]',
                  );
                  ref.read(firmNotifierProvider.notifier).loadFirm(firmId);
                  SnackbarService().showSnackbar('Added $email! Code: $issuedCode (valid for 5 mins)');
                } catch (e) {
                  SnackbarService().showSnackbar('Error: ${e.toString().replaceAll('Exception:', '')}', isError: true);
                }
              },
              child: const Text('Save & Issue Code'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Visual 5-Minute Staff Code Countdown Ring Widget
/// Replaces the old spinner with an animated circular progress ring,
/// showing minutes and seconds remaining, warning color threshold (<60s),
/// manual reset button, and automatic 5-minute code rollover with 10-second debounce.
class _StaffCodeCountdownRing extends StatefulWidget {
  final String firmId;
  final String staffId;
  final String email;
  final String code;
  final DateTime? expiresAt;
  final Color primaryColor;
  final VoidCallback onCopyFeedback;
  final bool hasCopied;

  const _StaffCodeCountdownRing({
    required this.firmId,
    required this.staffId,
    required this.email,
    required this.code,
    required this.expiresAt,
    required this.primaryColor,
    required this.onCopyFeedback,
    required this.hasCopied,
  });

  @override
  State<_StaffCodeCountdownRing> createState() => _StaffCodeCountdownRingState();
}

class _StaffCodeCountdownRingState extends State<_StaffCodeCountdownRing> {
  Timer? _ticker;
  bool _isResetting = false;
  DateTime? _lastAutoResetAttempt;

  @override
  void initState() {
    super.initState();
    _startTicker();
  }

  @override
  void didUpdateWidget(covariant _StaffCodeCountdownRing oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.expiresAt != oldWidget.expiresAt) {
      _startTicker();
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      _tick();
    });
  }

  int get _remainingSeconds {
    if (widget.expiresAt == null) return 0;
    final diff = widget.expiresAt!.difference(DateTime.now()).inSeconds;
    return diff > 0 ? diff : 0;
  }

  void _tick() {
    final remaining = _remainingSeconds;
    setState(() {});

    if (remaining <= 0 && !_isResetting) {
      final now = DateTime.now();
      if (_lastAutoResetAttempt == null || now.difference(_lastAutoResetAttempt!).inSeconds >= 10) {
        _lastAutoResetAttempt = now;
        _triggerReset(isManual: false);
      }
    }
  }

  Future<void> _triggerReset({required bool isManual}) async {
    if (_isResetting || !mounted) return;
    setState(() => _isResetting = true);

    try {
      final newCode = await DBService.instance.resetStaffCode(
        firmId: widget.firmId,
        staffDocId: widget.staffId,
      );
      if (mounted && isManual) {
        SnackbarService().showSnackbar('New code for ${widget.email}: $newCode (valid for 5 mins)');
      }
    } catch (e) {
      if (mounted && isManual) {
        SnackbarService().showSnackbar('Failed to reset code: $e', isError: true);
      }
    } finally {
      if (mounted) setState(() => _isResetting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final remaining = _remainingSeconds;
    // Total 5 minutes = 300 seconds
    final progress = (remaining / 300.0).clamp(0.0, 1.0);

    Color ringColor = Colors.greenAccent;
    if (remaining < 60) {
      ringColor = Colors.redAccent;
    } else if (remaining < 120) {
      ringColor = Colors.orangeAccent;
    }

    final mm = remaining ~/ 60;
    final ss = (remaining % 60).toString().padLeft(2, '0');

    return Wrap(
      spacing: 6,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        // Code Pill
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: const Color(0xFF161515),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.code,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(width: 4),
              InkWell(
                onTap: () async {
                  await Clipboard.setData(ClipboardData(text: widget.code));
                  widget.onCopyFeedback();
                  SnackbarService().showSnackbar('Code ${widget.code} copied!');
                },
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: widget.hasCopied
                      ? const Icon(Icons.check, size: 14, color: Colors.greenAccent, key: ValueKey('c_ok'))
                      : const Icon(Icons.copy, size: 14, color: Colors.grey, key: ValueKey('c_copy')),
                ),
              ),
            ],
          ),
        ),

        // Visual Countdown Ring (Stack with CircularProgressIndicator)
        SizedBox(
          width: 26,
          height: 26,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CircularProgressIndicator(
                value: _isResetting ? null : progress,
                strokeWidth: 2.5,
                backgroundColor: Colors.white.withOpacity(0.06),
                valueColor: AlwaysStoppedAnimation<Color>(ringColor),
              ),
              if (!_isResetting)
                Text(
                  '$mm',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: ringColor,
                  ),
                ),
            ],
          ),
        ),

        // Time Text
        Text(
          _isResetting ? 'Resetting...' : '$mm:$ss',
          style: TextStyle(
            color: ringColor,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),

        // Manual Refresh Button
        if (_isResetting)
          const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
        else
          IconButton(
            icon: const Icon(Icons.refresh, size: 16, color: Colors.blueAccent),
            tooltip: 'Reset code manually',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: () => _triggerReset(isManual: true),
          ),
      ],
    );
  }
}
