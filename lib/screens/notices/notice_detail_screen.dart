import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/firm.dart';
import '../../models/notice_model.dart';
import '../../services/notices_service.dart';
import '../../services/db_service.dart';
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
  bool get isAdmin => widget.currentUserRole == 'admin' || widget.currentUserRole == 'super_admin';

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
    if (lower.contains('youtu.be') || lower.contains('youtube.com')) return 'YouTube';
    if (lower.contains('vimeo.com')) return 'Vimeo';
    if (lower.contains('drive.google.com')) return 'Google Drive';
    return 'Video';
  }

  void _openLink(BuildContext context, String url, bool isTrustedVideo) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: const Color.fromRGBO(34, 33, 33, 1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(
              isTrustedVideo ? Icons.play_circle_fill : Icons.open_in_new,
              color: isTrustedVideo ? Colors.redAccent : widget.primaryColor,
              size: 24,
            ),
            const SizedBox(width: 10),
            Text(
              isTrustedVideo ? 'Watch Video' : 'External Link',
              style: const TextStyle(color: Colors.white, fontSize: 17),
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
                  color: Colors.amber.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.amber.withOpacity(0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.amberAccent, size: 18),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'This link opens an external site. Please verify the destination.',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            SelectableText(
              url,
              style: const TextStyle(color: Colors.lightBlueAccent, fontSize: 13),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Close', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: widget.primaryColor,
              foregroundColor: Colors.white,
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
            backgroundColor: Colors.green,
            content: Text('You have acknowledged this policy notice.'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.redAccent,
            content: Text('Failed to acknowledge: $e'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isAcknowledging = false);
    }
  }

  Future<void> _handleRetract() async {
    final reasonController = TextEditingController();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: const Color.fromRGBO(34, 33, 33, 1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Retract Notice?', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Retracting this notice will immediately remove it from all feeds. This action is recorded and cannot be undone.',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: reasonController,
              maxLines: 2,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Optional retraction reason...',
                hintStyle: TextStyle(color: Colors.grey[500], fontSize: 13),
                filled: true,
                fillColor: const Color.fromRGBO(24, 23, 23, 1),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
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
            SnackBar(content: Text('Error retracting notice: $e'), backgroundColor: Colors.redAccent),
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
      final deptDoc = await DBService.instance.getDepartment(widget.firmId, userDept);
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
    // Show only when audience is exactly a single department the reader belongs to
    return _notice.audienceKeys.length == 1 && _notice.audienceKeys.first == 'dept:$dept';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromRGBO(28, 27, 27, 1),
      appBar: AppBar(
        backgroundColor: const Color.fromRGBO(28, 27, 27, 1),
        elevation: 0,
        title: Text(
          _notice.type.label,
          style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
        ),
        actions: [
          if (isAuthor && _notice.isPublished)
            IconButton(
              icon: const Icon(Icons.edit_outlined, color: Colors.white70),
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
                      primaryColor: widget.primaryColor,
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
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.redAccent),
                    )
                  : const Icon(Icons.remove_circle_outline, color: Colors.redAccent),
              tooltip: 'Retract notice',
              onPressed: _isRetracting ? null : _handleRetract,
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Retracted Notice Warning Banner ──────────────────────────────
            if (_notice.isRetracted)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.redAccent.withOpacity(0.4)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.redAccent, size: 20),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'This notice has been retracted and is hidden from standard feeds.',
                        style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
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
                  backgroundColor: widget.primaryColor.withOpacity(0.2),
                  foregroundColor: widget.primaryColor,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _notice.authorName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _notice.authorLabel.isNotEmpty
                            ? '${_notice.authorLabel} • ${_formatDate(_notice.createdAt)}'
                            : _formatDate(_notice.createdAt),
                        style: TextStyle(color: Colors.grey[400], fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _notice.audienceSummary,
                    style: TextStyle(
                      color: Colors.grey[300],
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
                  Icon(Icons.history, color: Colors.grey[500], size: 14),
                  const SizedBox(width: 4),
                  Text(
                    'Edited ${_formatDate(_notice.editedAt!)} (v${_notice.version})',
                    style: TextStyle(color: Colors.grey[500], fontSize: 11),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 16),

            // ── Notice Title ─────────────────────────────────────────────────
            Text(
              _notice.title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
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
                height: 240,
                title: _notice.title,
              ),
              const SizedBox(height: 18),
            ],

            // ── Body Text ────────────────────────────────────────────────────
            SelectableText(
              _notice.body,
              style: const TextStyle(
                color: Color.fromRGBO(235, 235, 235, 1),
                fontSize: 15,
                height: 1.5,
              ),
            ),

            const SizedBox(height: 20),

            // ── Video Links Section ──────────────────────────────────────────
            if (_notice.videoLinks.isNotEmpty) ...[
              const Text(
                'Links & Video',
                style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold),
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
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color.fromRGBO(34, 33, 33, 1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isTrusted
                              ? Colors.redAccent.withOpacity(0.3)
                              : Colors.white.withOpacity(0.08),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isTrusted ? Icons.play_circle_fill : Icons.link,
                            color: isTrusted ? Colors.redAccent : widget.primaryColor,
                            size: 22,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isTrusted ? 'Watch on $platform' : 'External Web Link',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  url,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(color: Colors.grey[400], fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.arrow_forward_ios, color: Colors.grey, size: 14),
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
                  final isAcknowledged = ack != null && ack.version == _notice.version;

                  if (isAcknowledged) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.greenAccent.withOpacity(0.4)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle, color: Colors.greenAccent, size: 22),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Acknowledged',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                Text(
                                  'You read and accepted version ${_notice.version} on ${_formatDate(ack.at)}',
                                  style: const TextStyle(color: Colors.white70, fontSize: 11),
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
                      color: Colors.indigo.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.indigoAccent.withOpacity(0.4)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.gavel, color: Colors.indigoAccent, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              ack != null
                                  ? 'Policy Updated (Version ${_notice.version})'
                                  : 'Formal Policy Acknowledgement Required',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          ack != null
                              ? 'This policy has been revised since you last acknowledged it. Please confirm you have read the updated terms.'
                              : 'Please read this policy thoroughly and confirm below that you have understood and accepted it.',
                          style: TextStyle(color: Colors.grey[300], fontSize: 12),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.indigoAccent,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            icon: _isAcknowledging
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : const Icon(Icons.check, size: 18),
                            label: const Text(
                              'I have read and acknowledge this policy',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
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
              primaryColor: widget.primaryColor,
            ),

            const SizedBox(height: 20),

            // ── Contextual Actions: Message Poster & Discuss ─────────────────
            Row(
              children: [
                if (!isAuthor)
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: BorderSide(color: Colors.white.withOpacity(0.15)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.chat_bubble_outline, size: 17),
                      label: const Text('Message Poster', style: TextStyle(fontSize: 13)),
                      onPressed: _handleMessagePoster,
                    ),
                  ),
                if (!isAuthor && _canDiscussInDepartment) const SizedBox(width: 10),
                if (_canDiscussInDepartment)
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: widget.primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.forum_outlined, size: 17),
                      label: const Text('Discuss in Team', style: TextStyle(fontSize: 13)),
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
                  color: const Color.fromRGBO(30, 30, 30, 1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withOpacity(0.06)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.visibility_outlined, color: widget.primaryColor, size: 20),
                    const SizedBox(width: 10),
                    Text(
                      _isLoadingViewCount
                          ? 'Calculating views...'
                          : '$_viewCount people have seen this notice',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}
