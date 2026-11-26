import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/firm/providers.dart';
import '../services/db_service.dart';
import '../theme/pc_tokens.dart';

/// Web Firm Registration Wizard (/register-firm)
/// Steps:
/// 1. Firm details (Name, Brand color)
/// 2. Admin account (Name, Email, Password)
/// 3. Email verification (Admin's email verified BEFORE firm creation)
/// 4. Terms acceptance & bot protection acknowledgment
/// 5. Done -> Creates firm in Trial state atomically and navigates to Admin Console.
class RegisterFirmPage extends ConsumerStatefulWidget {
  const RegisterFirmPage({super.key});

  @override
  ConsumerState<RegisterFirmPage> createState() => _RegisterFirmPageState();
}

class _RegisterFirmPageState extends ConsumerState<RegisterFirmPage> {
  int _currentStep = 0;

  // Form Controllers
  final _firmFormKey = GlobalKey<FormState>();
  final _adminFormKey = GlobalKey<FormState>();

  final _firmNameController = TextEditingController();
  final _adminNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  Color _selectedColor = const Color(0xFF2563EB);
  bool _obscurePassword = true;
  bool _termsAccepted = false;
  bool _isLoading = false;
  String? _errorMessage;

  User? _createdUser;
  Timer? _verificationTimer;

  @override
  void dispose() {
    _verificationTimer?.cancel();
    _firmNameController.dispose();
    _adminNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _showColorPicker() {
    final tokens = context.pcTokens;
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: tokens.surface,
        title: Text(
          'Select Brand Color',
          style: TextStyle(color: tokens.textPrimary),
        ),
        content: SingleChildScrollView(
          child: ColorPicker(
            pickerColor: _selectedColor,
            onColorChanged: (color) => setState(() => _selectedColor = color),
            labelTypes: const [],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: Text(
              'Done',
              style: TextStyle(
                color: tokens.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _colorToHex(Color color) {
    return '#${color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';
  }

  // Step 2 -> Step 3: Create Auth user and send verification email
  Future<void> _createAdminAndSendVerification() async {
    if (!_adminFormKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text;

      UserCredential credential;
      try {
        credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );
      } on FirebaseAuthException catch (e) {
        if (e.code == 'email-already-in-use') {
          credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
            email: email,
            password: password,
          );
        } else {
          rethrow;
        }
      }

      _createdUser = credential.user;
      await _createdUser?.updateDisplayName(_adminNameController.text.trim());

      if (_createdUser != null && !_createdUser!.emailVerified) {
        await _createdUser!.sendEmailVerification();
        _startEmailVerificationPolling();
      }

      if (mounted) {
        setState(() {
          _currentStep = 2;
        });
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage =
              e.message ?? 'Authentication error during registration';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
        });
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _startEmailVerificationPolling() {
    _verificationTimer?.cancel();
    _verificationTimer =
        Timer.periodic(const Duration(seconds: 4), (timer) async {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await user.reload();
        if (user.emailVerified) {
          timer.cancel();
          if (mounted) {
            setState(() {
              _currentStep = 3;
            });
          }
        }
      }
    });
  }

  Future<void> _checkEmailVerificationManual() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await user.reload();
      if (!mounted) return;
      if (user.emailVerified) {
        _verificationTimer?.cancel();
        setState(() {
          _currentStep = 3;
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Email not yet verified. Please click the link sent to your inbox.',
            ),
          ),
        );
      }
    }
  }

  // Step 4: Finalize atomic firm creation
  Future<void> _finalizeFirmCreation() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _errorMessage = 'Session expired. Please sign in again.');
      return;
    }

    if (!user.emailVerified) {
      setState(
        () => _errorMessage =
            'Admin email must be verified before firm creation.',
      );
      return;
    }

    if (!_termsAccepted) {
      setState(
        () => _errorMessage = 'Please accept the Terms of Service to proceed.',
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final firmId = await DBService.instance.signUpWithFirm(
        uid: user.uid,
        email: user.email ?? _emailController.text.trim(),
        adminName: _adminNameController.text.trim(),
        firmName: _firmNameController.text.trim(),
        primaryColor: _colorToHex(_selectedColor),
      );

      await ref.read(firmNotifierProvider.notifier).loadFirm(firmId);

      if (mounted) {
        context.go('/admin-dashboard');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to create firm: ${e.toString()}';
        });
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.pcTokens;
    final activeAccent = PcTokens.readableAccentOnLight(_selectedColor);

    // Guard against unauthorized mobile access
    if (!kIsWeb) {
      return Scaffold(
        backgroundColor: tokens.canvas,
        appBar: AppBar(backgroundColor: Colors.transparent),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: tokens.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: tokens.border),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: tokens.primarySoft,
                        shape: BoxShape.circle,
                        border: Border.all(color: tokens.primaryBorder),
                      ),
                      child: Icon(
                        Icons.computer,
                        size: 32,
                        color: tokens.primary,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Web Only Feature',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: tokens.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Corporate firm registration and admin setup are managed exclusively through the web portal.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: tokens.textSecondary,
                        fontSize: 14,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () => context.go('/welcome'),
                      child: const Text('Back to Welcome'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: tokens.canvas,
      appBar: AppBar(
        title: const Text('Register Corporate Firm'),
        centerTitle: true,
        backgroundColor: tokens.surface,
        shape: Border(bottom: BorderSide(color: tokens.border)),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: tokens.textPrimary),
          onPressed: () => context.go('/sign-in'),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Container(
                padding: const EdgeInsets.all(32.0),
                decoration: BoxDecoration(
                  color: tokens.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: tokens.border),
                  boxShadow: [
                    BoxShadow(
                      color: tokens.textPrimary.withValues(alpha: 0.04),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildStepIndicator(tokens, activeAccent),
                    const SizedBox(height: 32),

                    if (_errorMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: tokens.urgentBg,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: tokens.urgentBorder),
                        ),
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(
                            color: tokens.urgentText,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],

                    if (_currentStep == 0)
                      _buildFirmDetailsStep(tokens, activeAccent),
                    if (_currentStep == 1)
                      _buildAdminAccountStep(tokens, activeAccent),
                    if (_currentStep == 2)
                      _buildEmailVerificationStep(tokens, activeAccent),
                    if (_currentStep == 3)
                      _buildTermsAndConfirmStep(tokens, activeAccent),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStepIndicator(PcTokens tokens, Color activeAccent) {
    const steps = [
      'Firm Details',
      'Admin Account',
      'Verify Email',
      'Accept Terms',
    ];

    return Row(
      children: List.generate(steps.length * 2 - 1, (index) {
        if (index.isOdd) {
          final completedLine = index ~/ 2 < _currentStep;
          return Expanded(
            child: Divider(
              color: completedLine ? activeAccent : tokens.border,
              thickness: 2,
            ),
          );
        }
        final stepIndex = index ~/ 2;
        final isActive = stepIndex == _currentStep;
        final isDone = stepIndex < _currentStep;

        return Column(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDone
                    ? activeAccent
                    : (isActive
                        ? activeAccent.withValues(alpha: 0.12)
                        : tokens.surfaceSubtle),
                border: Border.all(
                  color: (isActive || isDone)
                      ? activeAccent
                      : tokens.borderStrong,
                  width: 1.8,
                ),
              ),
              child: Center(
                child: isDone
                    ? Icon(
                        Icons.check,
                        size: 16,
                        color: PcTokens.contrastOn(activeAccent),
                      )
                    : Text(
                        '${stepIndex + 1}',
                        style: TextStyle(
                          color: isActive ? activeAccent : tokens.textMuted,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              steps[stepIndex],
              style: TextStyle(
                fontSize: 11,
                color: isActive ? tokens.textPrimary : tokens.textMuted,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        );
      }),
    );
  }

  // Step 1: Firm Details
  Widget _buildFirmDetailsStep(PcTokens tokens, Color activeAccent) {
    return Form(
      key: _firmFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Company Information',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: tokens.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Configure your company name and primary brand identity.',
            style: TextStyle(color: tokens.textSecondary, fontSize: 13.5),
          ),
          const SizedBox(height: 24),
          TextFormField(
            controller: _firmNameController,
            style: TextStyle(color: tokens.textPrimary),
            decoration: InputDecoration(
              labelText: 'Company / Firm Name',
              hintText: 'e.g. Acme Corporation',
              prefixIcon: Icon(
                Icons.business_outlined,
                color: tokens.textMuted,
              ),
            ),
            validator: (v) => (v == null || v.trim().isEmpty)
                ? 'Please enter your firm name'
                : null,
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: tokens.surfaceSubtle,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: tokens.border),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Brand Theme Color',
                        style: TextStyle(
                          color: tokens.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _colorToHex(_selectedColor),
                        style: TextStyle(
                          color: tokens.textSecondary,
                          fontSize: 12,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                ),
                InkWell(
                  onTap: _showColorPicker,
                  borderRadius: BorderRadius.circular(24),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: _selectedColor,
                      shape: BoxShape.circle,
                      border: Border.all(color: tokens.borderStrong, width: 2),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: () {
              if (_firmFormKey.currentState!.validate()) {
                setState(() => _currentStep = 1);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: activeAccent,
              foregroundColor: PcTokens.contrastOn(activeAccent),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Next: Admin Account',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  // Step 2: Admin Account
  Widget _buildAdminAccountStep(PcTokens tokens, Color activeAccent) {
    return Form(
      key: _adminFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Create Admin Account',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: tokens.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'You will be the primary administrator of this firm workspace.',
            style: TextStyle(color: tokens.textSecondary, fontSize: 13.5),
          ),
          const SizedBox(height: 24),
          TextFormField(
            controller: _adminNameController,
            style: TextStyle(color: tokens.textPrimary),
            decoration: InputDecoration(
              labelText: 'Your Full Name',
              prefixIcon: Icon(Icons.person_outline, color: tokens.textMuted),
            ),
            validator: (v) => (v == null || v.trim().isEmpty)
                ? 'Please enter your name'
                : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            style: TextStyle(color: tokens.textPrimary),
            decoration: InputDecoration(
              labelText: 'Corporate Email',
              hintText: 'admin@company.com',
              prefixIcon: Icon(Icons.email_outlined, color: tokens.textMuted),
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) {
                return 'Please enter your email';
              }
              if (!v.contains('@')) return 'Please enter a valid email';
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            style: TextStyle(color: tokens.textPrimary),
            decoration: InputDecoration(
              labelText: 'Password',
              prefixIcon: Icon(Icons.lock_outline, color: tokens.textMuted),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  color: tokens.textMuted,
                ),
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
              ),
            ),
            validator: (v) => (v == null || v.length < 8)
                ? 'Password must be at least 8 characters'
                : null,
          ),
          const SizedBox(height: 32),
          Row(
            children: [
              OutlinedButton(
                onPressed: () => setState(() => _currentStep = 0),
                style: OutlinedButton.styleFrom(
                  foregroundColor: tokens.textPrimary,
                  side: BorderSide(color: tokens.borderStrong),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Back'),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed:
                      _isLoading ? null : _createAdminAndSendVerification,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: activeAccent,
                    foregroundColor: PcTokens.contrastOn(activeAccent),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: PcTokens.contrastOn(activeAccent),
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'Next: Verify Email',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Step 3: Verify Email
  Widget _buildEmailVerificationStep(PcTokens tokens, Color activeAccent) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: activeAccent.withValues(alpha: 0.12),
              shape: BoxShape.circle,
              border: Border.all(color: activeAccent.withValues(alpha: 0.28)),
            ),
            child: Icon(
              Icons.mark_email_read_outlined,
              size: 38,
              color: activeAccent,
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Verify Your Email Address',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: tokens.textPrimary,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'We have sent a verification link to ${_emailController.text.trim()}.\nPlease click the link to confirm your identity before your firm is created.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: tokens.textSecondary,
            fontSize: 13.5,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: tokens.surfaceSubtle,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: tokens.border),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: activeAccent,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  'Waiting for confirmation... Click the link in your email.',
                  style: TextStyle(fontSize: 12.5, color: tokens.textSecondary),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        ElevatedButton(
          onPressed: _checkEmailVerificationManual,
          style: ElevatedButton.styleFrom(
            backgroundColor: activeAccent,
            foregroundColor: PcTokens.contrastOn(activeAccent),
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Text(
            "I've Verified My Email",
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: () async {
            await FirebaseAuth.instance.currentUser?.sendEmailVerification();
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Verification link resent to your email.'),
              ),
            );
          },
          child: Text(
            'Resend Verification Email',
            style: TextStyle(color: activeAccent, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }

  // Step 4: Terms & Creation
  Widget _buildTermsAndConfirmStep(PcTokens tokens, Color activeAccent) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Terms of Service & Plan',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: tokens.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: tokens.surfaceSubtle,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: tokens.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: tokens.infoSoft,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'PLAN: TRIAL TIER',
                      style: TextStyle(
                        color: tokens.infoAccent,
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '5 Team Seats Included',
                    style: TextStyle(
                      color: tokens.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                '• Self-service instant workspace creation\n'
                '• Maximum 5 team seats during initial trial period\n'
                '• Enterprise encryption & platform suspension abuse protections\n'
                '• Payment and billing integration can be added later',
                style: TextStyle(
                  color: tokens.textSecondary,
                  fontSize: 12.5,
                  height: 1.6,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),

        // Bot protection badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: tokens.online.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: tokens.online.withValues(alpha: 0.30)),
          ),
          child: const Row(
            children: [
              Icon(Icons.shield_outlined, color: Color(0xFF059669), size: 20),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Protected by Firebase App Check & reCAPTCHA',
                  style: TextStyle(
                    color: Color(0xFF059669),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        CheckboxListTile(
          value: _termsAccepted,
          onChanged: (val) => setState(() => _termsAccepted = val ?? false),
          activeColor: activeAccent,
          contentPadding: EdgeInsets.zero,
          title: Text(
            'I accept the ProntoChat Master Services Agreement and Workspace Terms of Service.',
            style: TextStyle(color: tokens.textPrimary, fontSize: 13),
          ),
        ),
        const SizedBox(height: 20),
        ElevatedButton(
          onPressed:
              (_isLoading || !_termsAccepted) ? null : _finalizeFirmCreation,
          style: ElevatedButton.styleFrom(
            backgroundColor: activeAccent,
            foregroundColor: PcTokens.contrastOn(activeAccent),
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: _isLoading
              ? SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    color: PcTokens.contrastOn(activeAccent),
                    strokeWidth: 2,
                  ),
                )
              : const Text(
                  'Complete Registration & Open Console',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                ),
        ),
      ],
    );
  }
}
