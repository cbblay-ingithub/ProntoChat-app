import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/firm.dart';
import '../../models/notice_model.dart';
import '../../services/notices_service.dart';
import '../../services/db_service.dart';
import '../../theme/pc_tokens.dart';
import '../../widgets/common/pc_avatar.dart';
import '../../widgets/notices/notice_image_carousel.dart';
import '../../widgets/notices/notice_reactions_widget.dart';
import '../../screens/employee/channel_chat_screen.dart';
import '../../pages/convo_page.dart';
import 'notice_composer_screen.dart';

/// Detailed view for a single notice with full media, video link cards,
/// reaction bar, policy acknowledgements, views tracking, and discussion actions.
class NoticeDetailScreen extends StatefulWidget {
  final NoticeModel notice;
  final Firm? firm;
  final String? _firmId;
  final String currentUid;
  final String currentUserName;
  final String currentUserRole;
  final String? userDepartmentId;
  final Color? _primaryColor;

  String get firmId => firm?.firmId ?? _firmId ?? '';
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

  const NoticeDetailScreen({
    super.key,
    required this.notice,
    this.firm,
    String? firmId,
    required this.currentUid,
    required this.currentUserName,
    required this.currentUserRole,
    this.userDepartmentId,
    Color? primaryColor,
  })  : _firmId = firmId,
        _primaryColor = primaryColor;

  @override
  State<NoticeDetailScreen> createState() => _NoticeDetailScreenState();
}

class _NoticeDetailScreenState extends State<NoticeDetailScreen> {
  late NoticeModel _notice;
  int _viewCount = 0;
  bool _isLoadingViewCount = false;
  bool _isAcknowledging = false;
  bool _isRetracting = false;

  bool get isAuthor => widget.currentUid == _notice.authorId;
  bool get isAdmin =>
      widget.currentUserRole == 'admin' ||
      widget.currentUserRole == 'super_admin';

  @override
  void initState() {
    super.initState();
    _notice = widget.notice;

    // 1. Record view once on first open
    NoticesService.instance.recordView(
      firmId: widget.firmId,
      noticeId: _notice.id,
      uid: widget.currentUid,
    );

    // 2. If author, load view count aggregate
    if (isAuthor) {
      _loadViewCount();
    }
  }

  Future<void> _loadViewCount() async {
    setState(() => _isLoadingViewCount = true);
    try {
      final count = await NoticesService.instance.getViewCount(
        widget.firmId,
        _notice.id,
      );
      if (mounted) {
        setState(() {
          _viewCount = count;
          _isLoadingViewCount = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingViewCount = false);
    }
  }

  String _formatDate(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year} at ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  // ── Video Link Validation & Categorization ─────────────────────────────────
  static const _trustedVideoHosts = [
    'youtube.com',
    'www.youtube.com',
    'youtu.be',
    'vimeo.com',
    'www.vimeo.com',
    'drive.google.com',
  ];

  bool _isTrustedVideoUrl(String url) {
    try {
      final uri = Uri.parse(url);
      if (uri.scheme != 'https') return false;
      final host = uri.host.toLowerCase();
      return _trustedVideoHosts.any((h) => host == h || host.endsWith('.$h'));
    } catch (_) {
      return false;
    }
  }

  String _getVideoPlatformLabel(String url) {
    final lower = url.toLowerCase();
    if (lower.contains('youtu.be') || lower.contains('youtube.com')) {
      return 'YouTube';
    }
    if (lower.contains('vimeo.com')) return 'Vimeo';
    if (lower.contains('drive.google.com')) return 'Google Drive';
    return 'Video';
  }

  void _openLink(BuildContext context, String url, bool isTrustedVideo) {
    final tokens = context.pcTokens;
    final accent = PcTokens.readableAccentOnLight(widget.primaryColor);

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: tokens.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(
              isTrustedVideo ? Icons.play_circle_fill : Icons.open_in_new,
              color: isTrustedVideo ? tokens.urgentText : accent,
              size: 24,
            ),
            const SizedBox(width: 10),
            Text(
              isTrustedVideo ? 'Watch Video' : 'External Link',
              style: TextStyle(
                color: tokens.textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isTrustedVideo) ...[
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: tokens.warningSoft,
                  borderRadius: BorderRadius.circular(10),
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
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'This link opens an external site. Please verify the destination.',
                        style: TextStyle(
                          color: tokens.textPrimary,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            SelectableText(
              url,
              style: TextStyle(color: accent, fontSize: 13),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: Text(
              'Close',
              style: TextStyle(color: tokens.textSecondary),
            ),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: accent,
              foregroundColor: PcTokens.contrastOn(accent),
            ),
            icon: const Icon(Icons.copy, size: 16),
            label: const Text('Copy Link'),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: url));
              if (dialogCtx.mounted) Navigator.pop(dialogCtx);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Link copied to clipboard!')),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  // ── Actions ────────────────────────────────────────────────────────────────
  Future<void> _handleAcknowledge() async {
    if (_isAcknowledging) return;
    setState(() => _isAcknowledging = true);

    try {
      await NoticesService.instance.acknowledgePolicy(
        firmId: widget.firmId,
        noticeId: _notice.id,
        uid: widget.currentUid,
        version: _notice.version,
        userName: widget.currentUserName,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Color(0xFF059669),
            content: Text('You have acknowledged this policy notice.'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFFDC2626),
            content: Text('Failed to acknowledge: $e'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isAcknowledging = false);
    }
  }

  Future<void> _handleRetract() async {
    final tokens = context.pcTokens;
    final reasonController = TextEditingController();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: tokens.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Retract Notice?',
          style: TextStyle(
            color: tokens.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Retracting this notice will immediately remove it from all feeds. This action is recorded and cannot be undone.',
              style: TextStyle(color: tokens.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: reasonController,
              maxLines: 2,
              style: TextStyle(color: tokens.textPrimary, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Optional retraction reason...',
                hintStyle: TextStyle(color: tokens.textMuted, fontSize: 13),
                filled: true,
                fillColor: tokens.surfaceSubtle,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: tokens.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: tokens.border),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: Text(
              'Cancel',
              style: TextStyle(color: tokens.textSecondary),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: tokens.urgentText,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(dialogCtx, true),
            child: const Text('Retract Notice'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isRetracting = true);
      try {
        await NoticesService.instance.retractNotice(
          firmId: widget.firmId,
          noticeId: _notice.id,
          retractedByUid: widget.currentUid,
          reason: reasonController.text,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Notice retracted successfully.')),
          );
          Navigator.of(context).pop();
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isRetracting = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error retracting notice: $e'),
              backgroundColor: tokens.urgentText,
            ),
          );
        }
      }
    }
  }

  void _handleMessagePoster() {
    if (_notice.authorId == widget.currentUid) return;

    final parts = [widget.currentUid, _notice.authorId]..sort();
    final conversationId = '${parts[0]}_${parts[1]}';

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatPage(
          conversationId: conversationId,
          otherUserId: _notice.authorId,
          otherUserName: _notice.authorName,
          otherUserImage: '',
        ),
      ),
    );
  }

  Future<void> _handleDiscuss() async {
    final userDept = widget.userDepartmentId;
    if (userDept == null) return;

    try {
      final deptDoc =
          await DBService.instance.getDepartment(widget.firmId, userDept);
      final convId = deptDoc?.conversationId;
      if (convId != null && mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChannelChatScreen(
              channelType: ChannelType.department,
              firmId: widget.firmId,
              conversationId: convId,
              title: deptDoc?.name ?? 'Department Chat',
              uid: widget.currentUid,
              userName: widget.currentUserName,
              departmentId: userDept,
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('[NoticeDetail] Error opening department discussion: $e');
    }
  }

  bool get _canDiscussInDepartment {
    final dept = widget.userDepartmentId;
    if (dept == null) return false;
    return _notice.audienceKeys.length == 1 &&
        _notice.audienceKeys.first == 'dept:$dept';
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.pcTokens;
    final accent = PcTokens.readableAccentOnLight(widget.primaryColor);
    final isWide = !PcBreakpoints.isCompact(MediaQuery.sizeOf(context).width);

    final articleBody = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Retracted Notice Warning Banner ──────────────────────────────
        if (_notice.isRetracted)
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: tokens.urgentBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: tokens.urgentBorder),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: tokens.urgentText, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'This notice has been retracted and is hidden from standard feeds.',
                    style: TextStyle(
                      color: tokens.urgentText,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),

        // ── Author & Audience Metadata Header ────────────────────────────
        Row(
          children: [
            PcAvatar(
              name: _notice.authorName,
              radius: 20,
              backgroundColor: accent.withValues(alpha: 0.12),
              foregroundColor: accent,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _notice.authorName,
                    style: TextStyle(
                      color: tokens.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _notice.authorLabel.isNotEmpty
                        ? '${_notice.authorLabel} • ${_formatDate(_notice.createdAt)}'
                        : _formatDate(_notice.createdAt),
                    style: TextStyle(color: tokens.textSecondary, fontSize: 12),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: tokens.surfaceSubtle,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: tokens.border),
              ),
              child: Text(
                _notice.audienceSummary,
                style: TextStyle(
                  color: tokens.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),

        if (_notice.isEdited) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.history, color: tokens.textMuted, size: 14),
              const SizedBox(width: 4),
              Text(
                'Edited ${_formatDate(_notice.editedAt!)} (v${_notice.version})',
                style: TextStyle(color: tokens.textMuted, fontSize: 11),
              ),
            ],
          ),
        ],

        const SizedBox(height: 18),

        // ── Notice Title ─────────────────────────────────────────────────
        Text(
          _notice.title,
          style: TextStyle(
            color: tokens.textPrimary,
            fontSize: 24,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
            height: 1.25,
          ),
        ),

        const SizedBox(height: 16),

        // ── Image Carousel (if media attached) ───────────────────────────
        if (_notice.media.isNotEmpty) ...[
          NoticeImageCarousel(
            mediaList: _notice.media,
            height: 260,
            title: _notice.title,
          ),
          const SizedBox(height: 18),
        ],

        // ── Body Text ────────────────────────────────────────────────────
        SelectableText(
          _notice.body,
          style: TextStyle(
            color: tokens.textPrimary,
            fontSize: 15,
            height: 1.6,
          ),
        ),

        const SizedBox(height: 22),

        // ── Video Links Section ──────────────────────────────────────────
        if (_notice.videoLinks.isNotEmpty) ...[
          Text(
            'Links & Video',
            style: TextStyle(
              color: tokens.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          ..._notice.videoLinks.map((url) {
            final isTrusted = _isTrustedVideoUrl(url);
            final platform = _getVideoPlatformLabel(url);

            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: InkWell(
                onTap: () => _openLink(context, url, isTrusted),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: tokens.surfaceSubtle,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isTrusted ? tokens.urgentBorder : tokens.border,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isTrusted ? Icons.play_circle_fill : Icons.link,
                        color: isTrusted ? tokens.urgentText : accent,
                        size: 22,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isTrusted
                                  ? 'Watch on $platform'
                                  : 'External Web Link',
                              style: TextStyle(
                                color: tokens.textPrimary,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              url,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: tokens.textSecondary,
                                fontSize: 11.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: tokens.textMuted,
                        size: 18,
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
          const SizedBox(height: 14),
        ],

        // ── Policy Acknowledgement Section (Policy notices only) ─────────
        if (_notice.isPolicy) ...[
          StreamBuilder<NoticeAck?>(
            stream: NoticesService.instance.streamUserAck(
              widget.firmId,
              _notice.id,
              widget.currentUid,
            ),
            builder: (context, ackSnapshot) {
              final ack = ackSnapshot.data;
              final isAcknowledged =
                  ack != null && ack.version == _notice.version;

              if (isAcknowledged) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: tokens.online.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: tokens.online.withValues(alpha: 0.30),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.check_circle,
                        color: Color(0xFF059669),
                        size: 22,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Acknowledged',
                              style: TextStyle(
                                color: tokens.textPrimary,
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              'You read and accepted version ${_notice.version} on ${_formatDate(ack.at)}',
                              style: TextStyle(
                                color: tokens.textSecondary,
                                fontSize: 11.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }

              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: tokens.projectSoft,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: tokens.projectAccent.withValues(alpha: 0.30),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.gavel,
                          color: tokens.projectAccent,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            ack != null
                                ? 'Policy Updated (Version ${_notice.version})'
                                : 'Formal Policy Acknowledgement Required',
                            style: TextStyle(
                              color: tokens.textPrimary,
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      ack != null
                          ? 'This policy has been revised since you last acknowledged it. Please confirm you have read the updated terms.'
                          : 'Please read this policy thoroughly and confirm below that you have understood and accepted it.',
                      style: TextStyle(
                        color: tokens.textSecondary,
                        fontSize: 12.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: tokens.projectAccent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        icon: _isAcknowledging
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.check, size: 18),
                        label: const Text(
                          'I have read and acknowledge this policy',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                        onPressed: _isAcknowledging ? null : _handleAcknowledge,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],

        // ── Interactive Reactions Bar ────────────────────────────────────
        NoticeReactionsWidget(
          firmId: widget.firmId,
          noticeId: _notice.id,
          currentUid: widget.currentUid,
          primaryColor: accent,
        ),

        const SizedBox(height: 20),

        // ── Contextual Actions: Message Poster & Discuss ─────────────────
        Row(
          children: [
            if (!isAuthor)
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: tokens.textPrimary,
                    side: BorderSide(color: tokens.borderStrong),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: Icon(
                    Icons.chat_bubble_outline,
                    size: 17,
                    color: accent,
                  ),
                  label: const Text(
                    'Message Poster',
                    style: TextStyle(fontSize: 13),
                  ),
                  onPressed: _handleMessagePoster,
                ),
              ),
            if (!isAuthor && _canDiscussInDepartment)
              const SizedBox(width: 10),
            if (_canDiscussInDepartment)
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accent,
                    foregroundColor: PcTokens.contrastOn(accent),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.forum_outlined, size: 17),
                  label: const Text(
                    'Discuss in Team',
                    style: TextStyle(fontSize: 13),
                  ),
                  onPressed: _handleDiscuss,
                ),
              ),
          ],
        ),

        const SizedBox(height: 24),

        // ── Author Oversight Information ─────────────────────────────────
        if (isAuthor)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: tokens.surfaceSubtle,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: tokens.border),
            ),
            child: Row(
              children: [
                Icon(Icons.visibility_outlined, color: accent, size: 20),
                const SizedBox(width: 10),
                Text(
                  _isLoadingViewCount
                      ? 'Calculating views...'
                      : '$_viewCount people have seen this notice',
                  style: TextStyle(
                    color: tokens.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
      ],
    );

    return Scaffold(
      backgroundColor: tokens.canvas,
      appBar: AppBar(
        backgroundColor: tokens.surface,
        elevation: 0,
        shape: Border(bottom: BorderSide(color: tokens.border)),
        title: Text(
          _notice.type.label,
          style: TextStyle(
            color: tokens.textPrimary,
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          if (isAuthor && _notice.isPublished)
            IconButton(
              icon: Icon(Icons.edit_outlined, color: tokens.textSecondary),
              tooltip: 'Edit notice',
              onPressed: () async {
                final updated = await Navigator.push<NoticeModel?>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => NoticeComposerScreen(
                      firmId: widget.firmId,
                      currentUid: widget.currentUid,
                      currentUserName: widget.currentUserName,
                      currentUserRole: widget.currentUserRole,
                      userDepartmentId: widget.userDepartmentId,
                      primaryColor: accent,
                      editingNotice: _notice,
                    ),
                  ),
                );
                if (updated != null && mounted) {
                  setState(() => _notice = updated);
                }
              },
            ),
          if ((isAuthor || isAdmin) && _notice.isPublished)
            IconButton(
              icon: _isRetracting
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: tokens.urgentText,
                      ),
                    )
                  : Icon(
                      Icons.remove_circle_outline,
                      color: tokens.urgentText,
                    ),
              tooltip: 'Retract notice',
              onPressed: _isRetracting ? null : _handleRetract,
            ),
        ],
      ),
      body: Center(
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
                    child: articleBody,
                  )
                : articleBody,
          ),
        ),
      ),
    );
  }
}
