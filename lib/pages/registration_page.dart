import 'dart:math';
import 'package:flutter/material.dart';
import './login_page.dart'; // Import the login page for navigation
import '../services/navigation_service.dart';

// ─────────────────────────────────────────────
//  LAUNCH ORBS  –  Custom animated illustration
// ─────────────────────────────────────────────

class _LaunchOrbPainter extends CustomPainter {
  final double pulse;       // 0 → 1, drives the plasma ring
  final double orbit;       // 0 → 2π, drives three orbiting dots
  final double rocketY;     // 0 → 1, rocket rises then resets
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
    final r  = size.shortestSide * 0.30; // base orb radius

    // ── 1. Outer glow halo ──────────────────────────────────────────
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

    // ── 2. Plasma ring (pulsing stroke) ─────────────────────────────
    final ringRadius = r * (1.0 + 0.06 * sin(pulse * 2 * pi));
    final ringPaint  = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..shader = SweepGradient(
        startAngle: pulse * 2 * pi,
        colors: [_cyan, _violet, _blue, _cyan],
      ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: ringRadius));
    canvas.drawCircle(Offset(cx, cy), ringRadius, ringPaint);

    // ── 3. Core orb (radial gradient sphere) ────────────────────────
    final orbPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.3, -0.4),
        colors: [
          const Color(0xFF4FC3F7),
          _blue,
          const Color(0xFF0A1628),
        ],
        stops: const [0.0, 0.45, 1.0],
      ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: r));
    canvas.drawCircle(Offset(cx, cy), r, orbPaint);

    // ── 4. Inner shimmer highlight ───────────────────────────────────
    final highlightPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.25, -0.35),
        colors: [Colors.white.withOpacity(0.45), Colors.transparent],
        stops: const [0.0, 0.6],
      ).createShader(Rect.fromCircle(center: Offset(cx - r * 0.25, cy - r * 0.30), radius: r * 0.45));
    canvas.drawCircle(Offset(cx - r * 0.25, cy - r * 0.30), r * 0.45, highlightPaint);

    // ── 5. Three orbiting satellites ────────────────────────────────
    const orbitR = [1.60, 1.80, 1.45]; // relative radii
    const orbitOffset = [0.0, 2.09, 4.19]; // 0, 2π/3, 4π/3
    const dotSizes  = [4.5, 3.5, 5.0];
    const dotColors = [_cyan, _violet, _hot];

    for (int i = 0; i < 3; i++) {
      final angle = orbit + orbitOffset[i];
      final ox = cx + r * orbitR[i] * cos(angle);
      final oy = cy + r * orbitR[i] * 0.35 * sin(angle); // squash → elliptical orbit
      canvas.drawCircle(
        Offset(ox, oy),
        dotSizes[i],
        Paint()..color = dotColors[i].withOpacity(0.92),
      );
      // Tiny glow around each satellite
      canvas.drawCircle(
        Offset(ox, oy),
        dotSizes[i] * 2.5,
        Paint()..color = dotColors[i].withOpacity(0.18),
      );
    }

    // ── 6. Rocket ───────────────────────────────────────────────────
    //   rocketY 0→0.4  : rising from below orb
    //   rocketY 0.4→0.7: passing through centre
    //   rocketY 0.7→1.0: exiting above with trail fade

    final rocketCenterY = cy + r * 0.5 - rocketY * r * 2.8;
    final rocketCenterX = cx;
    final rocketScale   = 0.055 * r; // body half-width

    // Flame / exhaust trail (below rocket)
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
                colors: [_hot.withOpacity(tAlpha), _cyan.withOpacity(tAlpha * 0.4), Colors.transparent],
              ).createShader(Rect.fromCircle(center: Offset(rocketCenterX, ty), radius: tR * 2.5)),
          );
        }
      }
    }

    // Rocket body (capsule)
    final bodyPath = Path();
    final bx = rocketCenterX;
    final by = rocketCenterY;
    final bw = rocketScale;
    final bh = rocketScale * 3.2;

    // Nose cone
    bodyPath.moveTo(bx, by - bh);
    bodyPath.quadraticBezierTo(bx + bw * 1.1, by - bh * 0.3, bx + bw, by);
    bodyPath.lineTo(bx - bw, by);
    bodyPath.quadraticBezierTo(bx - bw * 1.1, by - bh * 0.3, bx, by - bh);

    // Body rect (below nose)
    bodyPath.moveTo(bx - bw, by);
    bodyPath.lineTo(bx - bw, by + bh * 0.9);
    bodyPath.lineTo(bx + bw, by + bh * 0.9);
    bodyPath.lineTo(bx + bw, by);
    bodyPath.close();

    canvas.drawPath(
      bodyPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [const Color(0xFFCFD8E3), Colors.white, const Color(0xFF90A4AE)],
        ).createShader(Rect.fromCenter(center: Offset(bx, by), width: bw * 3, height: bh * 3)),
    );

    // Window on rocket
    canvas.drawCircle(
      Offset(bx, by - bh * 0.35),
      bw * 0.62,
      Paint()..color = _cyan.withOpacity(0.9),
    );
    canvas.drawCircle(
      Offset(bx, by - bh * 0.35),
      bw * 0.35,
      Paint()..color = const Color(0xFF001F3F),
    );

    // Left fin
    final finL = Path()
      ..moveTo(bx - bw, by + bh * 0.5)
      ..lineTo(bx - bw * 2.6, by + bh * 1.1)
      ..lineTo(bx - bw, by + bh * 0.9)
      ..close();
    canvas.drawPath(finL, Paint()..color = _blue);

    // Right fin
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

// ─────────────────────────────────────────────────────────
//  Stateful wrapper that drives the three AnimationControllers
// ─────────────────────────────────────────────────────────

class _LaunchOrbAnimation extends StatefulWidget {
  final double size;
  const _LaunchOrbAnimation({required this.size});

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
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();

    _orbitCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    )..repeat();

    _rocketCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    )..repeat(period: const Duration(milliseconds: 3600));

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
        // Trail only visible when rocket is actively flying (0.05 → 0.90)
        final t = _rocket.value;
        final trailOpacity = (t > 0.05 && t < 0.92)
            ? (t < 0.5 ? (t - 0.05) / 0.45 : (0.92 - t) / 0.42).clamp(0.0, 1.0)
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

// ─────────────────────────────────────────────
//  REGISTRATION PAGE  (unchanged except widget)
// ─────────────────────────────────────────────

class RegistrationPage extends StatefulWidget {
  const RegistrationPage({super.key});

  @override
  State<StatefulWidget> createState() => _RegPageState();
}

class _RegPageState extends State<RegistrationPage> {
  late double _deviceHeight;
  late double _deviceWidth;

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final TextEditingController _nameController            = TextEditingController();
  final TextEditingController _emailController           = TextEditingController();
  final TextEditingController _passwordController        = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    _deviceHeight = MediaQuery.of(context).size.height;
    _deviceWidth  = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: const Color.fromRGBO(28, 27, 27, 1),
      body: SingleChildScrollView(
        child: Container(
          height: _deviceHeight,
          padding: EdgeInsets.symmetric(horizontal: _deviceWidth * 0.08),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              _headingWidget(),
              SizedBox(height: _deviceHeight * 0.02),
              _animatedPictureWidget(),   // ← replaced
              SizedBox(height: _deviceHeight * 0.04),
              _inputForm(),
              SizedBox(height: _deviceHeight * 0.06),
              _signUpButton(),
              SizedBox(height: _deviceHeight * 0.05),
              _loginText(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _headingWidget() {
    return SizedBox(
      width: _deviceWidth,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          const Text(
            "Let's Get Going",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Enter Your Details Below",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w400,
              color: Colors.grey[400],
            ),
          ),
        ],
      ),
    );
  }

  /// ── NEW: custom rocket-launching-through-orb animation ──
  Widget _animatedPictureWidget() {
    final animSize = _deviceHeight * 0.17; // compact but punchy
    return SizedBox(
      height: animSize,
      width: animSize,
      child: _LaunchOrbAnimation(size: animSize),
    );
  }

  Widget _inputForm() {
    return Form(
      key: _formKey,
      child: Column(
        children: <Widget>[
          _nameTextField(),
          const SizedBox(height: 20),
          _emailTextField(),
          const SizedBox(height: 20),
          _passwordTextField(),
          const SizedBox(height: 20),
          _confirmPasswordTextField(),
        ],
      ),
    );
  }

  Widget _nameTextField() {
    return TextFormField(
      controller: _nameController,
      autocorrect: true,
      style: const TextStyle(color: Colors.white),
      enabled: !_isLoading,
      validator: (input) {
        if (input == null || input.isEmpty) return 'Please enter your name';
        if (input.length < 2) return 'Name must be at least 2 characters';
        return null;
      },
      decoration: _inputDecoration("Full Name", Icons.person_outline),
    );
  }

  Widget _emailTextField() {
    return TextFormField(
      controller: _emailController,
      autocorrect: false,
      keyboardType: TextInputType.emailAddress,
      style: const TextStyle(color: Colors.white),
      enabled: !_isLoading,
      validator: (input) {
        if (input == null || input.isEmpty) return 'Please enter your email';
        if (!input.contains('@') || !input.contains('.')) return 'Please enter a valid email';
        return null;
      },
      decoration: _inputDecoration("Email Address", Icons.email_outlined),
    );
  }

  Widget _passwordTextField() {
    return TextFormField(
      controller: _passwordController,
      obscureText: true,
      autocorrect: false,
      style: const TextStyle(color: Colors.white),
      enabled: !_isLoading,
      validator: (input) {
        if (input == null || input.isEmpty) return 'Please enter your password';
        if (input.length < 6) return 'Password must be at least 6 characters';
        return null;
      },
      decoration: _inputDecoration("Password", Icons.lock_outline),
    );
  }

  Widget _confirmPasswordTextField() {
    return TextFormField(
      controller: _confirmPasswordController,
      obscureText: true,
      autocorrect: false,
      style: const TextStyle(color: Colors.white),
      enabled: !_isLoading,
      validator: (input) {
        if (input == null || input.isEmpty) return 'Please confirm your password';
        if (input != _passwordController.text) return 'Passwords do not match';
        return null;
      },
      decoration: _inputDecoration("Confirm Password", Icons.lock_outline),
    );
  }

  InputDecoration _inputDecoration(String hint, IconData icon) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.grey),
      filled: true,
      fillColor: Colors.grey[900]!.withOpacity(0.5),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color.fromRGBO(41, 116, 188, 1), width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      prefixIcon: Icon(icon, color: Colors.grey),
    );
  }

  Widget _signUpButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _register,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color.fromRGBO(41, 116, 188, 1),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 0,
          disabledBackgroundColor: const Color.fromRGBO(41, 116, 188, 0.6),
        ),
        child: _isLoading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : const Text("Sign Up", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _loginText() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text("Already have an account? ", style: TextStyle(color: Colors.grey[400], fontSize: 16)),
        GestureDetector(
          onTap: _isLoading ? null : _navigateToLogin,
          child: Text(
            "Login",
            style: TextStyle(
              color: _isLoading ? Colors.grey[600] : const Color.fromRGBO(41, 116, 188, 1),
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  void _register() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Registration successful! Please login.'),
            backgroundColor: Colors.green,
          ),
        );
        _navigateToLogin();
      }
    }
  }

  void _navigateToLogin() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const LoginPage()),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }
}