import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart'; // Add this import
import 'package:pronto_chat/providers/auth_provider.dart';
import '../services/navigation_service.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<StatefulWidget> createState() {
    return LoginPageState();
  }
}

class LoginPageState extends State<LoginPage> {
  late double _deviceHeight;
  late double _deviceWidth;
  bool _isPasswordVisible = false;

  // Form key for validation
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  
  // Text controllers for email and password fields
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  // Loading state for button
  bool _isLoading = false;
  
  // Remove this line - we'll get AuthProvider from context instead
  // final AuthProvider _authProvider = AuthProvider.instance;
  
  @override
  Widget build(BuildContext context) {
    _deviceHeight = MediaQuery.of(context).size.height;
    _deviceWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: const Color.fromRGBO(28, 27, 27, 1),
      body: SafeArea(
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: _deviceHeight - MediaQuery.of(context).padding.top - MediaQuery.of(context).padding.bottom,
            ),
            child: IntrinsicHeight(
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: _deviceWidth * 0.08, vertical: 24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: <Widget>[
                    _headingWidget(),
                    SizedBox(height: _deviceHeight * 0.03),
                    _inputForm(),
                    SizedBox(height: _deviceHeight * 0.03),
                    _loginButton(),
                    const SizedBox(height: 24),
                    _joinFirmWidget(),
                    const SizedBox(height: 24),
                    _registerText(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Builds the heading widget with welcome text
  Widget _headingWidget() {
    return SizedBox(
      width: _deviceWidth,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Text(
            "Welcome Back!",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Please login to your account",
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

  /// Builds the input form with email and password fields
  Widget _inputForm() {
    return Container(
      child: Form(
        key: _formKey,
        child: Column(
          children: <Widget>[
            _emailTextField(),
            const SizedBox(height: 20),
            _passwordTextField(),
          ],
        ),
      ),
    );
  }

  /// Builds the email text field
  Widget _emailTextField() {
    return TextFormField(
      controller: _emailController,
      autocorrect: false,
      keyboardType: TextInputType.emailAddress,
      style: const TextStyle(color: Colors.white),
      enabled: !_isLoading,
      validator: (input) {
        if (input == null || input.isEmpty) {
          return 'Please enter your email';
        }
        if (!input.contains('@')) {
          return 'Please enter a valid email';
        }
        return null;
      },
      decoration: InputDecoration(
        hintText: "Email Address",
        hintStyle: const TextStyle(color: Colors.grey),
        filled: true,
        fillColor: Colors.grey[900]!.withOpacity(0.5),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: Color.fromRGBO(41, 116, 188, 1),
            width: 2,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        prefixIcon: const Icon(Icons.email_outlined, color: Colors.grey),
      ),
    );
  }

  /// Builds the password text field with visibility toggle
  Widget _passwordTextField() {
    return TextFormField(
      controller: _passwordController,
      obscureText: !_isPasswordVisible,
      autocorrect: false,
      style: const TextStyle(color: Colors.white),
      enabled: !_isLoading,
      validator: (input) {
        if (input == null || input.isEmpty) {
          return 'Please enter your password';
        }
        if (input.length < 6) {
          return 'Password must be at least 6 characters';
        }
        return null;
      },
      decoration: InputDecoration(
        hintText: "Password",
        hintStyle: const TextStyle(color: Colors.grey),
        filled: true,
        fillColor: Colors.grey[900]!.withOpacity(0.5),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: Color.fromRGBO(41, 116, 188, 1),
            width: 2,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        prefixIcon: const Icon(Icons.lock_outline, color: Colors.grey),
        suffixIcon: IconButton(
          icon: Icon(
            _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
            color: Colors.grey,
          ),
          onPressed: _isLoading ? null : () {
            setState(() {
              _isPasswordVisible = !_isPasswordVisible;
            });
          },
        ),
      ),
    );
  }

  /// Builds the login button with loading state
  Widget _loginButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _login,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color.fromRGBO(41, 116, 188, 1),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
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
            : const Text(
                "Login",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
      ),
    );
  }

  /// Builds the join firm button for employees with a manual code or link
  Widget _joinFirmWidget() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: Divider(color: Colors.grey[800], thickness: 1)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                "EMPLOYEE ONBOARDING",
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 11,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Expanded(child: Divider(color: Colors.grey[800], thickness: 1)),
          ],
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            key: const Key('join_firm_with_id_button'),
            onPressed: _isLoading ? null : _showJoinFirmDialog,
            icon: const Icon(Icons.apartment_outlined, size: 20),
            label: const Text(
              "Join with Firm ID or Code",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: Color.fromRGBO(41, 116, 188, 1), width: 1.5),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Opens dialog to manually input Firm ID or paste invite link
  void _showJoinFirmDialog() {
    final textController = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color.fromRGBO(34, 33, 33, 1),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: const [
              Icon(Icons.badge_outlined, color: Color.fromRGBO(41, 116, 188, 1)),
              SizedBox(width: 10),
              Text(
                'Join Your Firm',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Enter the Firm ID provided by your employer or paste your invitation link:',
                style: TextStyle(color: Colors.grey[300], fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 16),
              TextField(
                key: const Key('firm_id_dialog_text_field'),
                controller: textController,
                autofocus: true,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'e.g. firm_xyz123 or paste link',
                  hintStyle: TextStyle(color: Colors.grey[600]),
                  filled: true,
                  fillColor: const Color.fromRGBO(24, 23, 23, 1),
                  prefixIcon: const Icon(Icons.vpn_key_outlined, color: Colors.grey, size: 20),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.paste, color: Color.fromRGBO(41, 116, 188, 1), size: 20),
                    tooltip: 'Paste from clipboard',
                    onPressed: () async {
                      final data = await Clipboard.getData(Clipboard.kTextPlain);
                      if (data?.text != null && data!.text!.trim().isNotEmpty) {
                        textController.text = data.text!.trim();
                      }
                    },
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Colors.grey[700]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color.fromRGBO(41, 116, 188, 1), width: 1.8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text('Cancel', style: TextStyle(color: Colors.grey[400])),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color.fromRGBO(41, 116, 188, 1),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () {
                final raw = textController.text.trim();
                final extractedFirmId = _extractFirmId(raw);
                if (extractedFirmId.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter a valid Firm ID or invite link.')),
                  );
                  return;
                }
                Navigator.of(dialogContext).pop();
                NavigationService.instance.navigateTo('/employee-onboarding?firmId=$extractedFirmId');
              },
              child: const Text('Continue'),
            ),
          ],
        );
      },
    );
  }

  /// Extracts the firmId parameter from pasted URLs or returns the raw input
  String _extractFirmId(String input) {
    if (input.isEmpty) return '';
    final trimmed = input.trim();
    if (trimmed.contains('firmId=')) {
      final uri = Uri.tryParse(trimmed);
      if (uri != null && uri.queryParameters.containsKey('firmId') && uri.queryParameters['firmId']!.isNotEmpty) {
        return uri.queryParameters['firmId']!;
      }
      final match = RegExp(r'firmId=([^&]+)').firstMatch(trimmed);
      if (match != null && match.group(1) != null) {
        return match.group(1)!;
      }
    }
    return trimmed;
  }

  /// Builds the register text widget
  Widget _registerText() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          "New here? ",
          style: TextStyle(color: Colors.grey[400], fontSize: 16),
        ),
        GestureDetector(
          onTap: _isLoading ? null : () {
            NavigationService.instance.navigateToReplacement('/register-firm');
          },
          child: Text(
            "Register your firm",
            style: TextStyle(
              color: _isLoading 
                  ? Colors.grey[600] 
                  : const Color.fromRGBO(41, 116, 188, 1),
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  /// Handles the login process with button loading state
  void _login() async {
    if (_formKey.currentState!.validate()) {
      // Set loading state
      setState(() {
        _isLoading = true;
      });
      
      // Get AuthProvider from context instead of using instance
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      
      // Attempt login
      bool success = await authProvider.loginUserWithEmailAndPassword(
        _emailController.text.trim(),
        _passwordController.text,
      );
      
      // Reset loading state
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        if (success) {
          NavigationService.instance.navigateToReplacement('/');
        }
      }
    }
  }

  @override
  void dispose() {
    // Clean up controllers
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}