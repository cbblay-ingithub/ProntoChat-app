import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../theme/pc_tokens.dart';

/// Single shared sign-in screen for both admins and employees.
/// User's role is determined strictly from their membership record after sign-in.
class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isPasswordVisible = false;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleSignIn() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    try {
      final success =
          await authProvider.loginUserWithEmailAndPassword(email, password);
      if (!mounted) return;
      if (!success) {
        setState(() {
          _errorMessage =
              authProvider.errorMessage ?? 'Invalid email or password.';
        });
      } else {
        context.go('/splash');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Sign in failed: ${e.toString()}';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.pcTokens;
    final width = MediaQuery.sizeOf(context).width;
    final isWide = !PcBreakpoints.isCompact(width);

    final formBody = Form(
      key: _formKey,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Brand Icon
          Center(
            child: Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: tokens.primarySoft,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: tokens.primaryBorder),
              ),
              child: Icon(
                Icons.lock_outline_rounded,
                size: 30,
                color: tokens.primary,
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Title
          Text(
            'Sign In',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: tokens.textPrimary,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Access your ProntoChat workspace',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: tokens.textSecondary),
          ),
          const SizedBox(height: 28),

          // Error Message Banner
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
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 20),
          ],

          // Email Field
          TextFormField(
            key: const Key('sign_in_email_field'),
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            style: TextStyle(color: tokens.textPrimary),
            decoration: InputDecoration(
              labelText: 'Email Address',
              labelStyle: TextStyle(color: tokens.textSecondary),
              prefixIcon: Icon(
                Icons.email_outlined,
                color: tokens.textMuted,
              ),
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
                borderSide: BorderSide(color: tokens.primary, width: 1.6),
              ),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter your email';
              }
              if (!value.contains('@')) {
                return 'Please enter a valid email';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          // Password Field
          TextFormField(
            key: const Key('sign_in_password_field'),
            controller: _passwordController,
            obscureText: !_isPasswordVisible,
            style: TextStyle(color: tokens.textPrimary),
            onFieldSubmitted: (_) => _isLoading ? null : _handleSignIn(),
            decoration: InputDecoration(
              labelText: 'Password',
              labelStyle: TextStyle(color: tokens.textSecondary),
              prefixIcon: Icon(
                Icons.lock_outline,
                color: tokens.textMuted,
              ),
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
                borderSide: BorderSide(color: tokens.primary, width: 1.6),
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter your password';
              }
              return null;
            },
          ),
          const SizedBox(height: 24),

          // Sign In Button
          SizedBox(
            height: 50,
            child: ElevatedButton(
              key: const Key('sign_in_submit_button'),
              onPressed: _isLoading ? null : _handleSignIn,
              style: ElevatedButton.styleFrom(
                backgroundColor: tokens.primary,
                foregroundColor: tokens.onPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: _isLoading
                  ? SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: tokens.onPrimary,
                      ),
                    )
                  : const Text(
                      'Sign In',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
            ),
          ),

          // Web Only: Register Your Firm Link
          if (kIsWeb) ...[
            const SizedBox(height: 24),
            Wrap(
              alignment: WrapAlignment.center,
              children: [
                Text(
                  'Need a corporate workspace? ',
                  style: TextStyle(color: tokens.textSecondary, fontSize: 13.5),
                ),
                GestureDetector(
                  onTap: () => context.go('/register-firm'),
                  child: Text(
                    'Register your firm',
                    style: TextStyle(
                      color: tokens.primary,
                      fontWeight: FontWeight.w700,
                      fontSize: 13.5,
                    ),
                  ),
                ),
              ],
            ),
          ],

          // Mobile Only: Back to Welcome / Join Link
          if (!kIsWeb) ...[
            const SizedBox(height: 18),
            TextButton(
              onPressed: () => context.go('/join'),
              child: Text(
                'Have an invitation code? Join company',
                style: TextStyle(
                  color: tokens.primary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
    );

    return Scaffold(
      backgroundColor: tokens.canvas,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: (!kIsWeb && Navigator.of(context).canPop())
            ? IconButton(
                icon: Icon(Icons.arrow_back, color: tokens.textPrimary),
                onPressed: () => context.go('/welcome'),
              )
            : null,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: isWide ? 32 : 20,
              vertical: 24,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
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
