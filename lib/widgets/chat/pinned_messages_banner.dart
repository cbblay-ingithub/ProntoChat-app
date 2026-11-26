import 'package:flutter/material.dart';
import '../../models/chat_polish_models.dart';
import '../../theme/pc_tokens.dart';

class PinnedMessagesBanner extends StatefulWidget {
  final List<PinnedMessage> pins;
  final bool canManagePins;
  final ValueChanged<String> onJumpToMessage;
  final ValueChanged<String> onUnpinMessage;

  const PinnedMessagesBanner({
    super.key,
    required this.pins,
    required this.canManagePins,
    required this.onJumpToMessage,
    required this.onUnpinMessage,
  });

  @override
  State<PinnedMessagesBanner> createState() => _PinnedMessagesBannerState();
}

class _PinnedMessagesBannerState extends State<PinnedMessagesBanner> {
  int _currentIndex = 0;

  @override
  void didUpdateWidget(covariant PinnedMessagesBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.pins.isNotEmpty &&
        (oldWidget.pins.isEmpty ||
            widget.pins.first.messageId != oldWidget.pins.first.messageId)) {
      _currentIndex = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.pins.isEmpty) return const SizedBox.shrink();
    final tokens = context.pcTokens;

    final safeIndex = _currentIndex < widget.pins.length ? _currentIndex : 0;
    final pin = widget.pins[safeIndex];

    return Container(
      decoration: BoxDecoration(
        color: tokens.surface,
        border: Border(
          bottom: BorderSide(color: tokens.border, width: 1),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: tokens.warningSoft,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.push_pin_rounded,
              color: tokens.warningAccent,
              size: 15,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: GestureDetector(
              onTap: () => widget.onJumpToMessage(pin.messageId),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Text(
                        widget.pins.length > 1
                            ? 'Pinned Message (${safeIndex + 1}/${widget.pins.length})'
                            : 'Pinned Message',
                        style: TextStyle(
                          color: tokens.warningAccent,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Container(
                        margin: const EdgeInsets.only(left: 6),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: tokens.warningSoft,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          pin.formatRemaining(),
                          style: TextStyle(
                            color: tokens.warningAccent,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (widget.pins.length > 1) ...[
                        const SizedBox(width: 6),
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              _currentIndex =
                                  (_currentIndex + 1) % widget.pins.length;
                            });
                          },
                          child: Text(
                            'Next ▶',
                            style: TextStyle(
                              color: tokens.textSecondary,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    pin.snippet.isNotEmpty ? pin.snippet : 'Pinned message',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: tokens.textPrimary,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (widget.canManagePins)
            IconButton(
              icon: Icon(Icons.close_rounded, color: tokens.textMuted, size: 18),
              tooltip: 'Unpin message',
              onPressed: () => widget.onUnpinMessage(pin.messageId),
              visualDensity: VisualDensity.compact,
            ),
        ],
      ),
    );
  }
}
