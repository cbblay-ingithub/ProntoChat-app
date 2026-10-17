import 'dart:async';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../models/firm.dart';
import '../../models/notice_model.dart';
import '../../models/media_ref.dart';
import '../../models/department.dart';
import '../../services/notices_service.dart';
import '../../services/media_service.dart';
import '../../services/db_service.dart';
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
          : const Color(0xFF2974BC));

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
    return const Color(0xFF2974BC);
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
  final TextEditingController _videoLinkInputController = TextEditingController();

  // Audience State
  String _audienceMode = 'everyone'; // 'everyone', 'my_department', 'selected_departments'
  List<String> _selectedAudienceKeys = ['firm'];
  List<String> _selectedAudienceNames = ['Everyone'];

  // Departments List
  List<Department> _departments = [];
  bool _isLoadingDepts = true;
  bool _leadsMayTargetBeyondOwn = true;

  // Reach Preview State
  int _reachCount = 0;
  bool _isLoadingReach = false;
  Timer? _reachDebounceTimer;

  // Image Uploading State
  bool _isUploadingImage = false;
  double _uploadProgress = 0.0;
  String? _uploadError;

  // Submission State
  bool _isSubmitting = false;

  bool get isEditing => widget.editingNotice != null;
  bool get isAdmin => widget.currentUserRole == 'admin' || widget.currentUserRole == 'super_admin';
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
      _expiresAt = DateTime.now().add(const Duration(days: 14)); // default 14 days

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
          _leadsMayTargetBeyondOwn = firmDoc?.leadsMayTargetBeyondOwnDepartment ?? true;
          _isLoadingDepts = false;
        });

        // Resolve initial audience display names
        _updateAudienceDisplayNames();
        _triggerReachCalculation();
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingDepts = false);
    }
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
    _selectedAudienceNames = names.isNotEmpty ? names : ['Selected Departments'];
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

  // ── Allowed Notice Types for Current User ───────────────────────────────────
  List<NoticeType> get _allowedTypes {
    if (isAdmin) {
      return [NoticeType.announcement, NoticeType.urgent, NoticeType.policy];
    }
    if (isLead) {
      return [NoticeType.announcement, NoticeType.urgent];
    }
    // Granted publisher
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
        _uploadError = null;
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
          _uploadError = e.toString();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e'), backgroundColor: Colors.redAccent),
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
        const SnackBar(content: Text('Video link must use secure https:// scheme.')),
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

    // Expiry check for announcement and urgent
    if (_selectedType != NoticeType.policy && _expiresAt == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Expiry date is required for announcements and urgent notices.')),
      );
      return;
    }

    // Check reach threshold confirmation: if reach > 50 people or large audience
    if (!isEditing && _reachCount > 50) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color.fromRGBO(34, 33, 33, 1),
          title: const Text('Large Audience Confirmation', style: TextStyle(color: Colors.white)),
          content: Text(
            'This notice will reach $_reachCount people across ${_selectedAudienceNames.join(", ")}. Are you sure you want to broadcast this notice?',
            style: const TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: widget.primaryColor),
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
              backgroundColor: Colors.green,
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
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  // ── Step Navigation & Validation ───────────────────────────────────────────
  void _goToStep(int step) {
    if (step == 1) {
      if (_selectedAudienceKeys.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select an audience for this notice.')),
        );
        return;
      }
      // Lead urgent check: lead can only target own department
      if (isLead && _selectedType == NoticeType.urgent) {
        final ownKey = 'dept:${widget.userDepartmentId}';
        if (_selectedAudienceKeys.length != 1 || _selectedAudienceKeys.first != ownKey) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Leads can only post urgent alerts to their own department.')),
          );
          return;
        }
      }
      // Lead announcement setting check
      if (isLead && !_leadsMayTargetBeyondOwn) {
        final ownKey = 'dept:${widget.userDepartmentId}';
        if (_selectedAudienceKeys.length != 1 || _selectedAudienceKeys.first != ownKey) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Firm settings restrict leads to targeting their own department only.')),
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
    return Scaffold(
      backgroundColor: const Color.fromRGBO(28, 27, 27, 1),
      appBar: AppBar(
        backgroundColor: const Color.fromRGBO(28, 27, 27, 1),
        elevation: 0,
        title: Text(
          isEditing ? 'Edit Notice' : 'Compose Notice',
          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Step Progress Bar
            if (!isEditing) _buildProgressBar(),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: _currentStep == 0
                    ? _buildStep0TypeAndAudience()
                    : _currentStep == 1
                        ? _buildStep1Content()
                        : _buildStep2Preview(),
              ),
            ),

            // Bottom Navigation Footer
            _buildBottomControls(),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: const Color.fromRGBO(34, 33, 33, 1),
        border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.06))),
      ),
      child: Row(
        children: [
          _buildProgressSegment(0, 'Audience'),
          const SizedBox(width: 8),
          _buildProgressSegment(1, 'Content'),
          const SizedBox(width: 8),
          _buildProgressSegment(2, 'Preview'),
        ],
      ),
    );
  }

  Widget _buildProgressSegment(int index, String label) {
    final isActive = _currentStep >= index;
    final isCurrent = _currentStep == index;

    return Expanded(
      child: Row(
        children: [
          CircleAvatar(
            radius: 11,
            backgroundColor: isCurrent
                ? widget.primaryColor
                : isActive
                    ? widget.primaryColor.withOpacity(0.4)
                    : Colors.white.withOpacity(0.12),
            child: Text(
              '${index + 1}',
              style: TextStyle(
                color: isCurrent || isActive ? Colors.white : Colors.grey,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                color: isCurrent ? Colors.white : Colors.grey[400],
                fontSize: 12,
                fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // ── Step 0: Type & Audience Selection ───────────────────────────────────────
  Widget _buildStep0TypeAndAudience() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Notice Type',
          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        Row(
          children: _allowedTypes.map((type) {
            final isSelected = _selectedType == type;
            final isUrgent = type == NoticeType.urgent;
            final isPolicy = type == NoticeType.policy;

            return Expanded(
              child: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _selectedType = type;
                      // Auto-restrict lead to own department if urgent
                      if (isLead && isUrgent && widget.userDepartmentId != null) {
                        _audienceMode = 'my_department';
                        _selectedAudienceKeys = ['dept:${widget.userDepartmentId}'];
                        _updateAudienceDisplayNames();
                        _triggerReachCalculation();
                      }
                    });
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? (isUrgent
                              ? Colors.redAccent.withOpacity(0.2)
                              : isPolicy
                                  ? Colors.indigoAccent.withOpacity(0.25)
                                  : widget.primaryColor.withOpacity(0.22))
                          : const Color.fromRGBO(36, 35, 35, 1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? (isUrgent
                                ? Colors.redAccent
                                : isPolicy
                                    ? Colors.indigoAccent
                                    : widget.primaryColor)
                            : Colors.white.withOpacity(0.08),
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
                          color: isSelected
                              ? (isUrgent
                                  ? Colors.redAccent
                                  : isPolicy
                                      ? Colors.indigoAccent
                                      : widget.primaryColor)
                              : Colors.grey,
                          size: 22,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          type.label,
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.grey[400],
                            fontSize: 12,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
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

        // Audience Section (REQUIRED)
        Row(
          children: [
            const Text(
              'Audience (Required)',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.2),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                'IMMUTABLE AFTER POSTING',
                style: TextStyle(color: Colors.amberAccent, fontSize: 9, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Everyone Option
        if (!(isLead && (_selectedType == NoticeType.urgent || !_leadsMayTargetBeyondOwn)))
          _buildAudienceOption(
            title: 'Everyone (Firmwide)',
            subtitle: 'Broadcast to all employees and departments across the firm',
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

        // My Department Option
        if (widget.userDepartmentId != null)
          _buildAudienceOption(
            title: 'My Department',
            subtitle: 'Broadcast strictly to colleagues within your department',
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

        // Selected Departments Option
        if (!(isLead && (_selectedType == NoticeType.urgent || !_leadsMayTargetBeyondOwn)))
          _buildAudienceOption(
            title: 'Selected Departments',
            subtitle: 'Choose specific departments to target',
            icon: Icons.checklist_rounded,
            selected: _audienceMode == 'selected_departments',
            onTap: () => _openDepartmentPicker(),
          ),

        const SizedBox(height: 20),

        // Reach Preview Card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color.fromRGBO(34, 33, 33, 1),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: widget.primaryColor.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              Icon(Icons.people_alt_outlined, color: widget.primaryColor, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _isLoadingReach ? 'Computing reach...' : 'Estimated Reach: $_reachCount people',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Targeting: ${_selectedAudienceNames.join(", ")}',
                      style: TextStyle(color: Colors.grey[400], fontSize: 12),
                    ),
                  ],
                ),
              ),
              if (_reachCount > 50)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'BROADCAST',
                    style: TextStyle(color: Colors.orangeAccent, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAudienceOption({
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
                ? widget.primaryColor.withOpacity(0.15)
                : const Color.fromRGBO(34, 33, 33, 1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? widget.primaryColor : Colors.white.withOpacity(0.07),
              width: selected ? 1.4 : 1.0,
            ),
          ),
          child: Row(
            children: [
              Icon(icon, color: selected ? widget.primaryColor : Colors.grey, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: selected ? Colors.white : Colors.white70,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(subtitle, style: TextStyle(color: Colors.grey[400], fontSize: 12)),
                  ],
                ),
              ),
              if (selected)
                Icon(Icons.check_circle, color: widget.primaryColor, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  void _openDepartmentPicker() {
    final tempSelected = List<String>.from(_selectedAudienceKeys.where((k) => k.startsWith('dept:')));
    String search = '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color.fromRGBO(34, 33, 33, 1),
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
                filtered.every((d) => tempSelected.contains('dept:${d.deptId}'));

            return Container(
              height: MediaQuery.of(context).size.height * 0.75,
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Select Departments',
                        style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
                      ),
                      TextButton(
                        onPressed: () {
                          setSheetState(() {
                            if (allSelected) {
                              tempSelected.clear();
                            } else {
                              for (final d in filtered) {
                                final key = 'dept:${d.deptId}';
                                if (!tempSelected.contains(key)) tempSelected.add(key);
                              }
                            }
                          });
                        },
                        child: Text(allSelected ? 'Deselect All' : 'Select All'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    onChanged: (val) => setSheetState(() => search = val),
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Search departments...',
                      hintStyle: TextStyle(color: Colors.grey[500]),
                      prefixIcon: const Icon(Icons.search, color: Colors.grey),
                      filled: true,
                      fillColor: const Color.fromRGBO(24, 23, 23, 1),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
                      ),
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
                          title: Text(dept.name, style: const TextStyle(color: Colors.white)),
                          activeColor: widget.primaryColor,
                          checkColor: Colors.white,
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
                        backgroundColor: widget.primaryColor,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: () {
                        if (tempSelected.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Please select at least one department.')),
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
  Widget _buildStep1Content() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title Field (Max 120)
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Title',
              style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
            ),
            Text(
              '${_titleController.text.length}/120',
              style: TextStyle(color: Colors.grey[500], fontSize: 11),
            ),
          ],
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _titleController,
          maxLength: 120,
          onChanged: (_) => setState(() {}),
          style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
          decoration: InputDecoration(
            counterText: '',
            hintText: 'Enter a concise, clear title...',
            hintStyle: TextStyle(color: Colors.grey[500]),
            filled: true,
            fillColor: const Color.fromRGBO(34, 33, 33, 1),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Body Field (Max 2000)
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Body Content',
              style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
            ),
            Text(
              '${_bodyController.text.length}/2000',
              style: TextStyle(color: Colors.grey[500], fontSize: 11),
            ),
          ],
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _bodyController,
          maxLength: 2000,
          maxLines: 6,
          onChanged: (_) => setState(() {}),
          style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.4),
          decoration: InputDecoration(
            counterText: '',
            hintText: 'Plain text notice content (line breaks and links are preserved)...',
            hintStyle: TextStyle(color: Colors.grey[500]),
            filled: true,
            fillColor: const Color.fromRGBO(34, 33, 33, 1),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
            ),
          ),
        ),

        const SizedBox(height: 20),

        // Images Section (up to 4 via MediaService)
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Images (up to 4)',
              style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
            ),
            Text(
              '${_media.length}/4',
              style: TextStyle(color: Colors.grey[500], fontSize: 12),
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
                final url = MediaService.instance.urlFor(media, MediaVariant.noticeCard);

                return Stack(
                  children: [
                    Container(
                      margin: const EdgeInsets.only(right: 10),
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white.withOpacity(0.1)),
                        image: DecorationImage(image: NetworkImage(url), fit: BoxFit.cover),
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
                          child: const Icon(Icons.close, color: Colors.white, size: 14),
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
          LinearProgressIndicator(value: _uploadProgress, color: widget.primaryColor),
          const SizedBox(height: 4),
          const Text('Uploading image to Cloudinary...', style: TextStyle(color: Colors.grey, fontSize: 11)),
        ],

        if (_media.length < 4 && !_isUploadingImage) ...[
          const SizedBox(height: 8),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white70,
              side: BorderSide(color: Colors.white.withOpacity(0.15)),
            ),
            icon: const Icon(Icons.add_photo_alternate_outlined, size: 18),
            label: const Text('Add Image'),
            onPressed: _pickAndUploadImage,
          ),
        ],

        const SizedBox(height: 20),

        // Video Links Section (up to 3)
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Video Links (up to 3)',
              style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
            ),
            Text(
              '${_videoLinks.length}/3',
              style: TextStyle(color: Colors.grey[500], fontSize: 12),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ..._videoLinks.asMap().entries.map((entry) {
          final idx = entry.key;
          final url = entry.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                const Icon(Icons.link, color: Colors.grey, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    url,
                    style: const TextStyle(color: Colors.lightBlueAccent, fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.grey, size: 16),
                  onPressed: () => setState(() => _videoLinks.removeAt(idx)),
                ),
              ],
            ),
          );
        }),

        if (_videoLinks.length < 3)
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _videoLinkInputController,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'https://youtube.com/watch?v=...',
                    hintStyle: TextStyle(color: Colors.grey[600], fontSize: 12),
                    filled: true,
                    fillColor: const Color.fromRGBO(34, 33, 33, 1),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: widget.primaryColor,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                ),
                onPressed: _addVideoLink,
                child: const Text('Add'),
              ),
            ],
          ),

        const SizedBox(height: 20),

        // Pin Toggle & Expiry
        SwitchListTile(
          value: _pinned,
          title: const Text('Pin to top of feed', style: TextStyle(color: Colors.white, fontSize: 14)),
          subtitle: const Text('Pinned notices appear first for addressed members', style: TextStyle(color: Colors.grey, fontSize: 12)),
          activeColor: widget.primaryColor,
          contentPadding: EdgeInsets.zero,
          onChanged: (val) => setState(() => _pinned = val),
        ),

        const SizedBox(height: 10),

        // Expiry Picker
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(
            _selectedType == NoticeType.policy ? 'Expiry Date (Optional)' : 'Expiry Date (Required)',
            style: const TextStyle(color: Colors.white, fontSize: 14),
          ),
          subtitle: Text(
            _expiresAt != null
                ? 'Expires on ${_expiresAt!.day}/${_expiresAt!.month}/${_expiresAt!.year}'
                : 'No expiration date',
            style: TextStyle(color: Colors.grey[400], fontSize: 12),
          ),
          trailing: OutlinedButton(
            style: OutlinedButton.styleFrom(foregroundColor: widget.primaryColor),
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _expiresAt ?? DateTime.now().add(const Duration(days: 14)),
                firstDate: DateTime.now().add(const Duration(hours: 1)),
                lastDate: DateTime.now().add(const Duration(days: 90)), // Max 90 days per spec
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
  Widget _buildStep2Preview() {
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
        const Text(
          'Notice Preview',
          style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        const Text(
          'This is how the notice card will appear to recipients in the Home feed:',
          style: TextStyle(color: Colors.grey, fontSize: 12),
        ),
        const SizedBox(height: 16),

        // Live preview of feed card
        NoticeCard(
          notice: previewNotice,
          primaryColor: widget.primaryColor,
          onTap: () {},
        ),

        const SizedBox(height: 20),

        // Broadcast Summary
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color.fromRGBO(34, 33, 33, 1),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Distribution Summary',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 8),
              _buildSummaryRow('Notice Type', _selectedType.label),
              _buildSummaryRow('Target Audience', _selectedAudienceNames.join(', ')),
              _buildSummaryRow('Estimated Reach', '$_reachCount active members'),
              _buildSummaryRow(
                'Expiration',
                _expiresAt != null
                    ? '${_expiresAt!.day}/${_expiresAt!.month}/${_expiresAt!.year}'
                    : 'None (Permanent)',
              ),
              _buildSummaryRow('Images Attached', '${_media.length} images'),
              _buildSummaryRow('Video Links', '${_videoLinks.length} links'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[400], fontSize: 12)),
          Flexible(
            child: Text(
              value,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12),
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // ── Bottom Navigation Controls ──────────────────────────────────────────────
  Widget _buildBottomControls() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color.fromRGBO(34, 33, 33, 1),
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.08))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (_currentStep > 0 && !isEditing)
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white70,
                side: BorderSide(color: Colors.white.withOpacity(0.2)),
              ),
              onPressed: () => setState(() => _currentStep--),
              child: const Text('Back'),
            )
          else
            const SizedBox.shrink(),

          if (_currentStep < 2)
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: widget.primaryColor,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              onPressed: () => _goToStep(_currentStep + 1),
              child: const Text('Next'),
            )
          else
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: _selectedType == NoticeType.urgent ? Colors.redAccent : widget.primaryColor,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              icon: _isSubmitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.send_rounded, size: 18),
              label: Text(
                _isSubmitting
                    ? 'Publishing...'
                    : (isEditing ? 'Save Changes' : 'Publish Notice'),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              onPressed: _isSubmitting ? null : _submitNotice,
            ),
        ],
      ),
    );
  }
}
