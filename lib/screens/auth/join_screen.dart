import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../models/firm.dart';
import '../../widgets/common/pc_logo.dart';
import '../../services/db_service.dart';
import '../../providers/auth_provider.dart' as app_auth;
import '../../theme/pc_tokens.dart';

/// Employee Onboarding Screen (/join).
/// Handles QR scans, invite deep links, or manual firm entry.
/// Verifies employee identifier with one-time code, creates auth account,
/// and writes the active membership directly so onboarding happens once.
class JoinScreen extends StatefulWidget {
  final String? initialFirmId;
  final String? initialCode;

  const JoinScreen({
    super.key,
    this.initialFirmId,
    this.initialCode,
  });

  @override
  State<JoinScreen> createState() => _JoinScreenState();
}

class _JoinScreenState extends State<JoinScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _firmIdController;
  late final TextEditingController _codeController;
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  Firm? _loadedFirm;
  bool _isLoadingFirm = false;
  bool _isSubmitting = false;
  bool _isPasswordVisible = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _firmIdController = TextEditingController(text: widget.initialFirmId ?? '');
    _codeController = TextEditingController(text: widget.initialCode ?? '');

    if (widget.initialFirmId != null && widget.initialFirmId!.isNotEmpty) {
      _fetchFirmDetails(widget.initialFirmId!.trim());
    }
  }

  @override
  void dispose() {
    _firmIdController.dispose();
    _codeController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _fetchFirmDetails(String firmId) async {
    if (firmId.trim().isEmpty) return;

    setState(() {
      _isLoadingFirm = true;
      _errorMessage = null;
    });

    try {
      final firm = await DBService.instance.getFirm(firmId.trim());
      if (mounted) {
        setState(() {
          _loadedFirm = firm;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Workspace not found. Please verify the Firm ID.';
          _loadedFirm = null;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingFirm = false;
        });
      }
    }
  }

  Color _parseFirmColor(String? hexString) {
    if (hexString == null) return PcTokens.defaultBrandBlue;
    try {
      final clean = hexString.replaceAll('#', '');
      return Color(int.parse('FF$clean', radix: 16));
    } catch (_) {
      return PcTokens.defaultBrandBlue;
    }
  }

  Future<void> _handleJoin() async {
    if (!_formKey.currentState!.validate()) return;

    final firmId = _firmIdController.text.trim();
    final code = _codeController.text.trim();
    final name = _nameController.text.trim();
    final email = _emailController.text.trim().toLowerCase();
    final password = _passwordController.text;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      // 1. Create or obtain authenticated user
      User? user = FirebaseAuth.instance.currentUser;
      if (user != null &&
          !user.isAnonymous &&
          user.email?.toLowerCase() == email) {
        // Already signed in with this email
      } else {
        if (user != null && user.isAnonymous) {
          await FirebaseAuth.instance.signOut();
        }

        try {
          final credential =
              await FirebaseAuth.instance.createUserWithEmailAndPassword(
            email: email,
            password: password,
          );
          user = credential.user;
          await user?.updateDisplayName(name);
        } on FirebaseAuthException catch (e) {
          if (e.code == 'email-already-in-use') {
            try {
              final cred =
                  await FirebaseAuth.instance.signInWithEmailAndPassword(
                email: email,
                password: password,
              );
              user = cred.user;
            } catch (signInErr) {
              throw Exception(
                'An account for $email already exists. Please verify your password or sign in.',
              );
            }
          } else {
            rethrow;
          }
        }
      }

      if (user == null) {
        throw Exception('Authentication failed during onboarding.');
      }

      // 2. Perform atomic verification and onboarding write
      await DBService.instance.verifyAndOnboardEmployee(
        firmId: firmId,
        uid: user.uid,
        email: email,
        name: name,
        code: code,
      );

      // 3. Refresh user session in provider
      if (!mounted) return;
      final authProvider =
          Provider.of<app_auth.AuthProvider>(context, listen: false);
      await authProvider.refreshUserProfile();

      if (!mounted) return;
      context.go('/home');
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception:', '').trim();
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  InputDecoration _inputDecoration({
    required PcTokens tokens,
    required Color activeAccent,
    required String label,
    required IconData icon,
    String? hint,
    String? helper,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: tokens.textSecondary),
      hintText: hint,
      hintStyle: TextStyle(color: tokens.textMuted, letterSpacing: 0),
      helperText: helper,
      helperStyle: TextStyle(color: tokens.textMuted, fontSize: 11),
      prefixIcon: Icon(icon, color: tokens.textMuted),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: tokens.surfaceSubtle,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: tokens.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: tokens.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: activeAccent, width: 1.6),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.pcTokens;
    final width = MediaQuery.sizeOf(context).width;
    final isWide = !PcBreakpoints.isCompact(width);
    final rawPrimary = _parseFirmColor(_loadedFirm?.primaryColor);
    final activeAccent = PcTokens.readableAccentOnLight(rawPrimary);
    final onAccent = PcTokens.contrastOn(activeAccent);

    final formBody = Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Company Branding Header
          Center(
            child: PcLogo(
              logo: _loadedFirm?.logo,
              legacyUrl: _loadedFirm?.logoUrl,
              size: 72,
              borderRadius: 20,
              variant: MediaVariant.logoLg,
              firmName: _loadedFirm?.name ?? '',
              primaryColor: activeAccent,
            ),
          ),
          const SizedBox(height: 16),

          Text(
            _loadedFirm != null
                ? 'Join ${_loadedFirm!.name}'
                : 'Join Your Company Workspace',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: tokens.textPrimary,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            (_loadedFirm?.welcomeText != null &&
                    _loadedFirm!.welcomeText!.trim().isNotEmpty)
                ? _loadedFirm!.welcomeText!.trim()
                : (_loadedFirm != null
                    ? 'Enter your pre-authorized code to activate access'
                    : 'Enter your company ID and one-time code'),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13.5,
              color: tokens.textSecondary,
            ),
          ),
          const SizedBox(height: 24),

          // Error Banner
          if (_errorMessage != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: tokens.urgentBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: tokens.urgentBorder),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.error_outline,
                    color: tokens.urgentText,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(
                        color: tokens.urgentText,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],

          // Firm ID Field (if not already loaded)
          if (_loadedFirm == null) ...[
            TextFormField(
              key: const Key('join_firm_id_field'),
              controller: _firmIdController,
              style: TextStyle(color: tokens.textPrimary),
              decoration: _inputDecoration(
                tokens: tokens,
                activeAccent: activeAccent,
                label: 'Firm ID',
                hint: 'e.g. firm_xyz123',
                icon: Icons.vpn_key_outlined,
                suffixIcon: _isLoadingFirm
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: Center(
                          child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: activeAccent,
                            ),
                          ),
                        ),
                      )
                    : IconButton(
                        icon: Icon(Icons.arrow_forward, color: activeAccent),
                        onPressed: () =>
                            _fetchFirmDetails(_firmIdController.text),
                      ),
              ),
              validator: (val) => (val == null || val.trim().isEmpty)
                  ? 'Please enter your Firm ID'
                  : null,
            ),
            const SizedBox(height: 16),
          ],

          // One-Time Code Field
          TextFormField(
            key: const Key('join_code_field'),
            controller: _codeController,
            style: TextStyle(
              color: tokens.textPrimary,
              letterSpacing: 1.5,
              fontWeight: FontWeight.w700,
            ),
            decoration: _inputDecoration(
              tokens: tokens,
              activeAccent: activeAccent,
              label: 'Staff Onboarding Code',
              hint: '6-digit code (valid for 5 mins)',
              helper: 'Staff codes auto-reset every 5 minutes',
              icon: Icons.password_outlined,
            ),
            validator: (val) => (val == null || val.trim().isEmpty)
                ? 'Please enter your code'
                : null,
          ),
          const SizedBox(height: 16),

          // Full Name Field
          TextFormField(
            key: const Key('join_name_field'),
            controller: _nameController,
            style: TextStyle(color: tokens.textPrimary),
            decoration: _inputDecoration(
              tokens: tokens,
              activeAccent: activeAccent,
              label: 'Full Name',
              icon: Icons.person_outline,
            ),
            validator: (val) => (val == null || val.trim().isEmpty)
                ? 'Please enter your name'
                : null,
          ),
          const SizedBox(height: 16),

          // Email Field
          TextFormField(
            key: const Key('join_email_field'),
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            style: TextStyle(color: tokens.textPrimary),
            decoration: _inputDecoration(
              tokens: tokens,
              activeAccent: activeAccent,
              label: 'Company Email',
              hint: 'name@company.com',
              icon: Icons.email_outlined,
            ),
            validator: (val) {
              if (val == null || val.trim().isEmpty) {
                return 'Please enter your email';
              }
              if (!val.contains('@')) return 'Please enter a valid email';
              return null;
            },
          ),
          const SizedBox(height: 16),

          // Password Field
          TextFormField(
            key: const Key('join_password_field'),
            controller: _passwordController,
            obscureText: !_isPasswordVisible,
            style: TextStyle(color: tokens.textPrimary),
            decoration: _inputDecoration(
              tokens: tokens,
              activeAccent: activeAccent,
              label: 'Create Password',
              icon: Icons.lock_outline,
              suffixIcon: IconButton(
                icon: Icon(
                  _isPasswordVisible
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  color: tokens.textMuted,
                ),
                onPressed: () {
                  setState(() {
                    _isPasswordVisible = !_isPasswordVisible;
                  });
                },
              ),
            ),
            validator: (val) {
              if (val == null || val.length < 6) {
                return 'Password must be at least 6 characters';
              }
              return null;
            },
          ),
          const SizedBox(height: 24),

          // Join Company Button
          SizedBox(
            height: 52,
            child: ElevatedButton(
              key: const Key('join_submit_button'),
              onPressed: _isSubmitting ? null : _handleJoin,
              style: ElevatedButton.styleFrom(
                backgroundColor: activeAccent,
                foregroundColor: onAccent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
              child: _isSubmitting
                  ? SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: onAccent,
                      ),
                    )
                  : const Text(
                      'Activate & Join Workspace',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );

    return Scaffold(
      backgroundColor: tokens.canvas,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: tokens.textPrimary),
          onPressed: () {
            if (kIsWeb) {
              context.go('/sign-in');
            } else {
              context.go('/welcome');
            }
          },
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: isWide ? 32 : 20,
              vertical: 16,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: isWide
                  ? Container(
                      padding: const EdgeInsets.all(36),
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
                      child: formBody,
                    )
                  : formBody,
            ),
          ),
        ),
      ),
    );
  }
}
