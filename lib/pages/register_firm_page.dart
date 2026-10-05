import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/firm/providers.dart';
import '../services/db_service.dart';

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

  Color _selectedColor = const Color(0xFF295CB4);
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
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: const Color.fromRGBO(34, 33, 33, 1),
        title: const Text('Select Brand Color', style: TextStyle(color: Colors.white)),
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
            child: const Text('Done', style: TextStyle(color: Color.fromRGBO(41, 116, 188, 1))),
          ),
        ],
      ),
    );
  }

  String _colorToHex(Color color) {
    return '#${color.value.toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';
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
          // Check if already signed in or try sign in
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

      // If email is not yet verified, send verification link
      if (_createdUser != null && !_createdUser!.emailVerified) {
        await _createdUser!.sendEmailVerification();
        _startEmailVerificationPolling();
      }

      setState(() {
        _currentStep = 2; // Move to Verification Step
      });
    } on FirebaseAuthException catch (e) {
      setState(() {
        _errorMessage = e.message ?? 'Authentication error during registration';
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _startEmailVerificationPolling() {
    _verificationTimer?.cancel();
    _verificationTimer = Timer.periodic(const Duration(seconds: 4), (timer) async {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await user.reload();
        if (user.emailVerified) {
          timer.cancel();
          if (mounted) {
            setState(() {
              _currentStep = 3; // Move to Terms & Creation
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
      if (user.emailVerified) {
        _verificationTimer?.cancel();
        setState(() {
          _currentStep = 3;
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Email not yet verified. Please click the link sent to your inbox.'),
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
      setState(() => _errorMessage = 'Admin email must be verified before firm creation.');
      return;
    }

    if (!_termsAccepted) {
      setState(() => _errorMessage = 'Please accept the Terms of Service to proceed.');
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

      // Warm up firm provider state
      await ref.read(firmNotifierProvider.notifier).loadFirm(firmId);

      // Navigate to Admin Dashboard on Web
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
    // Guard against unauthorized mobile access
    if (!kIsWeb) {
      return Scaffold(
        backgroundColor: const Color.fromRGBO(24, 23, 23, 1),
        appBar: AppBar(backgroundColor: Colors.transparent),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.computer, size: 54, color: Colors.blueAccent),
                const SizedBox(height: 16),
                const Text(
                  'Web Only Feature',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 8),
                Text(
                  'Corporate firm registration and admin setup are managed exclusively through the web portal.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey[400], fontSize: 14),
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
      );
    }

    return Scaffold(
      backgroundColor: const Color.fromRGBO(24, 23, 23, 1),
      appBar: AppBar(
        title: const Text('Register Corporate Firm'),
        centerTitle: true,
        backgroundColor: const Color.fromRGBO(34, 33, 33, 1),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/sign-in'),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 640),
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 32),
              child: Card(
                color: const Color.fromRGBO(30, 29, 29, 1),
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(color: Colors.grey[800]!),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Step Progress Indicator
                      _buildStepIndicator(),
                      const SizedBox(height: 32),

                      if (_errorMessage != null) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red[900]?.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.red[700]!),
                          ),
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],

                      // Step Content Switcher
                      if (_currentStep == 0) _buildFirmDetailsStep(),
                      if (_currentStep == 1) _buildAdminAccountStep(),
                      if (_currentStep == 2) _buildEmailVerificationStep(),
                      if (_currentStep == 3) _buildTermsAndConfirmStep(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStepIndicator() {
    final steps = ['Firm Details', 'Admin Account', 'Verify Email', 'Accept Terms'];

    return Row(
      children: List.generate(steps.length * 2 - 1, (index) {
        if (index.isOdd) {
          return Expanded(
            child: Divider(
              color: (index ~/ 2 < _currentStep)
                  ? const Color.fromRGBO(41, 116, 188, 1)
                  : Colors.grey[800],
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
                    ? const Color.fromRGBO(41, 116, 188, 1)
                    : (isActive ? const Color.fromRGBO(41, 116, 188, 0.2) : Colors.grey[900]),
                border: Border.all(
                  color: (isActive || isDone)
                      ? const Color.fromRGBO(41, 116, 188, 1)
                      : Colors.grey[700]!,
                  width: 2,
                ),
              ),
              child: Center(
                child: isDone
                    ? const Icon(Icons.check, size: 16, color: Colors.white)
                    : Text(
                        '${stepIndex + 1}',
                        style: TextStyle(
                          color: isActive ? Colors.white : Colors.grey[400],
                          fontWeight: FontWeight.bold,
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
                color: isActive ? Colors.white : Colors.grey[500],
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        );
      }),
    );
  }

  // Step 1: Firm Details
  Widget _buildFirmDetailsStep() {
    return Form(
      key: _firmFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Company Information',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 6),
          Text(
            'Configure your company name and primary brand identity.',
            style: TextStyle(color: Colors.grey[400], fontSize: 13),
          ),
          const SizedBox(height: 24),
          TextFormField(
            controller: _firmNameController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'Company / Firm Name',
              hintText: 'e.g. Acme Corporation',
              prefixIcon: const Icon(Icons.business_outlined, color: Colors.grey),
              filled: true,
              fillColor: const Color.fromRGBO(24, 23, 23, 1),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter your firm name' : null,
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Brand Theme Color', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text(_colorToHex(_selectedColor), style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                  ],
                ),
              ),
              GestureDetector(
                onTap: _showColorPicker,
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: _selectedColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white24, width: 2),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: () {
              if (_firmFormKey.currentState!.validate()) {
                setState(() => _currentStep = 1);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color.fromRGBO(41, 116, 188, 1),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Next: Admin Account', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // Step 2: Admin Account
  Widget _buildAdminAccountStep() {
    return Form(
      key: _adminFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Create Admin Account',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 6),
          Text(
            'You will be the primary administrator of this firm workspace.',
            style: TextStyle(color: Colors.grey[400], fontSize: 13),
          ),
          const SizedBox(height: 24),
          TextFormField(
            controller: _adminNameController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'Your Full Name',
              prefixIcon: const Icon(Icons.person_outline, color: Colors.grey),
              filled: true,
              fillColor: const Color.fromRGBO(24, 23, 23, 1),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter your name' : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'Corporate Email',
              hintText: 'admin@company.com',
              prefixIcon: const Icon(Icons.email_outlined, color: Colors.grey),
              filled: true,
              fillColor: const Color.fromRGBO(24, 23, 23, 1),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Please enter your email';
              if (!v.contains('@')) return 'Please enter a valid email';
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'Password',
              prefixIcon: const Icon(Icons.lock_outline, color: Colors.grey),
              suffixIcon: IconButton(
                icon: Icon(_obscurePassword ? Icons.visibility : Icons.visibility_off, color: Colors.grey),
                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
              ),
              filled: true,
              fillColor: const Color.fromRGBO(24, 23, 23, 1),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            validator: (v) => (v == null || v.length < 8) ? 'Password must be at least 8 characters' : null,
          ),
          const SizedBox(height: 32),
          Row(
            children: [
              OutlinedButton(
                onPressed: () => setState(() => _currentStep = 0),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Back'),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _createAdminAndSendVerification,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color.fromRGBO(41, 116, 188, 1),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isLoading
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Next: Verify Email', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Step 3: Verify Email
  Widget _buildEmailVerificationStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.mark_email_read_outlined, size: 40, color: Color.fromRGBO(41, 116, 188, 1)),
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'Verify Your Email Address',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        const SizedBox(height: 10),
        Text(
          'We have sent a verification link to ${_emailController.text.trim()}.\nPlease click the link to confirm your identity before your firm is created.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey[400], fontSize: 13, height: 1.5),
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color.fromRGBO(24, 23, 23, 1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[800]!),
          ),
          child: Row(
            children: const [
              SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
              SizedBox(width: 14),
              Expanded(
                child: Text(
                  'Waiting for confirmation... Click the link in your email.',
                  style: TextStyle(fontSize: 12, color: Colors.white70),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        ElevatedButton(
          onPressed: _checkEmailVerificationManual,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color.fromRGBO(41, 116, 188, 1),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: const Text("I've Verified My Email", style: TextStyle(fontWeight: FontWeight.bold)),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: () async {
            await FirebaseAuth.instance.currentUser?.sendEmailVerification();
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Verification link resent to your email.')),
              );
            }
          },
          child: const Text('Resend Verification Email', style: TextStyle(color: Color.fromRGBO(41, 116, 188, 1))),
        ),
      ],
    );
  }

  // Step 4: Terms & Creation
  Widget _buildTermsAndConfirmStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Terms of Service & Plan',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color.fromRGBO(24, 23, 23, 1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[800]!),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text('PLAN: TRIAL TIER', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 11)),
                  ),
                  const Spacer(),
                  const Text('5 Team Seats Included', style: TextStyle(color: Colors.white70, fontSize: 12)),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                '• Self-service instant workspace creation\n'
                '• Maximum 5 team seats during initial trial period\n'
                '• Enterprise encryption & platform suspension abuse protections\n'
                '• Payment and billing integration can be added later',
                style: TextStyle(color: Colors.grey[400], fontSize: 12, height: 1.6),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Bot protection badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.green.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.green.withOpacity(0.3)),
          ),
          child: Row(
            children: const [
              Icon(Icons.shield_outlined, color: Colors.greenAccent, size: 20),
              SizedBox(width: 10),
              Text('Protected by Firebase App Check & reCAPTCHA', style: TextStyle(color: Colors.greenAccent, fontSize: 12)),
            ],
          ),
        ),
        const SizedBox(height: 20),

        CheckboxListTile(
          value: _termsAccepted,
          onChanged: (val) => setState(() => _termsAccepted = val ?? false),
          activeColor: const Color.fromRGBO(41, 116, 188, 1),
          contentPadding: EdgeInsets.zero,
          title: const Text(
            'I accept the ProntoChat Master Services Agreement and Workspace Terms of Service.',
            style: TextStyle(color: Colors.white, fontSize: 13),
          ),
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: (_isLoading || !_termsAccepted) ? null : _finalizeFirmCreation,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color.fromRGBO(41, 116, 188, 1),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: _isLoading
              ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Text('Complete Registration & Open Console', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        ),
      ],
    );
  }
}
