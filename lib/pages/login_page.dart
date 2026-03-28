import 'package:flutter/material.dart';
import 'package:pronto_chat/providers/auth_provider.dart';
import '../services/snackbar_service.dart';

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

  // Form key for validation
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  
  // Text controllers for email and password fields
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  // Loading state for button
  bool _isLoading = false;
  
  // Auth provider instance
  final AuthProvider _authProvider = AuthProvider.instance;
  
  // Snackbar service instance
  final SnackbarService _snackbarService = SnackbarService();

  @override
  Widget build(BuildContext context) {
    _deviceHeight = MediaQuery.of(context).size.height;
    _deviceWidth = MediaQuery.of(context).size.width;

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
              SizedBox(height: _deviceHeight * 0.04),
              _inputForm(),
              SizedBox(height: _deviceHeight * 0.06),
              _loginButton(),
              SizedBox(height: _deviceHeight * 0.05),
              _registerText(),
            ],
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
      enabled: !_isLoading, // Disable when loading
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
      obscureText: true,
      autocorrect: false,
      style: const TextStyle(color: Colors.white),
      enabled: !_isLoading, // Disable when loading
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
          icon: const Icon(Icons.visibility_outlined, color: Colors.grey),
          onPressed: _isLoading ? null : () {
            // TODO: Add password visibility toggle
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
        onPressed: _isLoading ? null : _login, // Disable button when loading
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color.fromRGBO(41, 116, 188, 1),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
          // Add disabled style
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

  /// Builds the register text widget
  Widget _registerText() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          "Don't have an account? ",
          style: TextStyle(color: Colors.grey[400], fontSize: 16),
        ),
        GestureDetector(
          onTap: _isLoading ? null : () {
            // TODO: Navigate to registration page
          },
          child: Text(
            "Register",
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
      
      // Attempt login
      bool success = await _authProvider.loginUserWithEmailAndPassword(
        _emailController.text.trim(),
        _passwordController.text,
      );
      
      // Reset loading state
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
      
      // Navigate on success
      if (success && mounted) {
        // TODO: Navigate to home screen
        // Navigator.pushReplacementNamed(context, '/home');
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