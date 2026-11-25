import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import './login_page.dart';
import '../services/db_service.dart';
import '../services/cloud_storage.dart';
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

  // Profile image — null means user hasn't picked one yet
  File? _selectedImage;
  final ImagePicker _imagePicker = ImagePicker();

  // Firebase + app service instances
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DBService _dbService = DBService.instance;
  final CloudStorageService _storageService = CloudStorageService.instance;

  // ─── Build ────────────────────────────────────────────────────────────────

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

              // Profile picture picker sits where the animated orb used to live.
              // The orb is still shown as the placeholder when no image is chosen.
              _profilePictureWidget(),

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

  // ─── Heading ──────────────────────────────────────────────────────────────

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

  // ─── Profile Picture Widget ───────────────────────────────────────────────

  /// Shows the animated orb as a placeholder. Once the user picks an image it
  /// switches to a circular preview of that image. A camera-badge in the corner
  /// makes the tap target obvious. Disabled while uploading.
  Widget _profilePictureWidget() {
    final double size = _deviceHeight * 0.17;

    return GestureDetector(
      onTap: _isLoading ? null : _showImageSourceSheet,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // ── Main circle ──────────────────────────────────────────────────
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              // Subtle blue ring so the circle reads as tappable
              border: Border.all(
                color: const Color.fromRGBO(41, 116, 188, 0.6),
                width: 2.5,
              ),
            ),
            child: ClipOval(
              child: _selectedImage != null
                  // User has chosen a photo — show it
                  ? Image.file(
                      _selectedImage!,
                      fit: BoxFit.cover,
                      width: size,
                      height: size,
                    )
                  // No photo yet — keep the existing animated orb
                  : AnimatedOrbSwitcher(size: size),
            ),
          ),

          // ── Camera badge ─────────────────────────────────────────────────
          Positioned(
            bottom: 4,
            right: 4,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color.fromRGBO(41, 116, 188, 1),
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color.fromRGBO(28, 27, 27, 1),
                  width: 2,
                ),
              ),
              child: Icon(
                _selectedImage != null ? Icons.edit : Icons.camera_alt,
                color: Colors.white,
                size: 16,
              ),
            ),
          ),

          // ── "Optional" label ──────────────────────────────────────────────
          if (_selectedImage == null)
            Positioned(
              bottom: -20,
              child: Text(
                "Tap to add photo  •  optional",
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 11,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ─── Image Source Bottom-Sheet ────────────────────────────────────────────

  /// Lets the user choose between their gallery and the camera.
  void _showImageSourceSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color.fromRGBO(38, 37, 37, 1),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey[600],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color.fromRGBO(41, 116, 188, 0.15),
                  child: Icon(Icons.photo_library_outlined,
                      color: Color.fromRGBO(41, 116, 188, 1)),
                ),
                title: const Text("Choose from Gallery",
                    style: TextStyle(color: Colors.white)),
                subtitle: Text("Pick an existing photo",
                    style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery);
                },
              ),

              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color.fromRGBO(41, 116, 188, 0.15),
                  child: Icon(Icons.camera_alt_outlined,
                      color: Color.fromRGBO(41, 116, 188, 1)),
                ),
                title: const Text("Take a Photo",
                    style: TextStyle(color: Colors.white)),
                subtitle: Text("Use your camera right now",
                    style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera);
                },
              ),

              // Only show "Remove" when a photo has already been selected
              if (_selectedImage != null)
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.red.withOpacity(0.12),
                    child:
                        const Icon(Icons.delete_outline, color: Colors.redAccent),
                  ),
                  title: const Text("Remove Photo",
                      style: TextStyle(color: Colors.redAccent)),
                  onTap: () {
                    Navigator.pop(context);
                    setState(() => _selectedImage = null);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Image Picker Logic ───────────────────────────────────────────────────

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? picked = await _imagePicker.pickImage(
        source: source,
        imageQuality: 75,   // Reduces file size ~60–70 % with barely visible quality loss
        maxWidth: 512,       // Profile pictures are displayed small — 512 px is plenty
        maxHeight: 512,
      );

      if (picked != null) {
        setState(() => _selectedImage = File(picked.path));
      }
    } catch (e) {
      // This typically happens when the user denies camera/gallery permissions.
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not access ${source == ImageSource.camera ? "camera" : "gallery"}: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ─── Form ─────────────────────────────────────────────────────────────────

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
        if (!input.contains('@') || !input.contains('.')) {
          return 'Please enter a valid email';
        }
        return null;
      },
      decoration:
          _inputDecoration("Email Address", Icons.email_outlined, null),
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
      decoration: _inputDecoration(
        "Password",
        Icons.lock_outline,
        IconButton(
          icon: Icon(
            _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
            color: Colors.grey,
          ),
          onPressed: _isLoading
              ? null
              : () => setState(() => _isPasswordVisible = !_isPasswordVisible),
        ),
      ),
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
      decoration: _inputDecoration(
        "Confirm Password",
        Icons.lock_outline,
        IconButton(
          icon: Icon(
            _isConfirmPasswordVisible
                ? Icons.visibility
                : Icons.visibility_off,
            color: Colors.grey,
          ),
          onPressed: _isLoading
              ? null
              : () => setState(() =>
                  _isConfirmPasswordVisible = !_isConfirmPasswordVisible),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(
      String hint, IconData icon, Widget? suffixIcon) {
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
        borderSide:
            const BorderSide(color: Color.fromRGBO(41, 116, 188, 1), width: 2),
      ),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      prefixIcon: Icon(icon, color: Colors.grey),
      suffixIcon: suffixIcon,
    );
  }

  // ─── Sign-Up Button ───────────────────────────────────────────────────────

  Widget _signUpButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _register,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color.fromRGBO(41, 116, 188, 1),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
            : const Text("Sign Up",
                style:
                    TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
      ),
    );
  }

  // ─── Login Link ───────────────────────────────────────────────────────────

  Widget _loginText() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text("Already have an account? ",
            style: TextStyle(color: Colors.grey[400], fontSize: 16)),
        GestureDetector(
          onTap: _isLoading ? null : _navigateToLogin,
          child: Text(
            "Login",
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

  // ─── Registration Logic ───────────────────────────────────────────────────

  void _register() async {
    if (!_formKey.currentState!.validate()) return;

    final String name = _nameController.text.trim();
    final String email = _emailController.text.trim();
    final String password = _passwordController.text;

    setState(() => _isLoading = true);

    try {
      // ── Step 1: Create the Firebase Auth account ──────────────────────────
      final UserCredential userCredential =
          await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final String uid = userCredential.user!.uid;

      // ── Step 2: Set display name in Firebase Auth ─────────────────────────
      await userCredential.user!.updateDisplayName(name);

      // ── Step 3: Resolve avatar URL ─────────────────────────────────────────
      //    • User picked a photo  → upload to Firebase Storage, use that URL.
      //    • User skipped         → generate an initials avatar via DiceBear
      //                             (no external dependency, just a URL).
      String avatarUrl;

      if (_selectedImage != null) {
        // Uploads to profile_images/<uid>.jpg and returns the download URL.
        // CloudStorageService already has this method wired up.
        avatarUrl = await _storageService.uploadUserImage(uid, _selectedImage!);
      } else {
        // DiceBear initials — clean, on-brand fallback. Swap the style slug
        // (e.g. "initials" → "pixel-art") to change the look app-wide later.
        avatarUrl =
            'https://api.dicebear.com/7.x/initials/png?seed=${Uri.encodeComponent(name)}&backgroundColor=2974BC&textColor=ffffff&radius=50&size=128';
      }

      // ── Step 4: Write user document to Firestore ──────────────────────────
      await _dbService.createUserInDB(uid, name, email, avatarUrl);

      // ── Step 5: Navigate to login ─────────────────────────────────────────
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Registration successful! Please login.'),
            backgroundColor: Colors.green,
          ),
        );
        _navigateToLogin();
      }

      // ─────────────────────────────────────────────────────────────────────
    } on FirebaseAuthException catch (e) {
      final String errorMessage = switch (e.code) {
        'email-already-in-use' =>
          'This email is already registered. Please login instead.',
        'invalid-email' => 'Please enter a valid email address.',
        'weak-password' =>
          'Password is too weak. Please use a stronger password.',
        _ => 'Registration failed: ${e.message}',
      };

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage), backgroundColor: Colors.red),
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
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _navigateToLogin() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
    );
  }

  // ─── Cleanup ──────────────────────────────────────────────────────────────

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }
}