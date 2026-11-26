import 'dart:async';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../../models/firm.dart';
import '../../models/notice_model.dart';
import '../../models/media_ref.dart';
import '../../models/department.dart';
import '../../services/notices_service.dart';
import '../../services/media_service.dart';
import '../../services/db_service.dart';
import '../../theme/pc_tokens.dart';
import '../../widgets/notices/notice_card.dart';

/// Composer screen supporting notice creation and editing across mobile and web.
class NoticeComposerScreen extends StatefulWidget {
  final Firm? firm;
  final String? _firmId;
  final String currentUid;
  final String currentUserName;
  final String currentUserRole;
  final String? _userDepartmentId;
  final String? _currentUserDepartmentId;
  final Color? _primaryColor;
  final bool? canTargetFirmWide;
  final NoticeModel? editingNotice;

  String get firmId => firm?.firmId ?? _firmId ?? '';
  String? get userDepartmentId => _currentUserDepartmentId ?? _userDepartmentId;
  Color get primaryColor =>
      _primaryColor ??
      (firm != null
          ? _hexToColor(firm!.primaryColor)
          : PcTokens.defaultBrandBlue);

  static Color _hexToColor(String hexString) {
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
    return PcTokens.defaultBrandBlue;
  }

  const NoticeComposerScreen({
    super.key,
    this.firm,
    String? firmId,
    required this.currentUid,
    required this.currentUserName,
    required this.currentUserRole,
    String? userDepartmentId,
    String? currentUserDepartmentId,
    Color? primaryColor,
    this.canTargetFirmWide,
    this.editingNotice,
  })  : _firmId = firmId,
        _userDepartmentId = userDepartmentId,
        _currentUserDepartmentId = currentUserDepartmentId,
        _primaryColor = primaryColor;

  @override
  State<NoticeComposerScreen> createState() => _NoticeComposerScreenState();
}

class _NoticeComposerScreenState extends State<NoticeComposerScreen> {
  int _currentStep = 0; // 0: Type & Audience, 1: Content & Media, 2: Preview

  // Notice Fields
  late NoticeType _selectedType;
  late TextEditingController _titleController;
  late TextEditingController _bodyController;
  late bool _pinned;
  DateTime? _expiresAt;
  final List<MediaRef> _media = [];
  final List<String> _videoLinks = [];
  final TextEditingController _videoLinkInputController =
      TextEditingController();

  // Audience State
  String _audienceMode =
      'everyone'; // 'everyone', 'my_department', 'selected_departments'
  List<String> _selectedAudienceKeys = ['firm'];
  List<String> _selectedAudienceNames = ['Everyone'];

  // Departments List
  List<Department> _departments = [];
  bool _leadsMayTargetBeyondOwn = true;

  // Reach Preview State
  int _reachCount = 0;
  bool _isLoadingReach = false;
  Timer? _reachDebounceTimer;

  // Image Uploading State
  bool _isUploadingImage = false;
  double _uploadProgress = 0.0;

  // Submission State
  bool _isSubmitting = false;

  bool get isEditing => widget.editingNotice != null;
  bool get isAdmin =>
      widget.currentUserRole == 'admin' ||
      widget.currentUserRole == 'super_admin';
  bool get isLead => widget.currentUserRole == 'lead';

  @override
  void initState() {
    super.initState();

    final edit = widget.editingNotice;
    if (edit != null) {
      _selectedType = edit.type;
      _titleController = TextEditingController(text: edit.title);
      _bodyController = TextEditingController(text: edit.body);
      _pinned = edit.pinned;
      _expiresAt = edit.expiresAt;
      _media.addAll(edit.media);
      _videoLinks.addAll(edit.videoLinks);
      _selectedAudienceKeys = List.from(edit.audienceKeys);
      _selectedAudienceNames = List.from(edit.audienceNames);
      _currentStep = 1; // Skip directly to content when editing
    } else {
      _selectedType = NoticeType.announcement;
      _titleController = TextEditingController();
      _bodyController = TextEditingController();
      _pinned = false;
      _expiresAt = DateTime.now().add(const Duration(days: 14));

      // Lead defaults to their own department
      if (isLead && widget.userDepartmentId != null) {
        _audienceMode = 'my_department';
        _selectedAudienceKeys = ['dept:${widget.userDepartmentId}'];
        _selectedAudienceNames = ['My Department'];
      }
    }

    _loadDepartmentsAndFirmSettings();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    _videoLinkInputController.dispose();
    _reachDebounceTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadDepartmentsAndFirmSettings() async {
    try {
      final firmDoc = await DBService.instance.getFirm(widget.firmId);
      final depts = await DBService.instance.getDepartments(widget.firmId);

      if (mounted) {
        setState(() {
          _departments = depts;
          _leadsMayTargetBeyondOwn =
              firmDoc?.leadsMayTargetBeyondOwnDepartment ?? true;
        });

        _updateAudienceDisplayNames();
        _triggerReachCalculation();
      }
    } catch (_) {}
  }

  void _updateAudienceDisplayNames() {
    if (_selectedAudienceKeys.contains('firm')) {
      _selectedAudienceNames = ['Everyone'];
      return;
    }

    final names = <String>[];
    for (final key in _selectedAudienceKeys) {
      if (key.startsWith('dept:')) {
        final deptId = key.substring(5);
        final match = _departments.firstWhere(
          (d) => d.deptId == deptId,
          orElse: () => Department(
            deptId: deptId,
            firmId: widget.firmId,
            name: 'Department',
            conversationId: '',
            createdAt: DateTime.now(),
            createdBy: '',
          ),
        );
        names.add(match.name);
      }
    }
    _selectedAudienceNames =
        names.isNotEmpty ? names : ['Selected Departments'];
  }

  void _triggerReachCalculation() {
    _reachDebounceTimer?.cancel();
    _reachDebounceTimer = Timer(const Duration(milliseconds: 300), () async {
      if (!mounted) return;
      setState(() => _isLoadingReach = true);

      final reach = await NoticesService.instance.computeReach(
        firmId: widget.firmId,
        audienceKeys: _selectedAudienceKeys,
      );

      if (mounted) {
        setState(() {
          _reachCount = reach;
          _isLoadingReach = false;
        });
      }
    });
  }

  List<NoticeType> get _allowedTypes {
    if (isAdmin) {
      return [NoticeType.announcement, NoticeType.urgent, NoticeType.policy];
    }
    if (isLead) {
      return [NoticeType.announcement, NoticeType.urgent];
    }
    return [NoticeType.announcement, NoticeType.urgent, NoticeType.policy];
  }

  // ── Image Upload Handling ───────────────────────────────────────────────────
  Future<void> _pickAndUploadImage() async {
    if (_media.length >= 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Maximum 4 images allowed per notice.')),
      );
      return;
    }

    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'webp', 'heic'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      final bytes = file.bytes;
      if (bytes == null || bytes.isEmpty) return;

      setState(() {
        _isUploadingImage = true;
        _uploadProgress = 0.1;
      });

      final mediaRef = await MediaService.instance.uploadBytes(
        bytes: bytes,
        fileName: file.name,
        purpose: MediaPurpose.notice,
        firmId: widget.firmId,
        onProgress: (p) {
          if (mounted) setState(() => _uploadProgress = p);
        },
      );

      if (mounted) {
        setState(() {
          _media.add(mediaRef);
          _isUploadingImage = false;
          _uploadProgress = 0.0;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isUploadingImage = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Upload failed: $e'),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
    }
  }

  // ── Video Link Validation ───────────────────────────────────────────────────
  void _addVideoLink() {
    final link = _videoLinkInputController.text.trim();
    if (link.isEmpty) return;

    if (!link.startsWith('https://')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Video link must use secure https:// scheme.'),
        ),
      );
      return;
    }

    if (_videoLinks.length >= 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Maximum 3 video links allowed.')),
      );
      return;
    }

    setState(() {
      _videoLinks.add(link);
      _videoLinkInputController.clear();
    });
  }

  // ── Final Submission ────────────────────────────────────────────────────────
  Future<void> _submitNotice() async {
    final tokens = context.pcTokens;
    final accent = PcTokens.readableAccentOnLight(widget.primaryColor);
    final title = _titleController.text.trim();
    final body = _bodyController.text.trim();

    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a notice title.')),
      );
      return;
    }
    if (body.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter notice body text.')),
      );
      return;
    }

    if (_selectedType != NoticeType.policy && _expiresAt == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Expiry date is required for announcements and urgent notices.',
          ),
        ),
      );
      return;
    }

    if (!isEditing && _reachCount > 50) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: tokens.surface,
          title: Text(
            'Large Audience Confirmation',
            style: TextStyle(color: tokens.textPrimary),
          ),
          content: Text(
            'This notice will reach $_reachCount people across ${_selectedAudienceNames.join(", ")}. Are you sure you want to broadcast this notice?',
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
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: accent,
                foregroundColor: PcTokens.contrastOn(accent),
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Confirm & Post'),
            ),
          ],
        ),
      );
      if (confirm != true) return;
    }

    setState(() => _isSubmitting = true);

    try {
      if (isEditing) {
        await NoticesService.instance.editNotice(
          firmId: widget.firmId,
          existingNotice: widget.editingNotice!,
          title: title,
          body: body,
          media: _media,
          videoLinks: _videoLinks,
          pinned: _pinned,
          expiresAt: _expiresAt,
        );

        final updated = widget.editingNotice!.copyWith(
          title: title,
          body: body,
          media: _media,
          videoLinks: _videoLinks,
          pinned: _pinned,
          expiresAt: _expiresAt,
          editedAt: DateTime.now(),
          version: widget.editingNotice!.isPolicy
              ? widget.editingNotice!.version + 1
              : widget.editingNotice!.version,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Notice updated successfully.')),
          );
          Navigator.of(context).pop(updated);
        }
      } else {
        final authorLabel = isAdmin
            ? 'Admin'
            : isLead
                ? 'Lead'
                : 'Publisher';

        final newId = await NoticesService.instance.createNotice(
          firmId: widget.firmId,
          type: _selectedType,
          title: title,
          body: body,
          media: _media,
          videoLinks: _videoLinks,
          audienceKeys: _selectedAudienceKeys,
          audienceNames: _selectedAudienceNames,
          authorId: widget.currentUid,
          authorName: widget.currentUserName,
          authorLabel: authorLabel,
          pinned: _pinned,
          expiresAt: _expiresAt,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: Color(0xFF059669),
              content: Text('Notice published successfully!'),
            ),
          );
          Navigator.of(context).pop(newId);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to publish notice: $e'),
            backgroundColor: tokens.urgentText,
          ),
        );
      }
    }
  }

  void _goToStep(int step) {
    if (step == 1) {
      if (_selectedAudienceKeys.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select an audience for this notice.'),
          ),
        );
        return;
      }
      if (isLead && _selectedType == NoticeType.urgent) {
        final ownKey = 'dept:${widget.userDepartmentId}';
        if (_selectedAudienceKeys.length != 1 ||
            _selectedAudienceKeys.first != ownKey) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Leads can only post urgent alerts to their own department.',
              ),
            ),
          );
          return;
        }
      }
      if (isLead && !_leadsMayTargetBeyondOwn) {
        final ownKey = 'dept:${widget.userDepartmentId}';
        if (_selectedAudienceKeys.length != 1 ||
            _selectedAudienceKeys.first != ownKey) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Firm settings restrict leads to targeting their own department only.',
              ),
            ),
          );
          return;
        }
      }
    } else if (step == 2) {
      if (_titleController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Title cannot be empty.')),
        );
        return;
      }
      if (_bodyController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Body text cannot be empty.')),
        );
        return;
      }
    }

    setState(() => _currentStep = step);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.pcTokens;
    final accent = PcTokens.readableAccentOnLight(widget.primaryColor);
    final isWide = !PcBreakpoints.isCompact(MediaQuery.sizeOf(context).width);

    final stepContent = _currentStep == 0
        ? _buildStep0TypeAndAudience(tokens, accent)
        : _currentStep == 1
            ? _buildStep1Content(tokens, accent)
            : _buildStep2Preview(tokens, accent);

    return Scaffold(
      backgroundColor: tokens.canvas,
      appBar: AppBar(
        backgroundColor: tokens.surface,
        elevation: 0,
        shape: Border(bottom: BorderSide(color: tokens.border)),
        title: Text(
          isEditing ? 'Edit Notice' : 'Compose Notice',
          style: TextStyle(
            color: tokens.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (!isEditing) _buildProgressBar(tokens, accent),
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 820),
                  child: SingleChildScrollView(
                    padding: EdgeInsets.symmetric(
                      horizontal: isWide ? 28 : 16,
                      vertical: isWide ? 24 : 16,
                    ),
                    child: isWide
                        ? Container(
                            padding: const EdgeInsets.all(28),
                            decoration: BoxDecoration(
                              color: tokens.surface,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: tokens.border),
                            ),
                            child: stepContent,
                          )
                        : stepContent,
                  ),
                ),
              ),
            ),
            _buildBottomControls(tokens, accent),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressBar(PcTokens tokens, Color accent) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: tokens.surface,
        border: Border(bottom: BorderSide(color: tokens.border)),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 780),
          child: Row(
            children: [
              _buildProgressSegment(0, 'Audience', tokens, accent),
              const SizedBox(width: 8),
              _buildProgressSegment(1, 'Content', tokens, accent),
              const SizedBox(width: 8),
              _buildProgressSegment(2, 'Preview', tokens, accent),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProgressSegment(
    int index,
    String label,
    PcTokens tokens,
    Color accent,
  ) {
    final isActive = _currentStep >= index;
    final isCurrent = _currentStep == index;

    return Expanded(
      child: Row(
        children: [
          CircleAvatar(
            radius: 11,
            backgroundColor: isCurrent
                ? accent
                : isActive
                    ? accent.withValues(alpha: 0.18)
                    : tokens.surfaceSubtle,
            child: Text(
              '${index + 1}',
              style: TextStyle(
                color: isCurrent
                    ? PcTokens.contrastOn(accent)
                    : (isActive ? accent : tokens.textMuted),
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                color: isCurrent ? tokens.textPrimary : tokens.textSecondary,
                fontSize: 12.5,
                fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // ── Step 0: Type & Audience Selection ───────────────────────────────────────
  Widget _buildStep0TypeAndAudience(PcTokens tokens, Color accent) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Notice Type',
          style: TextStyle(
            color: tokens.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: _allowedTypes.map((type) {
            final isSelected = _selectedType == type;
            final isUrgent = type == NoticeType.urgent;
            final isPolicy = type == NoticeType.policy;
            final typeColor = isUrgent
                ? tokens.urgentText
                : (isPolicy ? tokens.projectAccent : accent);
            final typeSoft = isUrgent
                ? tokens.urgentBg
                : (isPolicy
                    ? tokens.projectSoft
                    : accent.withValues(alpha: 0.10));

            return Expanded(
              child: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _selectedType = type;
                      if (isLead &&
                          isUrgent &&
                          widget.userDepartmentId != null) {
                        _audienceMode = 'my_department';
                        _selectedAudienceKeys = [
                          'dept:${widget.userDepartmentId}',
                        ];
                        _updateAudienceDisplayNames();
                        _triggerReachCalculation();
                      }
                    });
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 14,
                      horizontal: 8,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected ? typeSoft : tokens.surfaceSubtle,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? typeColor : tokens.border,
                        width: isSelected ? 1.5 : 1.0,
                      ),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          isUrgent
                              ? Icons.warning_amber_rounded
                              : isPolicy
                                  ? Icons.gavel
                                  : Icons.campaign_outlined,
                          color: isSelected ? typeColor : tokens.textSecondary,
                          size: 22,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          type.label,
                          style: TextStyle(
                            color: isSelected
                                ? tokens.textPrimary
                                : tokens.textSecondary,
                            fontSize: 12.5,
                            fontWeight:
                                isSelected ? FontWeight.w700 : FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),

        const SizedBox(height: 24),

        Row(
          children: [
            Text(
              'Audience (Required)',
              style: TextStyle(
                color: tokens.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: tokens.warningSoft,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: tokens.warningAccent.withValues(alpha: 0.30),
                ),
              ),
              child: Text(
                'IMMUTABLE AFTER POSTING',
                style: TextStyle(
                  color: tokens.warningAccent,
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        if (!(isLead &&
            (_selectedType == NoticeType.urgent || !_leadsMayTargetBeyondOwn)))
          _buildAudienceOption(
            tokens: tokens,
            accent: accent,
            title: 'Everyone (Firmwide)',
            subtitle:
                'Broadcast to all employees and departments across the firm',
            icon: Icons.public,
            selected: _audienceMode == 'everyone',
            onTap: () {
              setState(() {
                _audienceMode = 'everyone';
                _selectedAudienceKeys = ['firm'];
                _updateAudienceDisplayNames();
                _triggerReachCalculation();
              });
            },
          ),

        if (widget.userDepartmentId != null)
          _buildAudienceOption(
            tokens: tokens,
            accent: accent,
            title: 'My Department',
            subtitle:
                'Broadcast strictly to colleagues within your department',
            icon: Icons.corporate_fare,
            selected: _audienceMode == 'my_department',
            onTap: () {
              setState(() {
                _audienceMode = 'my_department';
                _selectedAudienceKeys = ['dept:${widget.userDepartmentId}'];
                _updateAudienceDisplayNames();
                _triggerReachCalculation();
              });
            },
          ),

        if (!(isLead &&
            (_selectedType == NoticeType.urgent || !_leadsMayTargetBeyondOwn)))
          _buildAudienceOption(
            tokens: tokens,
            accent: accent,
            title: 'Selected Departments',
            subtitle: 'Choose specific departments to target',
            icon: Icons.checklist_rounded,
            selected: _audienceMode == 'selected_departments',
            onTap: () => _openDepartmentPicker(tokens, accent),
          ),

        const SizedBox(height: 20),

        // Reach Preview Card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: accent.withValues(alpha: 0.25)),
          ),
          child: Row(
            children: [
              Icon(Icons.people_alt_outlined, color: accent, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _isLoadingReach
                          ? 'Computing reach...'
                          : 'Estimated Reach: $_reachCount people',
                      style: TextStyle(
                        color: tokens.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Targeting: ${_selectedAudienceNames.join(", ")}',
                      style: TextStyle(
                        color: tokens.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (_reachCount > 50)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: tokens.warningSoft,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'BROADCAST',
                    style: TextStyle(
                      color: tokens.warningAccent,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAudienceOption({
    required PcTokens tokens,
    required Color accent,
    required String title,
    required String subtitle,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: selected
                ? accent.withValues(alpha: 0.08)
                : tokens.surfaceSubtle,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? accent : tokens.border,
              width: selected ? 1.5 : 1.0,
            ),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: selected ? accent : tokens.textSecondary,
                size: 22,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: tokens.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: tokens.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (selected) Icon(Icons.check_circle, color: accent, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  void _openDepartmentPicker(PcTokens tokens, Color accent) {
    final tempSelected = List<String>.from(
      _selectedAudienceKeys.where((k) => k.startsWith('dept:')),
    );
    String search = '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: tokens.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final filtered = _departments.where((d) {
              return d.name.toLowerCase().contains(search.toLowerCase());
            }).toList();

            final allSelected = filtered.isNotEmpty &&
                filtered.every(
                  (d) => tempSelected.contains('dept:${d.deptId}'),
                );

            return Container(
              height: MediaQuery.sizeOf(context).height * 0.72,
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Select Departments',
                        style: TextStyle(
                          color: tokens.textPrimary,
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          setSheetState(() {
                            if (allSelected) {
                              tempSelected.clear();
                            } else {
                              for (final d in filtered) {
                                final key = 'dept:${d.deptId}';
                                if (!tempSelected.contains(key)) {
                                  tempSelected.add(key);
                                }
                              }
                            }
                          });
                        },
                        child: Text(
                          allSelected ? 'Deselect All' : 'Select All',
                          style: TextStyle(color: accent),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    onChanged: (val) => setSheetState(() => search = val),
                    style: TextStyle(color: tokens.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'Search departments...',
                      prefixIcon: Icon(Icons.search, color: tokens.textMuted),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (context, idx) {
                        final dept = filtered[idx];
                        final key = 'dept:${dept.deptId}';
                        final isChecked = tempSelected.contains(key);

                        return CheckboxListTile(
                          value: isChecked,
                          title: Text(
                            dept.name,
                            style: TextStyle(color: tokens.textPrimary),
                          ),
                          activeColor: accent,
                          checkColor: PcTokens.contrastOn(accent),
                          onChanged: (val) {
                            setSheetState(() {
                              if (val == true) {
                                tempSelected.add(key);
                              } else {
                                tempSelected.remove(key);
                              }
                            });
                          },
                        );
                      },
                    ),
                  ),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accent,
                        foregroundColor: PcTokens.contrastOn(accent),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: () {
                        if (tempSelected.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Please select at least one department.',
                              ),
                            ),
                          );
                          return;
                        }
                        setState(() {
                          _audienceMode = 'selected_departments';
                          _selectedAudienceKeys = List.from(tempSelected);
                          _updateAudienceDisplayNames();
                          _triggerReachCalculation();
                        });
                        Navigator.pop(sheetCtx);
                      },
                      child: Text('Done (${tempSelected.length} Selected)'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ── Step 1: Content, Images, Links, Expiry ──────────────────────────────────
  Widget _buildStep1Content(PcTokens tokens, Color accent) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Title',
              style: TextStyle(
                color: tokens.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              '${_titleController.text.length}/120',
              style: TextStyle(color: tokens.textMuted, fontSize: 11),
            ),
          ],
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _titleController,
          maxLength: 120,
          onChanged: (_) => setState(() {}),
          style: TextStyle(
            color: tokens.textPrimary,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
          decoration: const InputDecoration(
            counterText: '',
            hintText: 'Enter a concise, clear title...',
          ),
        ),

        const SizedBox(height: 16),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Body Content',
              style: TextStyle(
                color: tokens.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              '${_bodyController.text.length}/2000',
              style: TextStyle(color: tokens.textMuted, fontSize: 11),
            ),
          ],
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _bodyController,
          maxLength: 2000,
          maxLines: 6,
          onChanged: (_) => setState(() {}),
          style: TextStyle(
            color: tokens.textPrimary,
            fontSize: 14,
            height: 1.45,
          ),
          decoration: const InputDecoration(
            counterText: '',
            hintText:
                'Plain text notice content (line breaks and links are preserved)...',
          ),
        ),

        const SizedBox(height: 20),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Images (up to 4)',
              style: TextStyle(
                color: tokens.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              '${_media.length}/4',
              style: TextStyle(color: tokens.textMuted, fontSize: 12),
            ),
          ],
        ),
        const SizedBox(height: 8),

        if (_media.isNotEmpty)
          SizedBox(
            height: 100,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _media.length,
              itemBuilder: (context, idx) {
                final media = _media[idx];
                final url =
                    MediaService.instance.urlFor(media, MediaVariant.noticeCard);

                return Stack(
                  children: [
                    Container(
                      margin: const EdgeInsets.only(right: 10),
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: tokens.border),
                        image: DecorationImage(
                          image: NetworkImage(url),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    Positioned(
                      top: 4,
                      right: 14,
                      child: GestureDetector(
                        onTap: () => setState(() => _media.removeAt(idx)),
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: const BoxDecoration(
                            color: Colors.black87,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.close,
                            color: Colors.white,
                            size: 14,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),

        if (_isUploadingImage) ...[
          const SizedBox(height: 8),
          LinearProgressIndicator(value: _uploadProgress, color: accent),
          const SizedBox(height: 4),
          Text(
            'Uploading image...',
            style: TextStyle(color: tokens.textSecondary, fontSize: 11.5),
          ),
        ],

        if (_media.length < 4 && !_isUploadingImage) ...[
          const SizedBox(height: 8),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: tokens.textPrimary,
              side: BorderSide(color: tokens.borderStrong),
            ),
            icon: Icon(
              Icons.add_photo_alternate_outlined,
              size: 18,
              color: accent,
            ),
            label: const Text('Add Image'),
            onPressed: _pickAndUploadImage,
          ),
        ],

        const SizedBox(height: 20),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Video Links (up to 3)',
              style: TextStyle(
                color: tokens.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              '${_videoLinks.length}/3',
              style: TextStyle(color: tokens.textMuted, fontSize: 12),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ..._videoLinks.asMap().entries.map((entry) {
          final idx = entry.key;
          final url = entry.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: tokens.surfaceSubtle,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: tokens.border),
              ),
              child: Row(
                children: [
                  Icon(Icons.link, color: accent, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      url,
                      style: TextStyle(color: accent, fontSize: 12.5),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: tokens.textMuted, size: 16),
                    onPressed: () => setState(() => _videoLinks.removeAt(idx)),
                  ),
                ],
              ),
            ),
          );
        }),

        if (_videoLinks.length < 3)
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _videoLinkInputController,
                  style: TextStyle(color: tokens.textPrimary, fontSize: 13),
                  decoration: const InputDecoration(
                    hintText: 'https://youtube.com/watch?v=...',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: accent,
                  foregroundColor: PcTokens.contrastOn(accent),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 13,
                  ),
                ),
                onPressed: _addVideoLink,
                child: const Text('Add'),
              ),
            ],
          ),

        const SizedBox(height: 20),

        SwitchListTile(
          value: _pinned,
          title: Text(
            'Pin to top of feed',
            style: TextStyle(
              color: tokens.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          subtitle: Text(
            'Pinned notices appear first for addressed members',
            style: TextStyle(color: tokens.textSecondary, fontSize: 12),
          ),
          contentPadding: EdgeInsets.zero,
          onChanged: (val) => setState(() => _pinned = val),
        ),

        const SizedBox(height: 8),

        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(
            _selectedType == NoticeType.policy
                ? 'Expiry Date (Optional)'
                : 'Expiry Date (Required)',
            style: TextStyle(
              color: tokens.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          subtitle: Text(
            _expiresAt != null
                ? 'Expires on ${_expiresAt!.day}/${_expiresAt!.month}/${_expiresAt!.year}'
                : 'No expiration date',
            style: TextStyle(color: tokens.textSecondary, fontSize: 12),
          ),
          trailing: OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: accent,
              side: BorderSide(color: accent.withValues(alpha: 0.40)),
            ),
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate:
                    _expiresAt ?? DateTime.now().add(const Duration(days: 14)),
                firstDate: DateTime.now().add(const Duration(hours: 1)),
                lastDate: DateTime.now().add(const Duration(days: 90)),
              );
              if (picked != null) {
                setState(() => _expiresAt = picked);
              }
            },
            child: const Text('Select Date'),
          ),
        ),
      ],
    );
  }

  // ── Step 2: Final Preview ───────────────────────────────────────────────────
  Widget _buildStep2Preview(PcTokens tokens, Color accent) {
    final previewNotice = NoticeModel(
      id: 'preview',
      type: _selectedType,
      title: _titleController.text.trim(),
      body: _bodyController.text.trim(),
      media: _media,
      videoLinks: _videoLinks,
      audienceKeys: _selectedAudienceKeys,
      audienceNames: _selectedAudienceNames,
      authorId: widget.currentUid,
      authorName: widget.currentUserName,
      authorLabel: isAdmin ? 'Admin' : (isLead ? 'Lead' : 'Publisher'),
      pinned: _pinned,
      expiresAt: _expiresAt,
      version: isEditing ? (widget.editingNotice?.version ?? 1) : 1,
      createdAt: DateTime.now(),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Notice Preview',
          style: TextStyle(
            color: tokens.textPrimary,
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'This is how the notice card will appear to recipients in the Home feed:',
          style: TextStyle(color: tokens.textSecondary, fontSize: 12.5),
        ),
        const SizedBox(height: 16),

        NoticeCard(
          notice: previewNotice,
          primaryColor: accent,
          onTap: () {},
        ),

        const SizedBox(height: 20),

        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: tokens.surfaceSubtle,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: tokens.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Distribution Summary',
                style: TextStyle(
                  color: tokens.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),
              _buildSummaryRow(tokens, 'Notice Type', _selectedType.label),
              _buildSummaryRow(
                tokens,
                'Target Audience',
                _selectedAudienceNames.join(', '),
              ),
              _buildSummaryRow(
                tokens,
                'Estimated Reach',
                '$_reachCount active members',
              ),
              _buildSummaryRow(
                tokens,
                'Expiration',
                _expiresAt != null
                    ? '${_expiresAt!.day}/${_expiresAt!.month}/${_expiresAt!.year}'
                    : 'None (Permanent)',
              ),
              _buildSummaryRow(
                tokens,
                'Images Attached',
                '${_media.length} images',
              ),
              _buildSummaryRow(
                tokens,
                'Video Links',
                '${_videoLinks.length} links',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryRow(PcTokens tokens, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(color: tokens.textSecondary, fontSize: 12.5),
          ),
          Flexible(
            child: Text(
              value,
              style: TextStyle(
                color: tokens.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 12.5,
              ),
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomControls(PcTokens tokens, Color accent) {
    final publishBg =
        _selectedType == NoticeType.urgent ? tokens.urgentText : accent;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tokens.surface,
        border: Border(top: BorderSide(color: tokens.border)),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 780),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (_currentStep > 0 && !isEditing)
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: tokens.textPrimary,
                    side: BorderSide(color: tokens.borderStrong),
                  ),
                  onPressed: () => setState(() => _currentStep--),
                  child: const Text('Back'),
                )
              else
                const SizedBox.shrink(),

              if (_currentStep < 2)
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accent,
                    foregroundColor: PcTokens.contrastOn(accent),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                  onPressed: () => _goToStep(_currentStep + 1),
                  child: const Text('Next'),
                )
              else
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: publishBg,
                    foregroundColor: PcTokens.contrastOn(publishBg),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                  icon: _isSubmitting
                      ? SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: PcTokens.contrastOn(publishBg),
                          ),
                        )
                      : const Icon(Icons.send_rounded, size: 18),
                  label: Text(
                    _isSubmitting
                        ? 'Publishing...'
                        : (isEditing ? 'Save Changes' : 'Publish Notice'),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  onPressed: _isSubmitting ? null : _submitNotice,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
