import 'dart:math';
import 'package:flutter/material.dart';
import '../../models/chat_polish_models.dart';

class TypingIndicatorWidget extends StatelessWidget {
  final List<TypingIndicatorStatus> typingUsers;
  final String currentUid;

  const TypingIndicatorWidget({
    super.key,
    required this.typingUsers,
    required this.currentUid,
  });

  String _formatTypingText(List<TypingIndicatorStatus> others) {
    if (others.isEmpty) return '';
    final names = others.map((t) => t.userName).toSet().toList();

    if (names.length == 1) {
      return '${names.first} is typing...';
    } else if (names.length == 2) {
      return '${names[0]} and ${names[1]} are typing...';
    } else {
      return '${names[0]} and ${names.length - 1} others are typing...';
    }
  }

  @override
  Widget build(BuildContext context) {
    final others = typingUsers.where((u) => u.uid != currentUid && u.isActive).toList();
    if (others.isEmpty) return const SizedBox.shrink();

    final text = _formatTypingText(others);

    return Padding(
      padding: const EdgeInsets.only(left: 16, bottom: 6, top: 2),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: const Color.fromRGBO(30, 29, 36, 0.95),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0x3300E5FF), width: 0.8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
              BoxShadow(
                color: const Color(0xFF00E5FF).withOpacity(0.08),
                blurRadius: 10,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const BouncingDots(color: Color(0xFF00E5FF)),
              const SizedBox(width: 8),
              Text(
                text,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class BouncingDots extends StatefulWidget {
  final Color color;
  final double dotSize;
  const BouncingDots({
    super.key,
    this.color = const Color(0xFF00E5FF),
    this.dotSize = 5.0,
  });

  @override
  State<BouncingDots> createState() => _BouncingDotsState();
}

class _BouncingDotsState extends State<BouncingDots> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _buildDot(int index) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final double phase = (_controller.value * 2 * pi) - (index * 0.75);
        final double bounce = sin(phase);
        final double offsetY = bounce < 0 ? bounce * 2.5 : 0;
        final double opacity = 0.35 + (0.65 * ((bounce + 1) / 2));

        return Transform.translate(
          offset: Offset(0, offsetY),
          child: Opacity(
            opacity: opacity.clamp(0.2, 1.0),
            child: Container(
              width: widget.dotSize,
              height: widget.dotSize,
              margin: const EdgeInsets.symmetric(horizontal: 1.5),
              decoration: BoxDecoration(
                color: widget.color,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: widget.color.withOpacity(0.6),
                    blurRadius: 3,
                    spreadRadius: 0.5,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildDot(0),
        _buildDot(1),
        _buildDot(2),
      ],
    );
  }
}
