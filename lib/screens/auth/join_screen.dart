import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../models/firm.dart';
import '../../services/db_service.dart';
import '../../providers/auth_provider.dart' as app_auth;

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
    if (hexString == null) return const Color.fromRGBO(41, 116, 188, 1);
    try {
      final clean = hexString.replaceAll('#', '');
      return Color(int.parse('FF$clean', radix: 16));
    } catch (_) {
      return const Color.fromRGBO(41, 116, 188, 1);
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
      if (user != null && !user.isAnonymous && user.email?.toLowerCase() == email) {
        // Already signed in with this email
      } else {
        if (user != null && user.isAnonymous) {
          await FirebaseAuth.instance.signOut();
        }

        try {
          final credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
            email: email,
            password: password,
          );
          user = credential.user;
          await user?.updateDisplayName(name);
        } on FirebaseAuthException catch (e) {
          if (e.code == 'email-already-in-use') {
            // Sign in with existing credentials to attach membership
            try {
              final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
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
      if (mounted) {
        final authProvider = Provider.of<app_auth.AuthProvider>(context, listen: false);
        await authProvider.refreshUserProfile();

        // 4. Onboarding complete — navigate straight to Home!
        context.go('/home');
      }
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

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final primaryColor = _parseFirmColor(_loadedFirm?.primaryColor);

    return Scaffold(
      backgroundColor: const Color.fromRGBO(24, 23, 23, 1),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
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
            child: Container(
              constraints: const BoxConstraints(maxWidth: 480),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Company Branding Header
                    Center(
                      child: Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: primaryColor.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: primaryColor.withOpacity(0.4), width: 1.5),
                        ),
                        child: Icon(
                          Icons.apartment_rounded,
                          size: 36,
                          color: primaryColor,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    Text(
                      _loadedFirm != null
                          ? 'Join ${_loadedFirm!.name}'
                          : 'Join Your Company Workspace',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _loadedFirm != null
                          ? 'Enter your pre-authorized code to activate access'
                          : 'Enter your company ID and one-time code',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: Colors.grey[400]),
                    ),
                    const SizedBox(height: 24),

                    // Error Banner
                    if (_errorMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red[900]?.withOpacity(0.25),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.red[700]!),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline, color: Colors.redAccent, size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: const TextStyle(color: Colors.redAccent, fontSize: 13),
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
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Firm ID',
                          labelStyle: TextStyle(color: Colors.grey[400]),
                          hintText: 'e.g. firm_xyz123',
                          hintStyle: TextStyle(color: Colors.grey[600]),
                          prefixIcon: const Icon(Icons.vpn_key_outlined, color: Colors.grey),
                          suffixIcon: _isLoadingFirm
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: Center(
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  ),
                                )
                              : IconButton(
                                  icon: const Icon(Icons.arrow_forward, color: Colors.white),
                                  onPressed: () => _fetchFirmDetails(_firmIdController.text),
                                ),
                          filled: true,
                          fillColor: const Color.fromRGBO(34, 33, 33, 1),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        validator: (val) =>
                            (val == null || val.trim().isEmpty) ? 'Please enter your Firm ID' : null,
                      ),
                      const SizedBox(height: 16),
                    ],

                    // One-Time Code Field
                    TextFormField(
                      key: const Key('join_code_field'),
                      controller: _codeController,
                      style: const TextStyle(color: Colors.white, letterSpacing: 1.5, fontWeight: FontWeight.bold),
                      decoration: InputDecoration(
                        labelText: 'Staff Onboarding Code',
                        labelStyle: TextStyle(color: Colors.grey[400]),
                        hintText: '6-digit code (valid for 5 mins)',
                        hintStyle: TextStyle(color: Colors.grey[600], letterSpacing: 0),
                        helperText: 'Staff codes auto-reset every 5 minutes',
                        helperStyle: TextStyle(color: Colors.grey[500], fontSize: 11),
                        prefixIcon: const Icon(Icons.password_outlined, color: Colors.grey),
                        filled: true,
                        fillColor: const Color.fromRGBO(34, 33, 33, 1),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      validator: (val) =>
                          (val == null || val.trim().isEmpty) ? 'Please enter your code' : null,
                    ),
                    const SizedBox(height: 16),

                    // Full Name Field
                    TextFormField(
                      key: const Key('join_name_field'),
                      controller: _nameController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Full Name',
                        labelStyle: TextStyle(color: Colors.grey[400]),
                        prefixIcon: const Icon(Icons.person_outline, color: Colors.grey),
                        filled: true,
                        fillColor: const Color.fromRGBO(34, 33, 33, 1),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      validator: (val) =>
                          (val == null || val.trim().isEmpty) ? 'Please enter your name' : null,
                    ),
                    const SizedBox(height: 16),

                    // Email Field
                    TextFormField(
                      key: const Key('join_email_field'),
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Company Email',
                        labelStyle: TextStyle(color: Colors.grey[400]),
                        hintText: 'name@company.com',
                        hintStyle: TextStyle(color: Colors.grey[600]),
                        prefixIcon: const Icon(Icons.email_outlined, color: Colors.grey),
                        filled: true,
                        fillColor: const Color.fromRGBO(34, 33, 33, 1),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) return 'Please enter your email';
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
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Create Password',
                        labelStyle: TextStyle(color: Colors.grey[400]),
                        prefixIcon: const Icon(Icons.lock_outline, color: Colors.grey),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                            color: Colors.grey,
                          ),
                          onPressed: () {
                            setState(() {
                              _isPasswordVisible = !_isPasswordVisible;
                            });
                          },
                        ),
                        filled: true,
                        fillColor: const Color.fromRGBO(34, 33, 33, 1),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
                          backgroundColor: primaryColor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 0,
                        ),
                        child: _isSubmitting
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'Activate & Join Workspace',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
