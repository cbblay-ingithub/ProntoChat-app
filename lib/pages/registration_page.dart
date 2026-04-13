import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import './login_page.dart';
import '../services/navigation_service.dart';
import '../services/db_service.dart';
import './animation_switch.dart';

class RegistrationPage extends StatefulWidget {
  const RegistrationPage({super.key});

  @override
  State<StatefulWidget> createState() => _RegPageState();
}

class _RegPageState extends State<RegistrationPage> {
  late double _deviceHeight;
  late double _deviceWidth;

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  bool _isLoading = false;
  
  // Password visibility toggles
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;

  // Firebase instances
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DBService _dbService = DBService.instance;

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
              SizedBox(height: _deviceHeight * 0.02),
              _animatedPictureWidget(),
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

  Widget _animatedPictureWidget() {
    final animSize = _deviceHeight * 0.17;
    return AnimatedOrbSwitcher(size: animSize);
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
      decoration: _inputDecoration("Full Name", Icons.person_outline, null),
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
      decoration: _inputDecoration("Email Address", Icons.email_outlined, null),
    );
  }

  Widget _passwordTextField() {
    return TextFormField(
      controller: _passwordController,
      obscureText: !_isPasswordVisible,
      autocorrect: false,
      style: const TextStyle(color: Colors.white),
      enabled: !_isLoading,
      validator: (input) {
        if (input == null || input.isEmpty) return 'Please enter your password';
        if (input.length < 6) return 'Password must be at least 6 characters';
        return null;
      },
      decoration: _inputDecoration("Password", Icons.lock_outline, IconButton(
        icon: Icon(
          _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
          color: Colors.grey,
        ),
        onPressed: _isLoading ? null : () {
          setState(() {
            _isPasswordVisible = !_isPasswordVisible;
          });
        },
      )),
    );
  }

  Widget _confirmPasswordTextField() {
    return TextFormField(
      controller: _confirmPasswordController,
      obscureText: !_isConfirmPasswordVisible,
      autocorrect: false,
      style: const TextStyle(color: Colors.white),
      enabled: !_isLoading,
      validator: (input) {
        if (input == null || input.isEmpty) return 'Please confirm your password';
        if (input != _passwordController.text) return 'Passwords do not match';
        return null;
      },
      decoration: _inputDecoration("Confirm Password", Icons.lock_outline, IconButton(
        icon: Icon(
          _isConfirmPasswordVisible ? Icons.visibility : Icons.visibility_off,
          color: Colors.grey,
        ),
        onPressed: _isLoading ? null : () {
          setState(() {
            _isConfirmPasswordVisible = !_isConfirmPasswordVisible;
          });
        },
      )),
    );
  }

  InputDecoration _inputDecoration(String hint, IconData icon, Widget? suffixIcon) {
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
      suffixIcon: suffixIcon,
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
      String name = _nameController.text.trim();
      String email = _emailController.text.trim();
      String password = _passwordController.text;
      
      setState(() => _isLoading = true);
      
      try {
        // 1. Create user in Firebase Authentication
        UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );
        
        String uid = userCredential.user!.uid;
        
        // 2. Update user profile with display name
        await userCredential.user!.updateDisplayName(name);
        
        // 3. Create user document in Firestore
        // Using a default avatar URL (you can replace with actual image upload later)
        String defaultAvatarUrl = 'https://ui-avatars.com/api/?background=2974BC&color=fff&name=${Uri.encodeComponent(name)}';
        
        await _dbService.createUserInDB(
          uid,
          name,
          email,
          defaultAvatarUrl,
        );
        
        // 4. Show success message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Registration successful! Please login.'),
              backgroundColor: Colors.green,
            ),
          );
          _navigateToLogin();
        }
      } on FirebaseAuthException catch (e) {
        String errorMessage;
        switch (e.code) {
          case 'email-already-in-use':
            errorMessage = 'This email is already registered. Please login instead.';
            break;
          case 'invalid-email':
            errorMessage = 'Please enter a valid email address.';
            break;
          case 'weak-password':
            errorMessage = 'Password is too weak. Please use a stronger password.';
            break;
          default:
            errorMessage = 'Registration failed: ${e.message}';
        }
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMessage),
              backgroundColor: Colors.red,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Registration failed: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
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