import 'dart:math';
import 'package:flutter/material.dart';

// ═══════════════════════════════════════════════════════════════════
//  ANIMATED ORB SWITCHER
//  Tap the widget to cycle through 3 custom animations:
//    0 — Launch Orb   (rocket through plasma orb)
//    1 — Chat Bubbles (bouncing speech bubbles with typing dots)
//    2 — Starburst    (rotating ray burst)
//  Import this file and drop <AnimatedOrbSwitcher(size: ...)> anywhere.
// ═══════════════════════════════════════════════════════════════════

class AnimatedOrbSwitcher extends StatefulWidget {
  final double size;
  const AnimatedOrbSwitcher({super.key, required this.size});

  @override
  State<AnimatedOrbSwitcher> createState() => _AnimatedOrbSwitcherState();
}

class _AnimatedOrbSwitcherState extends State<AnimatedOrbSwitcher> {
  int _currentAnim = 0;

  @override
  Widget build(BuildContext context) {
    final animations = [
      _LaunchOrbAnimation(key: const ValueKey(0), size: widget.size),
      _ChatBubblesAnimation(key: const ValueKey(1), size: widget.size),
      _StarburstAnimation(key: const ValueKey(2), size: widget.size),
    ];

    return GestureDetector(
      onTap: () => setState(
        () => _currentAnim = (_currentAnim + 1) % animations.length,
      ),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 400),
        transitionBuilder: (child, animation) => ScaleTransition(
          scale: animation,
          child: FadeTransition(opacity: animation, child: child),
        ),
        child: SizedBox(
          key: ValueKey(_currentAnim),
          height: widget.size,
          width: widget.size,
          child: animations[_currentAnim],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  ANIMATION 1 — Launch Orb (rocket through plasma orb)
// ─────────────────────────────────────────────────────────────────

class _LaunchOrbPainter extends CustomPainter {
  final double pulse;
  final double orbit;
  final double rocketY;
  final double trailOpacity;

  _LaunchOrbPainter({
    required this.pulse,
    required this.orbit,
    required this.rocketY,
    required this.trailOpacity,
  });

  static const Color _blue   = Color.fromRGBO(41, 116, 188, 1);
  static const Color _cyan   = Color(0xFF00D4FF);
  static const Color _violet = Color(0xFF7B2FFF);
  static const Color _hot    = Color(0xFFFF6B35);

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r  = size.shortestSide * 0.30;

    // Outer glow halo
    final glowRadius = r * (1.35 + 0.12 * sin(pulse * 2 * pi));
    final glowPaint  = Paint()
      ..shader = RadialGradient(
        colors: [
          _cyan.withOpacity(0.18),
          _blue.withOpacity(0.10),
          Colors.transparent,
        ],
        stops: const [0.0, 0.55, 1.0],
      ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: glowRadius * 1.6));
    canvas.drawCircle(Offset(cx, cy), glowRadius * 1.6, glowPaint);

    // Plasma ring
    final ringRadius = r * (1.0 + 0.06 * sin(pulse * 2 * pi));
    final ringPaint  = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..shader = SweepGradient(
        startAngle: pulse * 2 * pi,
        colors: [_cyan, _violet, _blue, _cyan],
      ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: ringRadius));
    canvas.drawCircle(Offset(cx, cy), ringRadius, ringPaint);

    // Core orb
    final orbPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.3, -0.4),
        colors: [const Color(0xFF4FC3F7), _blue, const Color(0xFF0A1628)],
        stops: const [0.0, 0.45, 1.0],
      ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: r));
    canvas.drawCircle(Offset(cx, cy), r, orbPaint);

    // Shimmer highlight
    final highlightPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.25, -0.35),
        colors: [Colors.white.withOpacity(0.45), Colors.transparent],
        stops: const [0.0, 0.6],
      ).createShader(Rect.fromCircle(
          center: Offset(cx - r * 0.25, cy - r * 0.30), radius: r * 0.45));
    canvas.drawCircle(
        Offset(cx - r * 0.25, cy - r * 0.30), r * 0.45, highlightPaint);

    // Orbiting satellites
    const orbitR      = [1.60, 1.80, 1.45];
    const orbitOffset = [0.0, 2.09, 4.19];
    const dotSizes    = [4.5, 3.5, 5.0];
    const dotColors   = [_cyan, _violet, _hot];
    for (int i = 0; i < 3; i++) {
      final angle = orbit + orbitOffset[i];
      final ox = cx + r * orbitR[i] * cos(angle);
      final oy = cy + r * orbitR[i] * 0.35 * sin(angle);
      canvas.drawCircle(Offset(ox, oy), dotSizes[i],
          Paint()..color = dotColors[i].withOpacity(0.92));
      canvas.drawCircle(Offset(ox, oy), dotSizes[i] * 2.5,
          Paint()..color = dotColors[i].withOpacity(0.18));
    }

    // Rocket
    final rocketCenterY = cy + r * 0.5 - rocketY * r * 2.8;
    final rocketCenterX = cx;
    final rocketScale   = 0.055 * r;

    if (trailOpacity > 0.01) {
      for (int t = 1; t <= 6; t++) {
        final ty     = rocketCenterY + rocketScale * 3.2 + t * rocketScale * 1.8;
        final tAlpha = trailOpacity * (1.0 - t / 7.0);
        final tR     = rocketScale * (1.0 - t * 0.12);
        if (tR > 0) {
          canvas.drawCircle(
            Offset(rocketCenterX, ty),
            tR,
            Paint()
              ..shader = RadialGradient(
                colors: [
                  _hot.withOpacity(tAlpha),
                  _cyan.withOpacity(tAlpha * 0.4),
                  Colors.transparent,
                ],
              ).createShader(
                  Rect.fromCircle(center: Offset(rocketCenterX, ty), radius: tR * 2.5)),
          );
        }
      }
    }

    final bx = rocketCenterX;
    final by = rocketCenterY;
    final bw = rocketScale;
    final bh = rocketScale * 3.2;

    final bodyPath = Path()
      ..moveTo(bx, by - bh)
      ..quadraticBezierTo(bx + bw * 1.1, by - bh * 0.3, bx + bw, by)
      ..lineTo(bx - bw, by)
      ..quadraticBezierTo(bx - bw * 1.1, by - bh * 0.3, bx, by - bh)
      ..moveTo(bx - bw, by)
      ..lineTo(bx - bw, by + bh * 0.9)
      ..lineTo(bx + bw, by + bh * 0.9)
      ..lineTo(bx + bw, by)
      ..close();

    canvas.drawPath(
      bodyPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            const Color(0xFFCFD8E3),
            Colors.white,
            const Color(0xFF90A4AE),
          ],
        ).createShader(Rect.fromCenter(
            center: Offset(bx, by), width: bw * 3, height: bh * 3)),
    );

    canvas.drawCircle(Offset(bx, by - bh * 0.35), bw * 0.62,
        Paint()..color = _cyan.withOpacity(0.9));
    canvas.drawCircle(Offset(bx, by - bh * 0.35), bw * 0.35,
        Paint()..color = const Color(0xFF001F3F));

    final finL = Path()
      ..moveTo(bx - bw, by + bh * 0.5)
      ..lineTo(bx - bw * 2.6, by + bh * 1.1)
      ..lineTo(bx - bw, by + bh * 0.9)
      ..close();
    canvas.drawPath(finL, Paint()..color = _blue);

    final finR = Path()
      ..moveTo(bx + bw, by + bh * 0.5)
      ..lineTo(bx + bw * 2.6, by + bh * 1.1)
      ..lineTo(bx + bw, by + bh * 0.9)
      ..close();
    canvas.drawPath(finR, Paint()..color = _blue);
  }

  @override
  bool shouldRepaint(_LaunchOrbPainter old) => true;
}

class _LaunchOrbAnimation extends StatefulWidget {
  final double size;
  const _LaunchOrbAnimation({super.key, required this.size});

  @override
  State<_LaunchOrbAnimation> createState() => _LaunchOrbAnimationState();
}

class _LaunchOrbAnimationState extends State<_LaunchOrbAnimation>
    with TickerProviderStateMixin {
  late AnimationController _pulseCtrl;
  late AnimationController _orbitCtrl;
  late AnimationController _rocketCtrl;

  late Animation<double> _pulse;
  late Animation<double> _orbit;
  late Animation<double> _rocket;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2400))
      ..repeat();
    _orbitCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 3200))
      ..repeat();
    _rocketCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2800))
      ..repeat(period: const Duration(milliseconds: 3600));

    _pulse  = Tween<double>(begin: 0, end: 1).animate(_pulseCtrl);
    _orbit  = Tween<double>(begin: 0, end: 2 * pi).animate(_orbitCtrl);
    _rocket = CurvedAnimation(parent: _rocketCtrl, curve: Curves.easeInOut)
        .drive(Tween(begin: 0.0, end: 1.0));
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _orbitCtrl.dispose();
    _rocketCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_pulse, _orbit, _rocket]),
      builder: (_, __) {
        final t = _rocket.value;
        final trailOpacity = (t > 0.05 && t < 0.92)
            ? (t < 0.5 ? (t - 0.05) / 0.45 : (0.92 - t) / 0.42)
                .clamp(0.0, 1.0)
            : 0.0;
        return CustomPaint(
          size: Size(widget.size, widget.size),
          painter: _LaunchOrbPainter(
            pulse: _pulse.value,
            orbit: _orbit.value,
            rocketY: t,
            trailOpacity: trailOpacity,
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  ANIMATION 2 — Chat Bubbles
//
//  Scene: a large primary chat bubble bounces gently in the centre
//  with animated typing dots inside. A smaller reply bubble pops in
//  from the bottom-right on a slower cycle. Glowing halos and a
//  subtle drop shadow give depth.
//
//  Timeline (driven by a single 0→1 looping controller, 3 s cycle):
//    0.00 – 0.10  primary bubble scales in (elastic overshoot)
//    0.10 – 0.70  typing dots animate sequentially
//    0.70 – 0.80  reply bubble pops in (bottom-right)
//    0.80 – 0.95  reply bubble visible
//    0.95 – 1.00  both fade out, reset
// ─────────────────────────────────────────────────────────────────

class _ChatBubblesAnimation extends StatefulWidget {
  final double size;
  const _ChatBubblesAnimation({super.key, required this.size});

  @override
  State<_ChatBubblesAnimation> createState() => _ChatBubblesAnimationState();
}

class _ChatBubblesAnimationState extends State<_ChatBubblesAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 3000))
      ..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => CustomPaint(
        size: Size(widget.size, widget.size),
        painter: _ChatBubblesPainter(_ctrl.value),
      ),
    );
  }
}

class _ChatBubblesPainter extends CustomPainter {
  final double t; // 0 → 1

  _ChatBubblesPainter(this.t);

  static const _blue       = Color.fromRGBO(41, 116, 188, 1);
  static const _cyan       = Color(0xFF00D4FF);
  static const _violet     = Color(0xFF7B2FFF);
  static const _bubbleFill = Color(0xFF1E3A5F);  // deep navy bubble body

  // ── Rounded-rect chat bubble path ───────────────────────────────
  // [rect]   bounding box of the bubble body
  // [tail]   'left' or 'right' – which corner the tail points from
  void _drawChatBubble(
    Canvas canvas,
    Rect rect,
    String tail,
    Color fillColor,
    Color strokeColor,
    double strokeWidth,
    double opacity,
  ) {
    const radius = 14.0;
    const tailW  = 10.0;
    const tailH  = 12.0;

    final paint = Paint()
      ..color = fillColor.withOpacity(opacity)
      ..style = PaintingStyle.fill;

    final strokePaint = Paint()
      ..color = strokeColor.withOpacity(opacity * 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    // Drop shadow
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect.translate(2, 3), const Radius.circular(radius)),
      Paint()..color = Colors.black.withOpacity(opacity * 0.25),
    );

    // Bubble body
    final rRect = RRect.fromRectAndRadius(rect, const Radius.circular(radius));
    canvas.drawRRect(rRect, paint);
    canvas.drawRRect(rRect, strokePaint);

    // Tail
    final tailPath = Path();
    if (tail == 'left') {
      // Tail points down-left from the bottom-left corner
      tailPath
        ..moveTo(rect.left + radius, rect.bottom)
        ..lineTo(rect.left - tailW, rect.bottom + tailH)
        ..lineTo(rect.left + radius + tailW, rect.bottom)
        ..close();
    } else {
      // Tail points down-right from the bottom-right corner
      tailPath
        ..moveTo(rect.right - radius, rect.bottom)
        ..lineTo(rect.right + tailW, rect.bottom + tailH)
        ..lineTo(rect.right - radius - tailW, rect.bottom)
        ..close();
    }
    canvas.drawPath(tailPath, paint);
    canvas.drawPath(tailPath, strokePaint);
  }

  // ── Elastic scale-in curve (0→1 input, overshoot then settle) ───
  double _elasticIn(double x) {
    if (x <= 0) return 0;
    if (x >= 1) return 1;
    const c4 = (2 * pi) / 3;
    return pow(2, -8 * (1 - x)).toDouble() *
            sin(((1 - x) * 10 - 0.75) * c4) +
        1;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final w  = size.width;
    final h  = size.height;
    final cx = w / 2;
    final cy = h / 2;

    // ── Global fade-out near end of cycle ───────────────────────
    final globalOpacity = t > 0.92 ? ((1.0 - t) / 0.08).clamp(0.0, 1.0) : 1.0;

    // ── PRIMARY bubble ───────────────────────────────────────────
    // Scale in during 0→0.18, then gentle float bob
    final scaleProgress = (t / 0.18).clamp(0.0, 1.0);
    final primaryScale  = _elasticIn(scaleProgress);
    // Gentle vertical bob after appearing
    final bob = t > 0.18 ? sin((t - 0.18) / 0.82 * 2 * pi) * 3.5 : 0.0;

    final bW = w * 0.60;
    final bH = h * 0.30;
    final primaryRect = Rect.fromCenter(
      center: Offset(cx - w * 0.04, cy - h * 0.08 + bob),
      width:  bW * primaryScale,
      height: bH * primaryScale,
    );

    if (primaryScale > 0.02) {
      // Glow halo behind bubble
      canvas.drawCircle(
        primaryRect.center,
        bW * 0.52 * primaryScale,
        Paint()
          ..shader = RadialGradient(
            colors: [_cyan.withOpacity(0.14 * globalOpacity), Colors.transparent],
          ).createShader(Rect.fromCircle(
              center: primaryRect.center, radius: bW * 0.52 * primaryScale)),
      );

      _drawChatBubble(
        canvas, primaryRect, 'left',
        _bubbleFill, _cyan, 1.5,
        primaryScale * globalOpacity,
      );

      // Gradient sheen across bubble top
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(primaryRect.left, primaryRect.top,
              primaryRect.width, primaryRect.height * 0.45),
          const Radius.circular(14),
        ),
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.white.withOpacity(0.10 * primaryScale * globalOpacity),
              Colors.transparent,
            ],
          ).createShader(primaryRect),
      );

      // ── Typing dots (3 dots, wave-staggered) ──────────────────
      // Dots animate from t=0.18 to t=0.90
      if (t > 0.18 && t < 0.92 && primaryScale > 0.8) {
        final dotProgress = ((t - 0.18) / 0.72).clamp(0.0, 1.0);
        const dotCount = 3;
        final dotSpacing = bW * 0.16;
        final dotBaseX   = primaryRect.center.dx - dotSpacing;
        final dotBaseY   = primaryRect.center.dy + bH * 0.04;
        const dotR       = 4.5;

        for (int i = 0; i < dotCount; i++) {
          // Each dot bobs up with a staggered phase
          final phase   = (dotProgress * 3.0 - i * 0.38) % 1.0;
          final bounce  = -sin(phase * pi).clamp(0.0, 1.0) * bH * 0.18;
          final dotOpacity = (0.5 + 0.5 * sin(phase * pi))
              .clamp(0.4, 1.0) * globalOpacity;

          canvas.drawCircle(
            Offset(dotBaseX + i * dotSpacing, dotBaseY + bounce),
            dotR,
            Paint()..color = _cyan.withOpacity(dotOpacity),
          );
          // Tiny glow
          canvas.drawCircle(
            Offset(dotBaseX + i * dotSpacing, dotBaseY + bounce),
            dotR * 1.9,
            Paint()..color = _cyan.withOpacity(dotOpacity * 0.22),
          );
        }
      }
    }

    // ── REPLY bubble (smaller, bottom-right) ────────────────────
    // Pops in during t=0.55→0.72, stays until t=0.92
    final replyProgress = t < 0.55
        ? 0.0
        : t < 0.72
            ? ((t - 0.55) / 0.17).clamp(0.0, 1.0)
            : 1.0;
    final replyScale = _elasticIn(replyProgress);

    if (replyScale > 0.02) {
      final rW = w * 0.38;
      final rH = h * 0.20;
      final replyRect = Rect.fromCenter(
        center: Offset(cx + w * 0.14, cy + h * 0.22),
        width:  rW * replyScale,
        height: rH * replyScale,
      );

      // Glow
      canvas.drawCircle(
        replyRect.center,
        rW * 0.45 * replyScale,
        Paint()
          ..shader = RadialGradient(
            colors: [_violet.withOpacity(0.16 * globalOpacity), Colors.transparent],
          ).createShader(Rect.fromCircle(
              center: replyRect.center, radius: rW * 0.45 * replyScale)),
      );

      _drawChatBubble(
        canvas, replyRect, 'right',
        const Color(0xFF2A1A4A),  // deep violet body
        _violet, 1.2,
        replyScale * globalOpacity,
      );

      // Sheen
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(replyRect.left, replyRect.top,
              replyRect.width, replyRect.height * 0.45),
          const Radius.circular(14),
        ),
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.white.withOpacity(0.10 * replyScale * globalOpacity),
              Colors.transparent,
            ],
          ).createShader(replyRect),
      );

      // Reply dots (2 only, faster phase)
      if (replyScale > 0.7) {
        final dotProgress = ((t - 0.72) / 0.20).clamp(0.0, 1.0);
        const dotCount = 2;
        final dotSpacing = rW * 0.20;
        final dotBaseX   = replyRect.center.dx - dotSpacing * 0.5;
        final dotBaseY   = replyRect.center.dy + rH * 0.04;
        const dotR       = 3.5;

        for (int i = 0; i < dotCount; i++) {
          final phase  = (dotProgress * 3.0 - i * 0.4) % 1.0;
          final bounce = -sin(phase * pi).clamp(0.0, 1.0) * rH * 0.20;
          final dotOp  = (0.5 + 0.5 * sin(phase * pi))
              .clamp(0.4, 1.0) * globalOpacity;

          canvas.drawCircle(
            Offset(dotBaseX + i * dotSpacing, dotBaseY + bounce),
            dotR,
            Paint()..color = _violet.withOpacity(dotOp),
          );
          canvas.drawCircle(
            Offset(dotBaseX + i * dotSpacing, dotBaseY + bounce),
            dotR * 2.0,
            Paint()..color = _violet.withOpacity(dotOp * 0.20),
          );
        }
      }
    }

    // ── Small notification dot (top-right of primary bubble) ────
    if (primaryScale > 0.8 && t < 0.55) {
      final notifOpacity = t < 0.25
          ? ((t - 0.18) / 0.07).clamp(0.0, 1.0) * globalOpacity
          : (1.0 - (t - 0.25) / 0.30).clamp(0.0, 1.0) * globalOpacity;

      if (notifOpacity > 0.01) {
        final nx = primaryRect.right - 2.0;
        final ny = primaryRect.top + 2.0;
        canvas.drawCircle(
            Offset(nx, ny), 7.0,
            Paint()..color = const Color(0xFFFF6B35).withOpacity(notifOpacity));
        canvas.drawCircle(
            Offset(nx, ny), 7.0,
            Paint()
              ..color = Colors.white.withOpacity(notifOpacity * 0.3)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.2);
        // Exclamation mark inside
        canvas.drawLine(
          Offset(nx, ny - 3.0), Offset(nx, ny + 1.0),
          Paint()..color = Colors.white.withOpacity(notifOpacity)
            ..strokeWidth = 1.5..strokeCap = StrokeCap.round,
        );
        canvas.drawCircle(
            Offset(nx, ny + 3.0), 0.9,
            Paint()..color = Colors.white.withOpacity(notifOpacity));
      }
    }
  }

  @override
  bool shouldRepaint(_ChatBubblesPainter old) => old.t != t;
}

// ─────────────────────────────────────────────────────────────────
//  ANIMATION 3 — Rotating Starburst
// ─────────────────────────────────────────────────────────────────

class _StarburstAnimation extends StatefulWidget {
  final double size;
  const _StarburstAnimation({super.key, required this.size});

  @override
  State<_StarburstAnimation> createState() => _StarburstState();
}

class _StarburstState extends State<_StarburstAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 3000))
      ..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => CustomPaint(
        size: Size(widget.size, widget.size),
        painter: _StarburstPainter(_ctrl.value),
      ),
    );
  }
}

class _StarburstPainter extends CustomPainter {
  final double t;
  _StarburstPainter(this.t);

  static const _cyan   = Color(0xFF00D4FF);
  static const _violet = Color(0xFF7B2FFF);
  static const _hot    = Color(0xFFFF6B35);
  static const _blue   = Color.fromRGBO(41, 116, 188, 1);

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r  = size.shortestSide * 0.38;

    const rays = 12;

    // Outer glow
    canvas.drawCircle(
      Offset(cx, cy),
      r * 0.35,
      Paint()
        ..shader = RadialGradient(
          colors: [_cyan.withOpacity(0.25), Colors.transparent],
        ).createShader(
            Rect.fromCircle(center: Offset(cx, cy), radius: r * 0.35)),
    );

    for (int i = 0; i < rays; i++) {
      final angle    = 2 * pi * i / rays + t * 2 * pi;
      final outerLen = r * (0.65 + 0.35 * sin(t * 2 * pi + i * 0.8));
      final inner    = r * 0.28;

      final rayColor = switch (i % 3) {
        0 => _cyan,
        1 => _hot,
        _ => _violet,
      };

      canvas.drawLine(
        Offset(cx + inner * cos(angle), cy + inner * sin(angle)),
        Offset(cx + outerLen * cos(angle), cy + outerLen * sin(angle)),
        Paint()
          ..color = rayColor.withOpacity(0.85)
          ..strokeWidth = 2.8
          ..strokeCap = StrokeCap.round,
      );

      // Tip dot
      canvas.drawCircle(
        Offset(cx + outerLen * cos(angle), cy + outerLen * sin(angle)),
        2.0,
        Paint()..color = Colors.white.withOpacity(0.6),
      );
    }

    // Centre orb
    canvas.drawCircle(
      Offset(cx, cy),
      r * 0.22,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.3, -0.4),
          colors: [const Color(0xFF4FC3F7), _blue],
        ).createShader(
            Rect.fromCircle(center: Offset(cx, cy), radius: r * 0.22)),
    );

    // Highlight on centre
    canvas.drawCircle(
      Offset(cx - r * 0.07, cy - r * 0.07),
      r * 0.07,
      Paint()..color = Colors.white.withOpacity(0.4),
    );
  }

  @override
  bool shouldRepaint(_StarburstPainter old) => true;
}