import 'dart:async';
import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show Uint8List;
import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../models/firm.dart';
import '../../../models/media_ref.dart';
import '../../../providers/firm/providers.dart';
import '../../../services/audit_service.dart';
import '../../../services/chat_service.dart';
import '../../../services/media_service.dart';
import '../../../services/snackbar_service.dart';
import '../../../widgets/common/pc_logo.dart';

class CustomizationTab extends ConsumerStatefulWidget {
  const CustomizationTab({super.key});

  @override
  ConsumerState<CustomizationTab> createState() => _CustomizationTabState();
}

class _CustomizationTabState extends ConsumerState<CustomizationTab> {
  // Staged state for live preview & unsaved changes guard
  Color? _stagedPrimaryColor;
  String? _stagedWelcomeText;
  bool? _stagedShowLastSeen;
  bool? _stagedShowReadReceipts;
  MediaRef? _stagedLogo;
  String? _stagedLogoUrl;

  final TextEditingController _welcomeTextController = TextEditingController();

  bool _isUploadingLogo = false;
  bool _isSaving = false;
  bool _isDraggingLogo = false;

  // Live preview preview mode: 0 = Join Screen, 1 = Chat Screen
  int _previewMode = 0;

  @override
  void initState() {
    super.initState();
    final firm = ref.read(currentFirmProvider);
    if (firm != null) {
      _initFromFirm(firm);
    }
  }

  void _initFromFirm(Firm firm) {
    _stagedPrimaryColor = _hexToColor(firm.primaryColor);
    _stagedWelcomeText = firm.welcomeText ?? '';
    _welcomeTextController.text = _stagedWelcomeText!;
    _stagedShowLastSeen = firm.showLastSeen;
    _stagedShowReadReceipts = firm.showReadReceipts;
    _stagedLogo = firm.logo;
    _stagedLogoUrl = firm.logoUrl;
  }

  @override
  void dispose() {
    _welcomeTextController.dispose();
    super.dispose();
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

  String _colorToHex(Color color) {
    return '#${color.value.toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';
  }

  bool _hasUnsavedChanges(Firm firm) {
    if (_stagedPrimaryColor == null) return false;
    final firmPrimary = _hexToColor(firm.primaryColor);
    if (_stagedPrimaryColor!.value != firmPrimary.value) return true;
    if (_stagedWelcomeText != (firm.welcomeText ?? '')) return true;
    if (_stagedShowLastSeen != firm.showLastSeen) return true;
    if (_stagedShowReadReceipts != firm.showReadReceipts) return true;
    if (_stagedLogo != firm.logo) return true;
    if (_stagedLogoUrl != firm.logoUrl) return true;
    return false;
  }

  // ══════════════════════════════════════════════════════════════════════════
  // WCAG 2.1 CONTRAST RATIO CALCULATION
  // ══════════════════════════════════════════════════════════════════════════

  double _calculateLuminance(Color color) {
    double getComponent(double val) {
      return val <= 0.03928 ? val / 12.92 : math.pow((val + 0.055) / 1.055, 2.4).toDouble();
    }

    final r = getComponent(color.red / 255.0);
    final g = getComponent(color.green / 255.0);
    final b = getComponent(color.blue / 255.0);
    return 0.2126 * r + 0.7152 * g + 0.0722 * b;
  }

  double _calculateContrastRatio(Color c1, Color c2) {
    final l1 = _calculateLuminance(c1);
    final l2 = _calculateLuminance(c2);
    final lighter = math.max(l1, l2);
    final darker = math.min(l1, l2);
    return (lighter + 0.05) / (darker + 0.05);
  }

  @override
  Widget build(BuildContext context) {
    final firm = ref.watch(currentFirmProvider);
    if (firm == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_stagedPrimaryColor == null) {
      _initFromFirm(firm);
    }

    final primaryColor = _stagedPrimaryColor ?? _hexToColor(firm.primaryColor);
    final hasChanges = _hasUnsavedChanges(firm);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 900;

        return SingleChildScrollView(
          padding: EdgeInsets.all(isMobile ? 14 : 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Card
              _buildCustomizationHeader(context, firm, primaryColor, isMobile),
              const SizedBox(height: 18),

              // Unsaved changes banner
              if (hasChanges) ...[
                _buildUnsavedChangesBanner(context, firm, primaryColor),
                const SizedBox(height: 18),
              ],

              // Main Layout: Configuration Column & Live Preview Column
              if (isMobile) ...[
                _buildConfigurationSection(context, firm, primaryColor),
                const SizedBox(height: 24),
                _buildLivePreviewDeviceFrame(context, firm, primaryColor),
              ] else ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 6,
                      child: _buildConfigurationSection(context, firm, primaryColor),
                    ),
                    const SizedBox(width: 24),
                    Expanded(
                      flex: 4,
                      child: _buildLivePreviewDeviceFrame(context, firm, primaryColor),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: 32),

              // Danger Zone (Collapsed)
              _buildDangerZone(context, firm),
            ],
          ),
        );
      },
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // HEADER & UNSAVED CHANGES BANNER
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildCustomizationHeader(BuildContext context, Firm firm, Color primaryColor, bool isMobile) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E1D1D),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      padding: EdgeInsets.all(isMobile ? 16 : 22),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: primaryColor.withOpacity(0.14),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.palette_outlined, color: primaryColor, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Workspace Customization & Branding',
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 2),
                Text(
                  'Personalize your firm logo, brand palette, employee welcome text, and chat privacy policies.',
                  style: TextStyle(color: Colors.grey[400], fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUnsavedChangesBanner(BuildContext context, Firm firm, Color primaryColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: primaryColor.withOpacity(0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: primaryColor.withOpacity(0.5)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: primaryColor, size: 20),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'You have unsaved branding changes. Save to apply them firm-wide.',
              style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
          TextButton(
            onPressed: () => setState(() => _initFromFirm(firm)),
            child: const Text('Discard', style: TextStyle(color: Colors.grey)),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: _isSaving ? null : () => _saveCustomizations(context, firm),
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            ),
            child: _isSaving
                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Save Changes'),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // CONFIGURATION SECTION: LOGO, PALETTE, WELCOME TEXT, PRIVACY
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildConfigurationSection(BuildContext context, Firm firm, Color primaryColor) {
    // WCAG contrast against dark container background (#161515) and white text
    final bgDark = const Color(0xFF161515);
    final contrastAgainstDark = _calculateContrastRatio(primaryColor, bgDark);
    final contrastWhiteText = _calculateContrastRatio(Colors.white, primaryColor);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Logo Card
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1D1D),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.06)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Company Brand Logo',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
              ),
              const SizedBox(height: 4),
              Text(
                'Upload your company icon or seal. Dual-write supports Cloudinary named transformations.',
                style: TextStyle(color: Colors.grey[400], fontSize: 12),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  PcLogo(
                    logo: _stagedLogo,
                    legacyUrl: _stagedLogoUrl,
                    size: 56,
                    borderRadius: 12,
                    variant: MediaVariant.logoSm,
                    firmName: firm.name,
                    primaryColor: primaryColor,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: DropTarget(
                      onDragEntered: (_) => setState(() => _isDraggingLogo = true),
                      onDragExited: (_) => setState(() => _isDraggingLogo = false),
                      onDragDone: (details) async {
                        setState(() => _isDraggingLogo = false);
                        if (details.files.isNotEmpty) {
                          final file = details.files.first;
                          final bytes = await file.readAsBytes();
                          _uploadLogoBytes(bytes, file.name, firm);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                        decoration: BoxDecoration(
                          color: _isDraggingLogo ? primaryColor.withOpacity(0.1) : const Color(0xFF161515),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _isDraggingLogo ? primaryColor : Colors.white.withOpacity(0.1),
                            style: BorderStyle.solid,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.file_upload_outlined, size: 20, color: Colors.grey[400]),
                            const SizedBox(width: 8),
                            const Text(
                              'Drop image or ',
                              style: TextStyle(color: Colors.grey, fontSize: 12),
                            ),
                            InkWell(
                              onTap: _isUploadingLogo ? null : () => _pickAndUploadLogo(context, firm),
                              child: Text(
                                _isUploadingLogo ? 'Uploading...' : 'Browse',
                                style: TextStyle(
                                  color: primaryColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 2. Brand Color Palette & WCAG 2.1 Checker
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1D1D),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.06)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Brand Accent Color',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  InkWell(
                    onTap: () => _openColorPickerDialog(context, primaryColor),
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: primaryColor.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: primaryColor.withOpacity(0.4)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 14,
                            height: 14,
                            decoration: BoxDecoration(color: primaryColor, shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _colorToHex(primaryColor),
                            style: TextStyle(color: primaryColor, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.colorize, size: 14, color: Colors.grey),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Curated harmonious presets
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  const Color(0xFF00C853), // Electric Green
                  const Color(0xFF295CB4), // Pronto Classic Blue
                  const Color(0xFF7C4DFF), // Royal Indigo
                  const Color(0xFF00B0FF), // Cyan Accent
                  const Color(0xFFFF6D00), // Amber Coral
                  const Color(0xFFE91E63), // Vivid Rose
                  const Color(0xFF00E676), // Mint Emerald
                ].map((preset) {
                  final isChosen = preset.value == primaryColor.value;
                  return InkWell(
                    onTap: () => setState(() => _stagedPrimaryColor = preset),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: preset,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isChosen ? Colors.white : Colors.transparent,
                          width: 2.5,
                        ),
                      ),
                      child: isChosen ? const Icon(Icons.check, size: 16, color: Colors.white) : null,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              Divider(color: Colors.white.withOpacity(0.06), height: 1),
              const SizedBox(height: 14),

              // WCAG 2.1 Contrast Ratio Badge
              Row(
                children: [
                  Icon(Icons.accessibility_new_rounded, size: 18, color: primaryColor),
                  const SizedBox(width: 8),
                  const Text('WCAG 2.1 Accessibility:', style: TextStyle(color: Colors.grey, fontSize: 12)),
                  const SizedBox(width: 8),
                  _buildWcagBadge('Text on Brand', contrastWhiteText),
                  const SizedBox(width: 8),
                  _buildWcagBadge('Brand on Dark', contrastAgainstDark),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 3. Employee Join Screen Welcome Message
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1D1D),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.06)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Join Screen Welcome Message',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
              ),
              const SizedBox(height: 4),
              Text(
                'Displayed to employees when they scan the QR code or enter the Firm ID (max 200 characters).',
                style: TextStyle(color: Colors.grey[400], fontSize: 12),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _welcomeTextController,
                maxLength: 200,
                maxLines: 2,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'e.g. Welcome to Acme Corp! Enter your staff code or request access.',
                  hintStyle: TextStyle(color: Colors.grey[600], fontSize: 13),
                  filled: true,
                  fillColor: const Color(0xFF161515),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onChanged: (val) => setState(() => _stagedWelcomeText = val.trim()),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 4. Chat & Privacy Policies
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1D1D),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.06)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Chat & Presence Policies',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
              ),
              const SizedBox(height: 4),
              Text(
                'Firm-wide communication privacy toggles.',
                style: TextStyle(color: Colors.grey[400], fontSize: 12),
              ),
              const SizedBox(height: 8),
              Material(
                color: Colors.transparent,
                child: Column(
                  children: [
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      activeColor: primaryColor,
                      title: const Text('Show Last Seen & Online Presence',
                          style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                      subtitle: const Text('Allow members to see when teammates were last active in chats.',
                          style: TextStyle(color: Colors.grey, fontSize: 11)),
                      value: _stagedShowLastSeen ?? firm.showLastSeen,
                      onChanged: (val) => setState(() => _stagedShowLastSeen = val),
                    ),
                    Divider(color: Colors.white.withOpacity(0.06), height: 16),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      activeColor: primaryColor,
                      title: const Text('Show Read Receipts',
                          style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                      subtitle: const Text('Show double checkmarks in direct messages and participant counts in groups.',
                          style: TextStyle(color: Colors.grey, fontSize: 11)),
                      value: _stagedShowReadReceipts ?? firm.showReadReceipts,
                      onChanged: (val) => setState(() => _stagedShowReadReceipts = val),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildWcagBadge(String label, double ratio) {
    final passesAA = ratio >= 4.5;
    final passesAAA = ratio >= 7.0;

    Color badgeColor = Colors.greenAccent;
    String grade = 'AAA';
    if (!passesAAA && passesAA) {
      grade = 'AA';
      badgeColor = Colors.lightGreenAccent;
    } else if (!passesAA) {
      grade = 'FAIL';
      badgeColor = Colors.redAccent;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: badgeColor.withOpacity(0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: badgeColor.withOpacity(0.5)),
      ),
      child: Text(
        '$label: ${ratio.toStringAsFixed(1)}:1 ($grade)',
        style: TextStyle(color: badgeColor, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // LIVE PREVIEW DEVICE FRAME
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildLivePreviewDeviceFrame(BuildContext context, Firm firm, Color primaryColor) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E1D1D),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.phone_iphone, color: Colors.grey, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Interactive Live Preview',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ],
              ),
              // Segmented toggle
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF161515),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    _buildPreviewTabBtn(0, 'Join Screen'),
                    _buildPreviewTabBtn(1, 'Chat Home'),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Phone Mockup Frame
          Center(
            child: Container(
              width: 290,
              height: 520,
              decoration: BoxDecoration(
                color: const Color(0xFF121111),
                borderRadius: BorderRadius.circular(32),
                border: Border.all(color: Colors.grey[800]!, width: 4),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 20, spreadRadius: 2),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: Column(
                  children: [
                    // Phone Top Notch
                    Container(
                      height: 24,
                      color: Colors.black,
                      child: Center(
                        child: Container(
                          width: 70,
                          height: 8,
                          decoration: BoxDecoration(
                            color: Colors.grey[900],
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ),

                    // Phone Screen Content
                    Expanded(
                      child: _previewMode == 0
                          ? _buildLiveJoinScreenPreview(firm, primaryColor)
                          : _buildLiveChatScreenPreview(firm, primaryColor),
                    ),

                    // Phone Bottom Pill Bar
                    Container(
                      height: 16,
                      color: Colors.black,
                      child: Center(
                        child: Container(
                          width: 80,
                          height: 3,
                          decoration: BoxDecoration(
                            color: Colors.grey[700],
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewTabBtn(int mode, String label) {
    final isSelected = _previewMode == mode;
    return InkWell(
      onTap: () => setState(() => _previewMode = mode),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white.withOpacity(0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey[400],
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildLiveJoinScreenPreview(Firm firm, Color primaryColor) {
    final welcome = _stagedWelcomeText?.isNotEmpty == true
        ? _stagedWelcomeText!
        : (firm.welcomeText ?? 'Welcome to ${firm.name}');

    return Container(
      color: const Color(0xFF161515),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          PcLogo(
            logo: _stagedLogo,
            legacyUrl: _stagedLogoUrl,
            size: 64,
            borderRadius: 16,
            variant: MediaVariant.logoSm,
            firmName: firm.name,
            primaryColor: primaryColor,
          ),
          const SizedBox(height: 14),
          Text(
            firm.name,
            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            welcome,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[400], fontSize: 11),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 24),

          // Sample input box
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF1F1E1E),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
            ),
            child: Row(
              children: [
                Icon(Icons.key, size: 14, color: Colors.grey[500]),
                const SizedBox(width: 8),
                Text('Enter 6-digit staff code', style: TextStyle(color: Colors.grey[500], fontSize: 11)),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Primary Join Button
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: primaryColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Center(
              child: Text(
                'Join Workspace',
                style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLiveChatScreenPreview(Firm firm, Color primaryColor) {
    final showLastSeen = _stagedShowLastSeen ?? firm.showLastSeen;
    final showReceipts = _stagedShowReadReceipts ?? firm.showReadReceipts;

    return Container(
      color: const Color(0xFF141313),
      child: Column(
        children: [
          // Mock AppBar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            color: primaryColor,
            child: Row(
              children: [
                PcLogo(
                  logo: _stagedLogo,
                  legacyUrl: _stagedLogoUrl,
                  size: 24,
                  borderRadius: 6,
                  variant: MediaVariant.logoSm,
                  firmName: firm.name,
                  primaryColor: Colors.white,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '#all-staff',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                      if (showLastSeen)
                        const Text(
                          'Online • 5 active',
                          style: TextStyle(color: Colors.white70, fontSize: 9),
                        ),
                    ],
                  ),
                ),
                const Icon(Icons.search, size: 16, color: Colors.white),
              ],
            ),
          ),

          // Mock Chat Feed
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(10),
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF222121),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Sarah Lead', style: TextStyle(color: Colors.purpleAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 2),
                        const Text('Welcome to our newly branded team space!', style: TextStyle(color: Colors.white, fontSize: 11)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: primaryColor.withOpacity(0.85),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text('Excited to collaborate!', style: TextStyle(color: Colors.white, fontSize: 11)),
                        const SizedBox(height: 2),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('10:42 AM', style: TextStyle(color: Colors.white70, fontSize: 8)),
                            if (showReceipts) ...[
                              const SizedBox(width: 4),
                              const Icon(Icons.done_all, size: 10, color: Colors.white70),
                            ],
                          ],
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
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // ACTIONS: SAVE, UPLOAD LOGO, PICK COLOR, DANGER ZONE
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> _pickAndUploadLogo(BuildContext context, Firm firm) async {
    try {
      final result = await FilePicker.pickFiles(type: FileType.image, withData: true);
      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      if (file.bytes == null) {
        SnackbarService().showSnackbar('Could not read image bytes.', isError: true);
        return;
      }
      await _uploadLogoBytes(file.bytes!, file.name, firm);
    } catch (e) {
      SnackbarService().showSnackbar('Error selecting image: $e', isError: true);
    }
  }

  Future<void> _uploadLogoBytes(Uint8List bytes, String fileName, Firm firm) async {
    setState(() => _isUploadingLogo = true);
    SnackbarService().showSnackbar('Uploading brand logo to Cloudinary...');

    try {
      final mediaRef = await MediaService.instance.uploadBytes(
        bytes: bytes,
        fileName: fileName,
        purpose: MediaPurpose.logo,
        firmId: firm.firmId,
      );
      final downloadUrl = MediaService.instance.urlFor(mediaRef, MediaVariant.logoLg);

      setState(() {
        _stagedLogo = mediaRef;
        _stagedLogoUrl = downloadUrl;
        _isUploadingLogo = false;
      });
      SnackbarService().showSnackbar('Logo uploaded! Click "Save Changes" to apply.');
    } catch (e) {
      setState(() => _isUploadingLogo = false);
      SnackbarService().showSnackbar('Logo upload failed: $e', isError: true);
    }
  }

  void _openColorPickerDialog(BuildContext context, Color initialColor) {
    Color pickerColor = initialColor;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF222121),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Select Brand Accent Color', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: ColorPicker(
            pickerColor: pickerColor,
            onColorChanged: (c) => pickerColor = c,
            labelTypes: const [],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() => _stagedPrimaryColor = pickerColor);
            },
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveCustomizations(BuildContext context, Firm firm) async {
    setState(() => _isSaving = true);
    final hexString = _colorToHex(_stagedPrimaryColor ?? _hexToColor(firm.primaryColor));
    final welcome = _stagedWelcomeText ?? (firm.welcomeText ?? '');

    try {
      final updateData = <String, dynamic>{
        'primaryColor': hexString,
        'welcomeText': welcome,
        'showLastSeen': _stagedShowLastSeen ?? firm.showLastSeen,
        'showReadReceipts': _stagedShowReadReceipts ?? firm.showReadReceipts,
      };

      if (_stagedLogo != null) {
        updateData['logo'] = _stagedLogo!.toMap();
      }
      if (_stagedLogoUrl != null) {
        updateData['logoUrl'] = _stagedLogoUrl;
      }

      await FirebaseFirestore.instance.collection('Firms').doc(firm.firmId).update(updateData);

      // Audit log
      await AuditService.instance.logAction(
        firmId: firm.firmId,
        action: 'update_branding',
        targetType: 'firm',
        targetId: firm.firmId,
        targetLabel: 'Brand settings updated',
      );

      await ref.read(firmNotifierProvider.notifier).loadFirm(firm.firmId);
      SnackbarService().showSnackbar('Branding settings saved successfully!');
    } catch (e) {
      SnackbarService().showSnackbar('Error saving branding: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // DANGER ZONE (COLLAPSIBLE)
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildDangerZone(BuildContext context, Firm firm) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E1D1D),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
      ),
      child: ExpansionTile(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 20),
            SizedBox(width: 8),
            Text(
              'Danger Zone: Delete Firm',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.redAccent, fontSize: 14),
            ),
          ],
        ),
        childrenPadding: const EdgeInsets.all(18),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Permanently Erase Firm Workspace',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'All memberships, department channels, project groups, notices, and data will be permanently removed. This action cannot be undone.',
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              ElevatedButton(
                onPressed: () => _deleteFirm(context, firm),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red[700], foregroundColor: Colors.white),
                child: const Text('Delete Firm'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _deleteFirm(BuildContext context, Firm firm) async {
    final firstConfirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF222121),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Firm Workspace?'),
        content: const Text(
          'Are you sure you want to delete this firm? All staff memberships and data will be permanently erased. This is irreversible.',
          style: TextStyle(color: Colors.grey, fontSize: 13),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red[600]),
            child: const Text('Confirm Delete'),
          ),
        ],
      ),
    );

    if (firstConfirm != true) return;

    final nameController = TextEditingController();
    if (!context.mounted) return;

    final doubleConfirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF222121),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Double Confirmation Required'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('To confirm deletion, please type the exact firm name:'),
            const SizedBox(height: 8),
            Text(firm.name, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.redAccent)),
            const SizedBox(height: 16),
            TextField(
              controller: nameController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Enter firm name',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              if (nameController.text.trim() == firm.name) {
                Navigator.pop(ctx, true);
              } else {
                SnackbarService().showSnackbar('Firm name does not match!', isError: true);
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
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
        if (mounted && context.mounted) context.go('/register-firm');
      } catch (e) {
        SnackbarService().showSnackbar('Error deleting firm: $e', isError: true);
      }
    }
  }
}
