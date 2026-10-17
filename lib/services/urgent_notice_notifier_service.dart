import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/notice_model.dart';
import 'notices_service.dart';

/// Foreground-only live notifier for urgent notices.
/// Mirrors MentionNotifierService: triggers heavy impact haptic feedback,
/// alert audio, and renders a distinct floating urgent banner with a 'View' action.
class UrgentNoticeNotifierService {
  UrgentNoticeNotifierService._internal();
  static final UrgentNoticeNotifierService instance = UrgentNoticeNotifierService._internal();

  StreamSubscription? _urgentSub;
  final Set<String> _seenNoticeIds = {};
  final Set<String> _dismissedNoticeIds = {};
  bool _initialized = false;

  bool isDismissed(String noticeId) => _dismissedNoticeIds.contains(noticeId);

  void dismissLocally(String noticeId) {
    _dismissedNoticeIds.add(noticeId);
  }

  void startListening({
    required String firmId,
    String? userDepartmentId,
    required BuildContext context,
    required void Function(NoticeModel notice) onOpenNotice,
  }) {
    _urgentSub?.cancel();
    _initialized = false;

    _urgentSub = NoticesService.instance
        .streamLatestUrgentNotice(firmId: firmId, userDepartmentId: userDepartmentId)
        .listen((notice) {
      if (notice == null) return;

      if (!_initialized) {
        // Record current latest urgent notice so we don't spam banner immediately on fresh start
        _seenNoticeIds.add(notice.id);
        _initialized = true;
        return;
      }

      if (!_seenNoticeIds.contains(notice.id) && !_dismissedNoticeIds.contains(notice.id)) {
        _seenNoticeIds.add(notice.id);
        _showUrgentBanner(context, notice, onOpenNotice);
      }
    });
  }

  void _showUrgentBanner(
    BuildContext context,
    NoticeModel notice,
    void Function(NoticeModel notice) onOpenNotice,
  ) {
    // Distinct haptic & alert audio
    HapticFeedback.heavyImpact();
    SystemSound.play(SystemSoundType.alert);

    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;

    messenger.showSnackBar(
      SnackBar(
        backgroundColor: const Color.fromRGBO(48, 20, 20, 1),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Colors.redAccent, width: 1.4),
        ),
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(
                color: Color(0x33FF5252),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'URGENT NOTICE',
                        style: TextStyle(
                          color: Colors.redAccent,
                          fontWeight: FontWeight.w800,
                          fontSize: 11,
                          letterSpacing: 0.6,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'from ${notice.authorName}',
                        style: const TextStyle(color: Colors.white70, fontSize: 11),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    notice.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        action: SnackBarAction(
          label: 'View',
          textColor: Colors.redAccent,
          onPressed: () {
            onOpenNotice(notice);
          },
        ),
      ),
    );
  }

  void stopListening() {
    _urgentSub?.cancel();
    _urgentSub = null;
    _initialized = false;
  }
}
