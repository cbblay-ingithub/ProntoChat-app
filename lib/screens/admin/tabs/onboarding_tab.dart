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
import '../../../theme/pc_tokens.dart';

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
  final String
      status; // 'active', 'code_pending', 'invited', 'pending_approval', 'revoked', 'rejected'
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
  static const Color _emerald = Color(0xFF059669);

  late String _activeFilter;
  String _searchQuery = '';
  String? _selectedDeptFilter;

  final Set<String> _selectedActiveUids = {};
  final Map<String, bool> _actionLoading = {};

  bool _copiedFirmId = false;
  bool _copiedInviteLink = false;
  final Set<String> _copiedCodes = {};

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
    if (widget.initialFilter != null &&
        widget.initialFilter != oldWidget.initialFilter) {
      setState(() {
        _activeFilter = widget.initialFilter!;
      });
    }
  }

  Color _hexToColor(
    String hexString, [
    Color fallback = PcTokens.defaultBrandBlue,
  ]) {
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

  Widget _styledDropdown<T>({
    required PcTokens tokens,
    required T value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
    String? label,
  }) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: tokens.surfaceSubtle,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: tokens.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: tokens.border),
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          dropdownColor: tokens.surface,
          style: TextStyle(color: tokens.textPrimary, fontSize: 13.5),
          icon: Icon(Icons.arrow_drop_down, color: tokens.textSecondary),
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.pcTokens;
    final firm = ref.watch(currentFirmProvider);
    if (firm == null) {
      return Center(child: CircularProgressIndicator(color: tokens.primary));
    }

    final activeAccent =
        PcTokens.readableAccentOnLight(_hexToColor(firm.primaryColor));

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 800;

        return SingleChildScrollView(
          padding: EdgeInsets.all(isMobile ? 14 : 24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildOnboardingHeaderCard(
                    tokens,
                    firm,
                    activeAccent,
                    isMobile,
                  ),
                  const SizedBox(height: 18),

                  if (_showCsvStepper) ...[
                    _buildCsvStepperCard(
                      context,
                      tokens,
                      firm,
                      activeAccent,
                      isMobile,
                    ),
                    const SizedBox(height: 18),
                  ],

                  _buildUnifiedStaffHub(
                    context,
                    tokens,
                    firm,
                    activeAccent,
                    isMobile,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // 1. ONBOARDING HEADER & QR CARD
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildOnboardingHeaderCard(
    PcTokens tokens,
    Firm firm,
    Color activeAccent,
    bool isMobile,
  ) {
    final firmId = firm.firmId;
    final inviteUri = 'https://officespace.chottu.link/?firmId=$firmId';

    final csvBtn = OutlinedButton.icon(
      onPressed: () {
        setState(() {
          _showCsvStepper = true;
          _csvStep = 0;
          _csvErrorMessage = null;
          _csvParsedStaff = [];
          _csvMissingDepts = [];
        });
      },
      icon: Icon(Icons.upload_file, size: 16, color: activeAccent),
      label: const Text('Bulk Import CSV'),
      style: OutlinedButton.styleFrom(
        backgroundColor: tokens.surfaceSubtle,
        foregroundColor: tokens.textPrimary,
        side: BorderSide(color: tokens.borderStrong),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );

    return Material(
      color: tokens.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: tokens.border),
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
                    color: activeAccent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.qr_code_2_rounded,
                    color: activeAccent,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Invite & Onboard Team Members',
                        style: TextStyle(
                          color: tokens.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Staff can onboard instantly using your Firm ID, QR code, or direct invite link.',
                        style: TextStyle(
                          color: tokens.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!_showCsvStepper && !isMobile) ...[
                  const SizedBox(width: 12),
                  csvBtn,
                ],
              ],
            ),
            if (!_showCsvStepper && isMobile) ...[
              const SizedBox(height: 12),
              csvBtn,
            ],
            const SizedBox(height: 18),
            Divider(color: tokens.border, height: 1),
            const SizedBox(height: 18),

            if (isMobile) ...[
              Center(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: tokens.border),
                  ),
                  child: SizedBox(
                    width: 150,
                    height: 150,
                    child: QrImageView(
                      data: inviteUri.isNotEmpty
                          ? inviteUri
                          : 'https://officespace.chottu.link',
                      size: 150,
                      eyeStyle: QrEyeStyle(
                        eyeShape: QrEyeShape.square,
                        color: activeAccent,
                      ),
                      dataModuleStyle: QrDataModuleStyle(
                        dataModuleShape: QrDataModuleShape.square,
                        color: activeAccent,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _buildJoinCodeBanner(tokens, firmId, inviteUri, activeAccent),
            ] else ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: tokens.border),
                    ),
                    child: SizedBox(
                      width: 130,
                      height: 130,
                      child: QrImageView(
                        data: inviteUri.isNotEmpty
                            ? inviteUri
                            : 'https://officespace.chottu.link',
                        size: 130,
                        eyeStyle: QrEyeStyle(
                          eyeShape: QrEyeShape.square,
                          color: activeAccent,
                        ),
                        dataModuleStyle: QrDataModuleStyle(
                          dataModuleShape: QrDataModuleShape.square,
                          color: activeAccent,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 22),
                  Expanded(
                    child: _buildJoinCodeBanner(
                      tokens,
                      firmId,
                      inviteUri,
                      activeAccent,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildJoinCodeBanner(
    PcTokens tokens,
    String firmId,
    String inviteUri,
    Color activeAccent,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: tokens.surfaceSubtle,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: activeAccent.withValues(alpha: 0.30)),
          ),
          child: Row(
            children: [
              Icon(Icons.vpn_key_rounded, color: activeAccent, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'FIRM ID (MANUAL JOIN CODE)',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: tokens.textMuted,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 2),
                    SelectableText(
                      firmId,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: tokens.textPrimary,
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
                  SnackbarService()
                      .showSnackbar('Firm ID copied to clipboard!');
                  Future.delayed(const Duration(seconds: 2), () {
                    if (mounted) setState(() => _copiedFirmId = false);
                  });
                },
                icon: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: _copiedFirmId
                      ? const Icon(
                          Icons.check,
                          color: _emerald,
                          size: 16,
                          key: ValueKey('c_id_ok'),
                        )
                      : Icon(
                          Icons.copy,
                          color: activeAccent,
                          size: 16,
                          key: const ValueKey('c_id_copy'),
                        ),
                ),
                label: Text(
                  _copiedFirmId ? 'Copied' : 'Copy Code',
                  style: TextStyle(
                    color: _copiedFirmId ? _emerald : activeAccent,
                    fontSize: 12,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  backgroundColor: tokens.surface,
                  side: BorderSide(
                    color: _copiedFirmId
                        ? _emerald
                        : activeAccent.withValues(alpha: 0.45),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

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
                    ? const Icon(
                        Icons.check,
                        color: _emerald,
                        size: 16,
                        key: ValueKey('c_link_ok'),
                      )
                    : const Icon(
                        Icons.link,
                        size: 16,
                        key: ValueKey('c_link_copy'),
                      ),
              ),
              label: Text(
                _copiedInviteLink ? 'Link Copied!' : 'Copy Direct Link',
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor:
                    _copiedInviteLink ? _emerald : tokens.textPrimary,
                side: BorderSide(
                  color: _copiedInviteLink ? _emerald : tokens.borderStrong,
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
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
                  backgroundColor: activeAccent,
                  foregroundColor: PcTokens.contrastOn(activeAccent),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
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

  Widget _buildCsvStepperCard(
    BuildContext context,
    PcTokens tokens,
    Firm firm,
    Color activeAccent,
    bool isMobile,
  ) {
    return Material(
      color: tokens.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: activeAccent.withValues(alpha: 0.40)),
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
                    Icon(Icons.badge_outlined, color: activeAccent, size: 20),
                    const SizedBox(width: 10),
                    Text(
                      'CSV Bulk Onboarding Stepper',
                      style: TextStyle(
                        color: tokens.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: Icon(Icons.close, color: tokens.textMuted, size: 20),
                  onPressed: () => setState(() => _showCsvStepper = false),
                ),
              ],
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                _buildStepIndicator(
                  tokens,
                  0,
                  '1. Upload CSV',
                  _csvStep == 0,
                  _csvStep > 0,
                  activeAccent,
                ),
                _buildStepDivider(tokens, _csvStep > 0),
                _buildStepIndicator(
                  tokens,
                  1,
                  '2. Validate & Preview',
                  _csvStep == 1,
                  _csvStep > 1,
                  activeAccent,
                ),
                _buildStepDivider(tokens, _csvStep > 1),
                _buildStepIndicator(
                  tokens,
                  2,
                  '3. Confirm & Issue',
                  _csvStep == 2,
                  false,
                  activeAccent,
                ),
              ],
            ),
            const SizedBox(height: 20),

            if (_csvErrorMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: tokens.urgentBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: tokens.urgentBorder),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.error_outline,
                      color: tokens.urgentText,
                      size: 18,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _csvErrorMessage!,
                        style: TextStyle(
                          color: tokens.urgentText,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            if (_csvStep == 0)
              _buildCsvStepUpload(context, tokens, firm, activeAccent),
            if (_csvStep == 1)
              _buildCsvStepPreview(context, tokens, firm, activeAccent),
            if (_csvStep == 2)
              _buildCsvStepComplete(tokens, activeAccent),
          ],
        ),
      ),
    );
  }

  Widget _buildStepIndicator(
    PcTokens tokens,
    int step,
    String label,
    bool isActive,
    bool isDone,
    Color activeAccent,
  ) {
    return Row(
      children: [
        Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isDone
                ? _emerald
                : (isActive ? activeAccent : tokens.surfaceSubtle),
            border: Border.all(
              color: isDone
                  ? _emerald
                  : (isActive ? activeAccent : tokens.borderStrong),
            ),
          ),
          child: Center(
            child: isDone
                ? const Icon(Icons.check, size: 15, color: Colors.white)
                : Text(
                    '${step + 1}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: isActive
                          ? PcTokens.contrastOn(activeAccent)
                          : tokens.textMuted,
                    ),
                  ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            color: isActive ? tokens.textPrimary : tokens.textSecondary,
            fontSize: 12,
            fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildStepDivider(PcTokens tokens, bool isDone) {
    return Expanded(
      child: Container(
        height: 2,
        margin: const EdgeInsets.symmetric(horizontal: 10),
        color: isDone ? _emerald : tokens.border,
      ),
    );
  }

  Widget _buildCsvStepUpload(
    BuildContext context,
    PcTokens tokens,
    Firm firm,
    Color activeAccent,
  ) {
    return DropTarget(
      onDragEntered: (_) => setState(() => _isDraggingFile = true),
      onDragExited: (_) => setState(() => _isDraggingFile = false),
      onDragDone: (details) async {
        setState(() => _isDraggingFile = false);
        if (details.files.isNotEmpty) {
          final file = details.files.first;
          if (file.name.toLowerCase().endsWith('.csv') ||
              file.name.toLowerCase().endsWith('.txt')) {
            final bytes = await file.readAsBytes();
            _processCsvBytes(bytes, firm);
          } else {
            setState(
              () => _csvErrorMessage = 'Please drop a valid .csv file.',
            );
          }
        }
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
        decoration: BoxDecoration(
          color: _isDraggingFile
              ? activeAccent.withValues(alpha: 0.08)
              : tokens.surfaceSubtle,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _isDraggingFile ? activeAccent : tokens.borderStrong,
            width: 1.5,
          ),
        ),
        child: Column(
          children: [
            Icon(
              Icons.cloud_upload_outlined,
              size: 44,
              color: _isDraggingFile ? activeAccent : tokens.textMuted,
            ),
            const SizedBox(height: 12),
            Text(
              'Drag and drop your CSV file here',
              style: TextStyle(
                color: tokens.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Supported columns: Name, Email, Department (optional), Role (optional: employee/lead)',
              textAlign: TextAlign.center,
              style: TextStyle(color: tokens.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () async {
                try {
                  setState(() => _csvErrorMessage = null);
                  final staffList =
                      await CsvUploadService.instance.pickAndParseCsv();
                  if (staffList.isNotEmpty) {
                    await _validateAndTransitionParsedCsv(staffList, firm);
                  }
                } catch (e) {
                  setState(
                    () => _csvErrorMessage =
                        e.toString().replaceAll('Exception:', ''),
                  );
                }
              },
              icon: const Icon(Icons.folder_open, size: 16),
              label: const Text('Choose File from Computer'),
              style: ElevatedButton.styleFrom(
                backgroundColor: activeAccent,
                foregroundColor: PcTokens.contrastOn(activeAccent),
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
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
      final staffList = await CsvUploadService.instance.pickAndParseCsv();
      if (staffList.isNotEmpty) {
        await _validateAndTransitionParsedCsv(staffList, firm);
      }
    } catch (e) {
      setState(
        () => _csvErrorMessage = e.toString().replaceAll('Exception:', ''),
      );
    }
  }

  Future<void> _validateAndTransitionParsedCsv(
    List<Map<String, dynamic>> staffList,
    Firm firm,
  ) async {
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

  Widget _buildCsvStepPreview(
    BuildContext context,
    PcTokens tokens,
    Firm firm,
    Color activeAccent,
  ) {
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
              style: TextStyle(
                color: tokens.textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: willExceed
                    ? tokens.urgentBg
                    : _emerald.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: willExceed
                      ? tokens.urgentBorder
                      : _emerald.withValues(alpha: 0.35),
                ),
              ),
              child: Text(
                willExceed
                    ? 'Seat limit exceeded (${seatCount + _csvParsedStaff.length}/$seatLimit)'
                    : 'Seat check: $seatCount + ${_csvParsedStaff.length} of $seatLimit used',
                style: TextStyle(
                  color: willExceed ? tokens.urgentText : _emerald,
                  fontWeight: FontWeight.w700,
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
              color: tokens.warningSoft,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: tokens.warningAccent.withValues(alpha: 0.35),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: tokens.warningAccent,
                  size: 18,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Found ${_csvMissingDepts.length} new departments in CSV: ${_csvMissingDepts.join(', ')}.',
                    style: TextStyle(
                      color: tokens.textPrimary,
                      fontSize: 12,
                    ),
                  ),
                ),
                Checkbox(
                  value: _csvAutoCreateDepts,
                  activeColor: activeAccent,
                  onChanged: (val) =>
                      setState(() => _csvAutoCreateDepts = val ?? true),
                ),
                Text(
                  'Auto-create',
                  style: TextStyle(color: tokens.textPrimary, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],

        Container(
          height: 200,
          decoration: BoxDecoration(
            color: tokens.surfaceSubtle,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: tokens.border),
          ),
          child: ListView.separated(
            padding: const EdgeInsets.all(8),
            itemCount: _csvParsedStaff.length,
            separatorBuilder: (_, _) => Divider(color: tokens.border, height: 1),
            itemBuilder: (ctx, idx) {
              final item = _csvParsedStaff[idx];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 12,
                      backgroundColor: activeAccent.withValues(alpha: 0.14),
                      child: Text(
                        (item['name'] as String? ?? 'S')
                            .substring(0, 1)
                            .toUpperCase(),
                        style: TextStyle(
                          color: activeAccent,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: Text(
                        item['name'] ?? '',
                        style: TextStyle(
                          color: tokens.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: Text(
                        item['email'] ?? '',
                        style: TextStyle(
                          color: tokens.textSecondary,
                          fontSize: 12,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        (item['department'] as String?)?.isNotEmpty == true
                            ? item['department']
                            : 'Unassigned',
                        style: TextStyle(
                          color: tokens.textSecondary,
                          fontSize: 12,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: tokens.infoSoft,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        (item['role'] as String? ?? 'employee').toUpperCase(),
                        style: TextStyle(
                          color: tokens.infoAccent,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 16),

        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: () => setState(() => _csvStep = 0),
              child: Text(
                'Back',
                style: TextStyle(color: tokens.textSecondary),
              ),
            ),
            const SizedBox(width: 12),
            ElevatedButton(
              onPressed: willExceed || _csvIsUploading
                  ? null
                  : () => _executeCsvImport(context, firm),
              style: ElevatedButton.styleFrom(
                backgroundColor: activeAccent,
                foregroundColor: PcTokens.contrastOn(activeAccent),
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 12,
                ),
              ),
              child: _csvIsUploading
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: PcTokens.contrastOn(activeAccent),
                      ),
                    )
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
      SnackbarService().showSnackbar(
        'Successfully imported ${_csvParsedStaff.length} staff records!',
      );
    } catch (e) {
      setState(() {
        _csvIsUploading = false;
        _csvErrorMessage = e.toString().replaceAll('Exception:', '');
      });
    }
  }

  Widget _buildCsvStepComplete(PcTokens tokens, Color activeAccent) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          children: [
            const Icon(Icons.check_circle_outline, color: _emerald, size: 48),
            const SizedBox(height: 12),
            Text(
              'Import Completed Successfully!',
              style: TextStyle(
                color: tokens.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${_csvParsedStaff.length} staff codes generated. They appear below with active 5-minute countdowns.',
              textAlign: TextAlign.center,
              style: TextStyle(color: tokens.textSecondary, fontSize: 13),
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
              style: ElevatedButton.styleFrom(
                backgroundColor: activeAccent,
                foregroundColor: PcTokens.contrastOn(activeAccent),
              ),
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
    PcTokens tokens,
    Firm firm,
    Color activeAccent,
    bool isMobile,
  ) {
    return StreamBuilder<List<Department>>(
      stream: DBService.instance.streamDepartments(firm.firmId),
      builder: (context, deptSnapshot) {
        final departments = deptSnapshot.data ?? [];
        final Map<String, String> deptMap = {
          for (final d in departments) d.deptId: d.name,
        };

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
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: CircularProgressIndicator(color: activeAccent),
                    ),
                  );
                }

                final memberDocs = membersSnap.data?.docs ?? [];
                final List<UnifiedStaffItem> allStaffItems = [];
                final Set<String> activeMemberEmails = {};

                for (final doc in memberDocs) {
                  final data = doc.data() as Map<String, dynamic>;
                  final email = (data['email'] as String? ?? '').toLowerCase();
                  if (email.isNotEmpty) activeMemberEmails.add(email);

                  final rawStatus = data['status'] as String? ?? 'approved';
                  String mappedStatus = 'active';
                  if (rawStatus == 'pending') {
                    mappedStatus = 'pending_approval';
                  }
                  if (rawStatus == 'revoked') mappedStatus = 'revoked';
                  if (rawStatus == 'rejected') mappedStatus = 'rejected';

                  allStaffItems.add(
                    UnifiedStaffItem(
                      type: UnifiedStaffType.member,
                      id: doc.id,
                      uid: data['uid'] as String? ?? doc.id,
                      name: (data['name'] as String?)?.isNotEmpty == true
                          ? data['name']
                          : (email.isNotEmpty ? email : doc.id),
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
                            : ((data['role'] as String? ?? '') == 'lead'
                                ? MembershipRole.lead
                                : MembershipRole.employee),
                        status: rawStatus == 'revoked'
                            ? MembershipStatus.revoked
                            : (rawStatus == 'pending'
                                ? MembershipStatus.pending
                                : (rawStatus == 'rejected'
                                    ? MembershipStatus.rejected
                                    : MembershipStatus.active)),
                        departmentId: data['departmentId'] as String?,
                      ),
                    ),
                  );
                }

                for (final p in preAuthList) {
                  final email = (p['email'] as String? ?? '').toLowerCase();
                  final pStatus = p['status'] as String? ?? 'invited';
                  if (pStatus == 'joined' &&
                      activeMemberEmails.contains(email)) {
                    continue;
                  }

                  final exp = p['codeExpiresAt'];
                  DateTime? expDate;
                  if (exp is Timestamp) expDate = exp.toDate();

                  allStaffItems.add(
                    UnifiedStaffItem(
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
                    ),
                  );
                }

                final filteredItems = allStaffItems.where((item) {
                  if (_activeFilter == 'active' && item.status != 'active') {
                    return false;
                  }
                  if (_activeFilter == 'pending' &&
                      item.status != 'code_pending' &&
                      item.status != 'pending_approval') {
                    return false;
                  }
                  if (_activeFilter == 'revoked' && item.status != 'revoked') {
                    return false;
                  }

                  if (_selectedDeptFilter != null &&
                      _selectedDeptFilter!.isNotEmpty) {
                    if (item.departmentId != _selectedDeptFilter) return false;
                  }

                  if (_searchQuery.isNotEmpty) {
                    final q = _searchQuery.toLowerCase();
                    final matchName = item.name.toLowerCase().contains(q);
                    final matchEmail = item.email.toLowerCase().contains(q);
                    final matchCode =
                        item.code?.toLowerCase().contains(q) ?? false;
                    if (!matchName && !matchEmail && !matchCode) return false;
                  }

                  return true;
                }).toList();

                return Material(
                  color: tokens.surface,
                  clipBehavior: Clip.antiAlias,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(color: tokens.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildStaffFilterBar(
                        context,
                        tokens,
                        firm,
                        activeAccent,
                        departments,
                        allStaffItems,
                      ),

                      if (_selectedActiveUids.isNotEmpty)
                        _buildBulkActionToolbar(
                          tokens,
                          firm.firmId,
                          departments,
                          activeAccent,
                        ),

                      if (filteredItems.isEmpty)
                        _buildEmptyStaffState(tokens)
                      else if (isMobile)
                        _buildMobileStaffList(
                          context,
                          tokens,
                          firm,
                          activeAccent,
                          filteredItems,
                          deptMap,
                          departments,
                        )
                      else
                        _buildDesktopStaffTable(
                          context,
                          tokens,
                          firm,
                          activeAccent,
                          filteredItems,
                          deptMap,
                          departments,
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

  // ══════════════════════════════════════════════════════════════════════════
  // FILTER BAR & EMPTY STATE
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildStaffFilterBar(
    BuildContext context,
    PcTokens tokens,
    Firm firm,
    Color activeAccent,
    List<Department> departments,
    List<UnifiedStaffItem> allItems,
  ) {
    final activeCount = allItems.where((i) => i.status == 'active').length;
    final pendingCount = allItems
        .where(
          (i) => i.status == 'code_pending' || i.status == 'pending_approval',
        )
        .length;
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
              Text(
                'Staff Directory & Access',
                style: TextStyle(
                  color: tokens.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
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
                    : () => _showAddPreApprovedStaffDialog(
                          context,
                          firm.firmId,
                          departments,
                        ),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add Staff Code'),
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      isLimitReached ? tokens.textMuted : activeAccent,
                  foregroundColor: isLimitReached
                      ? Colors.white
                      : PcTokens.contrastOn(activeAccent),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _buildFilterChip(
                tokens,
                'all',
                'All (${allItems.length})',
                activeAccent,
              ),
              _buildFilterChip(
                tokens,
                'active',
                'Active ($activeCount)',
                activeAccent,
              ),
              _buildFilterChip(
                tokens,
                'pending',
                'Pending ($pendingCount)',
                activeAccent,
              ),
              _buildFilterChip(
                tokens,
                'revoked',
                'Revoked ($revokedCount)',
                activeAccent,
              ),

              const SizedBox(width: 8),

              SizedBox(
                width: 210,
                height: 36,
                child: TextField(
                  style: TextStyle(color: tokens.textPrimary, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Search name, email...',
                    hintStyle: TextStyle(color: tokens.textMuted, fontSize: 12),
                    prefixIcon: Icon(
                      Icons.search,
                      size: 16,
                      color: tokens.textMuted,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 0,
                      horizontal: 10,
                    ),
                    filled: true,
                    fillColor: tokens.surfaceSubtle,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: tokens.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: tokens.border),
                    ),
                  ),
                  onChanged: (val) =>
                      setState(() => _searchQuery = val.trim()),
                ),
              ),

              Container(
                width: 175,
                height: 36,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: tokens.surfaceSubtle,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: tokens.border),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String?>(
                    value: _selectedDeptFilter,
                    isExpanded: true,
                    dropdownColor: tokens.surface,
                    icon: Icon(
                      Icons.arrow_drop_down,
                      color: tokens.textSecondary,
                      size: 18,
                    ),
                    style: TextStyle(color: tokens.textPrimary, fontSize: 12),
                    hint: Text(
                      'All Departments',
                      style: TextStyle(
                        color: tokens.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text(
                          'All Departments',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                      ...departments.map(
                        (d) => DropdownMenuItem<String?>(
                          value: d.deptId,
                          child: Text(
                            d.name,
                            style: const TextStyle(fontSize: 12),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                    onChanged: (val) =>
                        setState(() => _selectedDeptFilter = val),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(
    PcTokens tokens,
    String filterId,
    String label,
    Color activeAccent,
  ) {
    final isSelected = _activeFilter == filterId;
    return InkWell(
      onTap: () => setState(() => _activeFilter = filterId),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? activeAccent.withValues(alpha: 0.12)
              : tokens.surfaceSubtle,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? activeAccent : tokens.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? activeAccent : tokens.textSecondary,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildBulkActionToolbar(
    PcTokens tokens,
    String firmId,
    List<Department> departments,
    Color activeAccent,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: activeAccent.withValues(alpha: 0.08),
        border: Border.symmetric(
          horizontal: BorderSide(color: activeAccent.withValues(alpha: 0.25)),
        ),
      ),
      child: Row(
        children: [
          Text(
            '${_selectedActiveUids.length} staff selected',
            style: TextStyle(
              color: tokens.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
          const Spacer(),
          TextButton.icon(
            icon: Icon(Icons.corporate_fare, size: 16, color: activeAccent),
            label: const Text('Bulk Assign Dept'),
            style: TextButton.styleFrom(foregroundColor: tokens.textPrimary),
            onPressed: () => _showBulkAssignDeptDialog(
              context,
              firmId,
              _selectedActiveUids.toList(),
              departments,
            ),
          ),
          const SizedBox(width: 8),
          TextButton.icon(
            icon: Icon(Icons.shield_outlined, size: 16, color: activeAccent),
            label: const Text('Bulk Set Role'),
            style: TextButton.styleFrom(foregroundColor: tokens.textPrimary),
            onPressed: () => _showBulkSetRoleDialog(
              context,
              firmId,
              _selectedActiveUids.toList(),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: Icon(Icons.close, size: 18, color: tokens.textMuted),
            tooltip: 'Clear selection',
            onPressed: () => setState(() => _selectedActiveUids.clear()),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyStaffState(PcTokens tokens) {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.people_outline, size: 48, color: tokens.textMuted),
            const SizedBox(height: 12),
            Text(
              'No staff members match the selected filter',
              style: TextStyle(
                color: tokens.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Adjust the filter or add new staff codes to invite teammates.',
              style: TextStyle(color: tokens.textSecondary, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // DESKTOP DATA TABLE
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildDesktopStaffTable(
    BuildContext context,
    PcTokens tokens,
    Firm firm,
    Color activeAccent,
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
              minWidth:
                  constraints.maxWidth < 900 ? 900 : constraints.maxWidth,
            ),
            child: DataTable(
              columnSpacing: 20,
              horizontalMargin: 16,
              dataRowMinHeight: 52,
              dataRowMaxHeight: 64,
              headingRowColor: WidgetStatePropertyAll(tokens.surfaceSubtle),
              headingTextStyle: TextStyle(
                color: tokens.textSecondary,
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
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
                final deptName = item.departmentId != null
                    ? deptMap[item.departmentId]
                    : null;
                final isSelected = item.uid != null &&
                    _selectedActiveUids.contains(item.uid);

                return DataRow(
                  selected: isSelected,
                  onSelectChanged:
                      (item.status == 'active' && !isSelf && item.uid != null)
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
                    DataCell(
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircleAvatar(
                              radius: 15,
                              backgroundColor:
                                  activeAccent.withValues(alpha: 0.14),
                              backgroundImage: item.avatarUrl != null
                                  ? NetworkImage(item.avatarUrl!)
                                  : null,
                              child: item.avatarUrl == null
                                  ? Text(
                                      item.name.isNotEmpty
                                          ? item.name[0].toUpperCase()
                                          : '?',
                                      style: TextStyle(
                                        color: activeAccent,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                      ),
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
                                      style: TextStyle(
                                        color: tokens.textPrimary,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    if (isSelf) ...[
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 4,
                                          vertical: 1,
                                        ),
                                        decoration: BoxDecoration(
                                          color: tokens.infoSoft,
                                          borderRadius:
                                              BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          'YOU',
                                          style: TextStyle(
                                            color: tokens.infoAccent,
                                            fontSize: 9,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                Text(
                                  item.email,
                                  style: TextStyle(
                                    color: tokens.textSecondary,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                    DataCell(
                      Text(
                        deptName ?? 'Unassigned',
                        style: TextStyle(
                          color: deptName != null
                              ? tokens.textPrimary
                              : tokens.textMuted,
                          fontSize: 12,
                        ),
                      ),
                    ),

                    DataCell(_buildRoleBadge(tokens, item.role)),

                    DataCell(
                      _buildStatusCell(
                        context,
                        tokens,
                        item,
                        firm.firmId,
                        activeAccent,
                      ),
                    ),

                    DataCell(
                      _buildRowActions(
                        context,
                        tokens,
                        item,
                        firm.firmId,
                        activeAccent,
                        departments,
                      ),
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

  Widget _buildRoleBadge(PcTokens tokens, String role) {
    final isAdminRole = role == 'admin';
    final isLeadRole = role == 'lead';
    final bg = isAdminRole
        ? tokens.infoSoft
        : (isLeadRole ? tokens.projectSoft : tokens.surfaceSubtle);
    final fg = isAdminRole
        ? tokens.infoAccent
        : (isLeadRole ? tokens.projectAccent : tokens.textSecondary);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: fg.withValues(alpha: 0.22)),
      ),
      child: Text(
        role.toUpperCase(),
        style: TextStyle(
          color: fg,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // MOBILE CARD VIEW
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildMobileStaffList(
    BuildContext context,
    PcTokens tokens,
    Firm firm,
    Color activeAccent,
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
        separatorBuilder: (_, _) => Divider(color: tokens.border, height: 1),
        itemBuilder: (ctx, idx) {
          final item = items[idx];
          final deptName = item.departmentId != null
              ? deptMap[item.departmentId]
              : null;

          return ListTile(
            contentPadding: const EdgeInsets.symmetric(vertical: 4),
            leading: CircleAvatar(
              backgroundColor: activeAccent.withValues(alpha: 0.14),
              child: Text(
                item.name.isNotEmpty ? item.name[0].toUpperCase() : '?',
                style: TextStyle(
                  color: activeAccent,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            title: Row(
              children: [
                Flexible(
                  child: Text(
                    item.name,
                    style: TextStyle(
                      color: tokens.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 6),
                _buildRoleBadge(tokens, item.role),
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.email,
                  style: TextStyle(color: tokens.textSecondary, fontSize: 12),
                ),
                const SizedBox(height: 3),
                Text(
                  'Dept: ${deptName ?? "None"}',
                  style: TextStyle(color: tokens.textMuted, fontSize: 11),
                ),
                const SizedBox(height: 6),
                _buildStatusCell(
                  context,
                  tokens,
                  item,
                  firm.firmId,
                  activeAccent,
                ),
              ],
            ),
            trailing: _buildRowActions(
              context,
              tokens,
              item,
              firm.firmId,
              activeAccent,
              departments,
            ),
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
    PcTokens tokens,
    UnifiedStaffItem item,
    String firmId,
    Color activeAccent,
  ) {
    if (item.status == 'active') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: _emerald.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: _emerald.withValues(alpha: 0.25)),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle, size: 12, color: _emerald),
            SizedBox(width: 4),
            Text(
              'Active',
              style: TextStyle(
                color: _emerald,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      );
    }

    if (item.status == 'revoked') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: tokens.urgentBg,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: tokens.urgentBorder),
        ),
        child: Text(
          'Revoked',
          style: TextStyle(
            color: tokens.urgentText,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }

    if (item.status == 'pending_approval') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: tokens.warningSoft,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: tokens.warningAccent.withValues(alpha: 0.30),
          ),
        ),
        child: Text(
          'Pending Approval',
          style: TextStyle(
            color: tokens.warningAccent,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }

    if (item.status == 'code_pending' && item.code != null) {
      return _StaffCodeCountdownRing(
        firmId: firmId,
        staffId: item.id,
        email: item.email,
        code: item.code!,
        expiresAt: item.codeExpiresAt,
        primaryColor: activeAccent,
        onCopyFeedback: () {
          setState(() => _copiedCodes.add(item.id));
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted) setState(() => _copiedCodes.remove(item.id));
          });
        },
        hasCopied: _copiedCodes.contains(item.id),
      );
    }

    return Text(
      item.status,
      style: TextStyle(color: tokens.textSecondary, fontSize: 12),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // ROW ACTIONS & OFFBOARDING CHECKLIST
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildRowActions(
    BuildContext context,
    PcTokens tokens,
    UnifiedStaffItem item,
    String firmId,
    Color activeAccent,
    List<Department> departments,
  ) {
    final isActionActive = _actionLoading[item.id] == true;
    if (isActionActive) {
      return SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(strokeWidth: 2, color: activeAccent),
      );
    }

    if (item.type == UnifiedStaffType.preApproved) {
      return IconButton(
        icon: Icon(Icons.delete_outline, color: tokens.urgentText, size: 18),
        tooltip: 'Remove Invite',
        onPressed: () => _confirmRemovePreApproved(context, firmId, item),
      );
    }

    if (item.status == 'pending_approval') {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(Icons.close, color: tokens.urgentText, size: 18),
            tooltip: 'Reject',
            onPressed: () => _rejectMembership(context, firmId, item),
          ),
          IconButton(
            icon: const Icon(Icons.check, color: _emerald, size: 18),
            tooltip: 'Approve',
            onPressed: () => _approveMembership(context, firmId, item),
          ),
        ],
      );
    }

    if (item.status == 'revoked') {
      return ElevatedButton.icon(
        onPressed: () => _restoreMembership(context, firmId, item),
        icon: const Icon(Icons.restore, size: 14),
        label: const Text('Restore', style: TextStyle(fontSize: 11)),
        style: ElevatedButton.styleFrom(
          backgroundColor: _emerald,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        ),
      );
    }

    if (item.status == 'active' && item.role != 'admin') {
      return PopupMenuButton<String>(
        icon: Icon(Icons.more_vert, color: tokens.textSecondary, size: 18),
        color: tokens.surface,
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
          PopupMenuItem(
            value: 'dept',
            child: Row(
              children: [
                Icon(
                  Icons.corporate_fare,
                  size: 16,
                  color: tokens.textSecondary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Assign Department',
                  style: TextStyle(color: tokens.textPrimary, fontSize: 13),
                ),
              ],
            ),
          ),
          PopupMenuItem(
            value: 'role',
            child: Row(
              children: [
                Icon(
                  Icons.shield_outlined,
                  size: 16,
                  color: tokens.textSecondary,
                ),
                const SizedBox(width: 8),
                Text(
                  item.role == 'lead'
                      ? 'Demote to Employee'
                      : 'Promote to Lead',
                  style: TextStyle(color: tokens.textPrimary, fontSize: 13),
                ),
              ],
            ),
          ),
          const PopupMenuDivider(),
          PopupMenuItem(
            value: 'revoke',
            child: Row(
              children: [
                Icon(Icons.block, color: tokens.urgentText, size: 16),
                const SizedBox(width: 8),
                Text(
                  'Revoke Access',
                  style: TextStyle(color: tokens.urgentText, fontSize: 13),
                ),
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

    final deptsSnap = await FirebaseFirestore.instance
        .collection('Firms')
        .doc(firmId)
        .collection('departments')
        .where('headUid', isEqualTo: uid)
        .where('status', isEqualTo: 'active')
        .get();

    final headedDeptNames =
        deptsSnap.docs.map((d) => d.data()['name'] as String? ?? 'Dept').toList();

    final projectsSnap = await FirebaseFirestore.instance
        .collection('Firms')
        .doc(firmId)
        .collection('projects')
        .where('ownerUid', isEqualTo: uid)
        .where('status', isEqualTo: 'active')
        .get();

    final ownedProjectNames = projectsSnap.docs
        .map((p) => p.data()['name'] as String? ?? 'Project')
        .toList();

    final hasLeadershipRoles =
        headedDeptNames.isNotEmpty || ownedProjectNames.isNotEmpty;

    if (!context.mounted) return;
    final tokens = context.pcTokens;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: tokens.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(
              hasLeadershipRoles ? Icons.warning_amber_rounded : Icons.block,
              color: hasLeadershipRoles
                  ? tokens.warningAccent
                  : tokens.urgentText,
              size: 22,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                hasLeadershipRoles
                    ? 'Offboarding Leadership Warning'
                    : 'Revoke Workspace Access?',
                style: TextStyle(
                  color: tokens.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Revoking access for ${item.name} (${item.email}) will immediately prevent them from logging in.',
              style: TextStyle(color: tokens.textSecondary, fontSize: 13),
            ),
            if (hasLeadershipRoles) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: tokens.warningSoft,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: tokens.warningAccent.withValues(alpha: 0.35),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Active Responsibilities Detected:',
                      style: TextStyle(
                        color: tokens.warningAccent,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 6),
                    if (headedDeptNames.isNotEmpty)
                      Text(
                        '• Department Head of: ${headedDeptNames.join(", ")}',
                        style: TextStyle(
                          color: tokens.textPrimary,
                          fontSize: 12,
                        ),
                      ),
                    if (ownedProjectNames.isNotEmpty)
                      Text(
                        '• Owner of Project Group(s): ${ownedProjectNames.join(", ")}',
                        style: TextStyle(
                          color: tokens.textPrimary,
                          fontSize: 12,
                        ),
                      ),
                    const SizedBox(height: 8),
                    Text(
                      'Revoking now will leave these areas without a leader. Consider reassigning their roles first in the Notices & Groups tab.',
                      style: TextStyle(
                        color: tokens.textSecondary,
                        fontSize: 11.5,
                      ),
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
            child: Text(
              'Cancel',
              style: TextStyle(color: tokens.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: tokens.urgentText,
              foregroundColor: Colors.white,
            ),
            child: const Text('Revoke Access'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _actionLoading[item.id] = true);
      try {
        await DBService.instance.updateMembershipStatus(item.id, 'revoked');

        await AuditService.instance.logAction(
          firmId: firmId,
          action: 'revoke_staff',
          targetType: 'membership',
          targetId: item.id,
          targetLabel: '${item.name} (${item.email})',
        );

        SnackbarService().showSnackbar('${item.name} access revoked.');
      } catch (e) {
        SnackbarService()
            .showSnackbar('Error revoking member: $e', isError: true);
      } finally {
        if (mounted) setState(() => _actionLoading[item.id] = false);
      }
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // ROLE, DEPT, REMOVE, APPROVE & REJECT HANDLERS
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> _approveMembership(
    BuildContext context,
    String firmId,
    UnifiedStaffItem item,
  ) async {
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

  Future<void> _rejectMembership(
    BuildContext context,
    String firmId,
    UnifiedStaffItem item,
  ) async {
    final tokens = context.pcTokens;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: tokens.surface,
        title: Text(
          'Reject Access Request?',
          style: TextStyle(color: tokens.textPrimary),
        ),
        content: Text(
          'Reject access request for ${item.name}?',
          style: TextStyle(color: tokens.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancel',
              style: TextStyle(color: tokens.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: tokens.urgentText),
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

  Future<void> _restoreMembership(
    BuildContext context,
    String firmId,
    UnifiedStaffItem item,
  ) async {
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

  Future<void> _confirmRemovePreApproved(
    BuildContext context,
    String firmId,
    UnifiedStaffItem item,
  ) async {
    final tokens = context.pcTokens;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: tokens.surface,
        title: Text(
          'Remove Pre-Authorized Staff?',
          style: TextStyle(color: tokens.textPrimary),
        ),
        content: Text(
          'Remove ${item.email} from pre-approved staff? This frees 1 trial seat.',
          style: TextStyle(color: tokens.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancel',
              style: TextStyle(color: tokens.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: tokens.urgentText),
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
        SnackbarService()
            .showSnackbar('Removed ${item.email}. 1 seat returned.');
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
    final tokens = context.pcTokens;
    String? selectedDeptId = item.departmentId;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: tokens.surface,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            'Assign Department: ${item.name}',
            style: TextStyle(
              color: tokens.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _styledDropdown<String?>(
                tokens: tokens,
                label: 'Department',
                value: selectedDeptId,
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('None (Unassigned)'),
                  ),
                  ...departments.where((d) => d.isActive).map(
                        (d) => DropdownMenuItem<String?>(
                          value: d.deptId,
                          child: Text(d.name),
                        ),
                      ),
                ],
                onChanged: (val) => setDialogState(() => selectedDeptId = val),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                'Cancel',
                style: TextStyle(color: tokens.textSecondary),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                try {
                  await DBService.instance.assignMemberDepartment(
                    firmId,
                    item.uid!,
                    selectedDeptId,
                  );
                  await AuditService.instance.logAction(
                    firmId: firmId,
                    action: 'assign_department',
                    targetType: 'membership',
                    targetId: item.id,
                    targetLabel: '${item.name} -> ${selectedDeptId ?? "None"}',
                  );
                  SnackbarService().showSnackbar('Department updated.');
                } catch (e) {
                  SnackbarService().showSnackbar(
                    'Error updating department: $e',
                    isError: true,
                  );
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
    UnifiedStaffItem item,
  ) async {
    final tokens = context.pcTokens;
    final newRole =
        item.role == 'lead' ? MembershipRole.employee : MembershipRole.lead;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: tokens.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          newRole == MembershipRole.lead
              ? 'Promote to Lead?'
              : 'Demote to Employee?',
          style: TextStyle(color: tokens.textPrimary),
        ),
        content: Text(
          newRole == MembershipRole.lead
              ? 'Promoting ${item.name} to Lead grants permissions to create/manage project groups and post in #all-staff.'
              : 'Demoting ${item.name} to Employee will remove their permissions to create project groups.',
          style: TextStyle(color: tokens.textSecondary, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancel',
              style: TextStyle(color: tokens.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: newRole == MembershipRole.lead
                  ? tokens.projectAccent
                  : tokens.textSecondary,
              foregroundColor: Colors.white,
            ),
            child: Text(
              newRole == MembershipRole.lead
                  ? 'Promote to Lead'
                  : 'Demote to Employee',
            ),
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
        SnackbarService()
            .showSnackbar('Updated role to ${newRole.name.toUpperCase()}.');
      } catch (e) {
        SnackbarService()
            .showSnackbar('Error updating role: $e', isError: true);
      }
    }
  }

  Future<void> _showBulkAssignDeptDialog(
    BuildContext context,
    String firmId,
    List<String> memberIds,
    List<Department> departments,
  ) async {
    final tokens = context.pcTokens;
    String? targetDeptId;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: tokens.surface,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            'Bulk Assign Department (${memberIds.length} staff)',
            style: TextStyle(color: tokens.textPrimary),
          ),
          content: _styledDropdown<String?>(
            tokens: tokens,
            label: 'Target Department',
            value: targetDeptId,
            items: [
              const DropdownMenuItem<String?>(
                value: null,
                child: Text('None (Remove Department)'),
              ),
              ...departments.where((d) => d.isActive).map(
                    (d) => DropdownMenuItem<String?>(
                      value: d.deptId,
                      child: Text(d.name),
                    ),
                  ),
            ],
            onChanged: (val) => setDialogState(() => targetDeptId = val),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                'Cancel',
                style: TextStyle(color: tokens.textSecondary),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                try {
                  await DBService.instance.bulkAssignDepartment(
                    firmId,
                    memberIds,
                    targetDeptId,
                  );
                  await AuditService.instance.logAction(
                    firmId: firmId,
                    action: 'bulk_assign_dept',
                    targetType: 'membership_list',
                    targetId: firmId,
                    targetLabel:
                        '${memberIds.length} members assigned to ${targetDeptId ?? "None"}',
                  );
                  setState(() => _selectedActiveUids.clear());
                  SnackbarService().showSnackbar(
                    'Bulk assigned ${memberIds.length} members.',
                  );
                } catch (e) {
                  SnackbarService().showSnackbar(
                    'Error in bulk assignment: $e',
                    isError: true,
                  );
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
    final tokens = context.pcTokens;
    MembershipRole targetRole = MembershipRole.lead;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: tokens.surface,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            'Bulk Set Role (${memberIds.length} staff)',
            style: TextStyle(color: tokens.textPrimary),
          ),
          content: _styledDropdown<MembershipRole>(
            tokens: tokens,
            label: 'Target Role',
            value: targetRole,
            items: [
              DropdownMenuItem(
                value: MembershipRole.lead,
                child: Text(
                  'Lead (Manage Groups & #all-staff)',
                  style: TextStyle(color: tokens.projectAccent),
                ),
              ),
              const DropdownMenuItem(
                value: MembershipRole.employee,
                child: Text('Employee (Standard Member)'),
              ),
            ],
            onChanged: (val) {
              if (val != null) setDialogState(() => targetRole = val);
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                'Cancel',
                style: TextStyle(color: tokens.textSecondary),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                try {
                  await DBService.instance.bulkUpdateRoles(
                    firmId,
                    memberIds,
                    targetRole,
                  );
                  await AuditService.instance.logAction(
                    firmId: firmId,
                    action: 'bulk_set_role',
                    targetType: 'membership_list',
                    targetId: firmId,
                    targetLabel:
                        '${memberIds.length} members set to ${targetRole.name}',
                  );
                  setState(() => _selectedActiveUids.clear());
                  SnackbarService().showSnackbar(
                    'Bulk updated ${memberIds.length} roles to ${targetRole.name}.',
                  );
                } catch (e) {
                  SnackbarService().showSnackbar(
                    'Error updating roles: $e',
                    isError: true,
                  );
                }
              },
              child: const Text('Apply Role'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddPreApprovedStaffDialog(
    BuildContext context,
    String firmId,
    List<Department> departments,
  ) {
    final tokens = context.pcTokens;
    final emailController = TextEditingController();
    final nameController = TextEditingController();
    MembershipRole selectedRole = MembershipRole.employee;
    String? selectedDeptId;

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: tokens.surface,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            'Add Pre-Authorized Staff',
            style: TextStyle(
              color: tokens.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pre-authorizing an employee reserves 1 seat. A 5-minute staff code will be auto-generated and active as soon as you save.',
                  style: TextStyle(color: tokens.textSecondary, fontSize: 13),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: nameController,
                  style: TextStyle(color: tokens.textPrimary),
                  decoration: const InputDecoration(
                    labelText: 'Employee Name',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: emailController,
                  style: TextStyle(color: tokens.textPrimary),
                  decoration: const InputDecoration(
                    labelText: 'Employee Email',
                    hintText: 'name@company.com',
                  ),
                ),
                const SizedBox(height: 12),
                _styledDropdown<MembershipRole>(
                  tokens: tokens,
                  label: 'Initial Role',
                  value: selectedRole,
                  items: [
                    const DropdownMenuItem(
                      value: MembershipRole.employee,
                      child: Text('Employee (Standard)'),
                    ),
                    DropdownMenuItem(
                      value: MembershipRole.lead,
                      child: Text(
                        'Lead (Manage Groups)',
                        style: TextStyle(color: tokens.projectAccent),
                      ),
                    ),
                  ],
                  onChanged: (val) {
                    if (val != null) setDialogState(() => selectedRole = val);
                  },
                ),
                const SizedBox(height: 12),
                _styledDropdown<String?>(
                  tokens: tokens,
                  label: 'Department (Optional)',
                  value: selectedDeptId,
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('None (Unassigned)'),
                    ),
                    ...departments.where((d) => d.isActive).map(
                          (d) => DropdownMenuItem<String?>(
                            value: d.deptId,
                            child: Text(d.name),
                          ),
                        ),
                  ],
                  onChanged: (val) => setDialogState(() => selectedDeptId = val),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: Text(
                'Cancel',
                style: TextStyle(color: tokens.textSecondary),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                final email = emailController.text.trim();
                final name = nameController.text.trim();
                if (email.isEmpty || !email.contains('@')) {
                  SnackbarService().showSnackbar(
                    'Please enter a valid email address.',
                    isError: true,
                  );
                  return;
                }
                Navigator.pop(dialogCtx);
                try {
                  final issuedCode =
                      await DBService.instance.addPreApprovedStaff(
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
                  SnackbarService().showSnackbar(
                    'Added $email! Code: $issuedCode (valid for 5 mins)',
                  );
                } catch (e) {
                  SnackbarService().showSnackbar(
                    'Error: ${e.toString().replaceAll('Exception:', '')}',
                    isError: true,
                  );
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
  State<_StaffCodeCountdownRing> createState() =>
      _StaffCodeCountdownRingState();
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

    try {
      final newCode = await DBService.instance.resetStaffCode(
        firmId: widget.firmId,
        staffDocId: widget.staffId,
      );
      if (mounted && isManual) {
        SnackbarService().showSnackbar(
          'New code for ${widget.email}: $newCode (valid for 5 mins)',
        );
      }
    } catch (e) {
      if (mounted && isManual) {
        SnackbarService()
            .showSnackbar('Failed to reset code: $e', isError: true);
      }
    } finally {
      if (mounted) setState(() => _isResetting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.pcTokens;
    final remaining = _remainingSeconds;
    final progress = (remaining / 300.0).clamp(0.0, 1.0);

    Color ringColor = const Color(0xFF059669);
    if (remaining < 60) {
      ringColor = tokens.urgentText;
    } else if (remaining < 120) {
      ringColor = tokens.warningAccent;
    }

    final mm = remaining ~/ 60;
    final ss = (remaining % 60).toString().padLeft(2, '0');

    return Wrap(
      spacing: 6,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: tokens.surfaceSubtle,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: tokens.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.code,
                style: TextStyle(
                  color: tokens.textPrimary,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(width: 5),
              InkWell(
                onTap: () async {
                  await Clipboard.setData(ClipboardData(text: widget.code));
                  widget.onCopyFeedback();
                  SnackbarService()
                      .showSnackbar('Code ${widget.code} copied!');
                },
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: widget.hasCopied
                      ? const Icon(
                          Icons.check,
                          size: 14,
                          color: Color(0xFF059669),
                          key: ValueKey('c_ok'),
                        )
                      : Icon(
                          Icons.copy,
                          size: 14,
                          color: tokens.textMuted,
                          key: const ValueKey('c_copy'),
                        ),
                ),
              ),
            ],
          ),
        ),

        SizedBox(
          width: 26,
          height: 26,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CircularProgressIndicator(
                value: _isResetting ? null : progress,
                strokeWidth: 2.5,
                backgroundColor: tokens.border,
                valueColor: AlwaysStoppedAnimation<Color>(ringColor),
              ),
              if (!_isResetting)
                Text(
                  '$mm',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: ringColor,
                  ),
                ),
            ],
          ),
        ),

        Text(
          _isResetting ? 'Resetting...' : '$mm:$ss',
          style: TextStyle(
            color: ringColor,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),

        if (_isResetting)
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: widget.primaryColor,
            ),
          )
        else
          IconButton(
            icon: Icon(Icons.refresh, size: 16, color: widget.primaryColor),
            tooltip: 'Reset code manually',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: () => _triggerReset(isManual: true),
          ),
      ],
    );
  }
}
