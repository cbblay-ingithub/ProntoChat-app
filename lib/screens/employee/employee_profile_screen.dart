import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:provider/provider.dart' as provider;
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../services/db_service.dart';
import '../../services/snackbar_service.dart';
import '../../models/firm.dart';

class EmployeeProfileScreen extends ConsumerStatefulWidget {
  final String firmId;

  const EmployeeProfileScreen({
    super.key,
    required this.firmId,
  });

  @override
  ConsumerState<EmployeeProfileScreen> createState() => _EmployeeProfileScreenState();
}

class _EmployeeProfileScreenState extends ConsumerState<EmployeeProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _titleController = TextEditingController();
  bool _isLoading = false;
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    final authProvider = provider.Provider.of<AuthProvider>(context, listen: false);
    setState(() => _isLoading = true);

    try {
      final email = _emailController.text.trim().toLowerCase();
      final password = _passwordController.text;
      final name = _nameController.text.trim();

      // 1. Ensure user has a durable Firebase Auth account
      User? user = FirebaseAuth.instance.currentUser;

      // If user is already signed in with a real email account matching the input
      if (user != null && !user.isAnonymous && user.email?.toLowerCase() == email) {
        // Use existing authenticated user
      } else {
        // If there was an anonymous session, sign out first so we create a clean account
        if (user != null && user.isAnonymous) {
          await FirebaseAuth.instance.signOut();
        }

        try {
          final credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
            email: email,
            password: password,
          );
          user = credential.user;
          if (user != null) {
            await user.updateDisplayName(name);
          }
        } on FirebaseAuthException catch (e) {
          if (e.code == 'email-already-in-use') {
            if (mounted) {
              setState(() => _isLoading = false);
              _showExistingAccountDialog(email);
            }
            return;
          } else {
            rethrow;
          }
        }
      }

      if (user == null) {
        throw Exception('Failed to authenticate user for onboarding.');
      }

      final uid = user.uid;

      // 2. Check if user is already an approved member of this firm
      final existingMembership = await FirebaseFirestore.instance
          .collection('Memberships')
          .doc(uid)
          .get();

      if (existingMembership.exists) {
        final data = existingMembership.data();
        final currentFirmId = data?['firmId'] as String?;
        final currentStatus = data?['status'] as String?;

        if (currentFirmId == widget.firmId &&
            (currentStatus == 'approved' || currentStatus == 'active')) {
          if (mounted) {
            SnackbarService().showSnackbar('You are already an approved member of this workspace!');
            context.go('/home');
          }
          return;
        }
      }

      // 3. Check if email is in PreApprovedStaff (direct doc lookup with query fallback)
      bool isPreApproved = false;
      String? preApprovedDocId;
      try {
        final preApprovedDoc = await FirebaseFirestore.instance
            .collection('Firms')
            .doc(widget.firmId)
            .collection('PreApprovedStaff')
            .doc(email)
            .get();

        if (preApprovedDoc.exists) {
          isPreApproved = true;
          preApprovedDocId = preApprovedDoc.id;
        } else {
          final preApprovedQuery = await FirebaseFirestore.instance
              .collection('Firms')
              .doc(widget.firmId)
              .collection('PreApprovedStaff')
              .where('email', isEqualTo: email)
              .limit(1)
              .get();
          if (preApprovedQuery.docs.isNotEmpty) {
            isPreApproved = true;
            preApprovedDocId = preApprovedQuery.docs.first.id;
          }
        }
      } catch (e) {
        debugPrint('⚠️ PreApprovedStaff check error: $e');
      }

      // 4. Perform Firestore batch writes atomically (membership starts as pending approval)
      await DBService.instance.registerEmployeeProfile(
        uid: uid,
        firmId: widget.firmId,
        name: name,
        email: email,
        jobTitle: _titleController.text.trim(),
        isApproved: false,
        preApprovedDocId: preApprovedDocId,
      );

      // Force refresh AuthProvider profile cache
      await authProvider.refreshUserProfile();

      // 5. Route to PendingApprovalScreen to await admin review
      if (mounted) {
        SnackbarService().showSnackbar('Access request submitted! Waiting for admin approval.');
        context.go('/pending-approval?firmId=${widget.firmId}&uid=$uid');
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        SnackbarService().showSnackbar('Auth error: ${e.message}', isError: true);
      }
    } catch (e) {
      if (mounted) {
        SnackbarService().showSnackbar('Error: ${e.toString()}', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showExistingAccountDialog(String email) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: const Color.fromRGBO(34, 33, 33, 1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Account Already Exists',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'An account with $email is already registered. If you are already onboarded, please log in with your password to access your workspace.',
          style: TextStyle(color: Colors.grey[300], fontSize: 14, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color.fromRGBO(41, 116, 188, 1),
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(dialogCtx);
              context.go('/login');
            },
            child: const Text('Go to Login'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Complete Your Profile'),
        centerTitle: true,
      ),
      body: FutureBuilder<Firm>(
        future: DBService.instance.getFirm(widget.firmId),
        builder: (context, snapshot) {
          final firm = snapshot.data;
          final firmName = firm?.name ?? 'your workspace';
          final logoUrl = firm?.logoUrl;

          return Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (logoUrl != null && logoUrl.isNotEmpty) ...[
                      Center(
                        child: Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: Image.network(
                            logoUrl,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) => const Icon(
                              Icons.business,
                              size: 40,
                              color: Color.fromRGBO(41, 116, 188, 1),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    Text(
                      'Welcome to $firmName',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Create your employee account to join your workspace.',
                      style: TextStyle(color: Colors.grey[500]),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 28),
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Full Name',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Full Name is required';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Work Email',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Work Email is required';
                        }
                        if (!value.contains('@') || !value.contains('.')) {
                          return 'Please enter a valid email';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: !_isPasswordVisible,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                          ),
                          onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Password is required';
                        }
                        if (value.length < 6) {
                          return 'Password must be at least 6 characters';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _confirmPasswordController,
                      obscureText: !_isConfirmPasswordVisible,
                      decoration: InputDecoration(
                        labelText: 'Confirm Password',
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.lock_reset_outlined),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _isConfirmPasswordVisible ? Icons.visibility : Icons.visibility_off,
                          ),
                          onPressed: () => setState(
                            () => _isConfirmPasswordVisible = !_isConfirmPasswordVisible,
                          ),
                        ),
                      ),
                      validator: (value) {
                        if (value != _passwordController.text) {
                          return 'Passwords do not match';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _titleController,
                      decoration: const InputDecoration(
                        labelText: 'Job Title (Optional)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.badge_outlined),
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _submitForm,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: const Color.fromRGBO(41, 116, 188, 1),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Request Access',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Already onboarded? ',
                          style: TextStyle(color: Colors.grey[400]),
                        ),
                        GestureDetector(
                          onTap: () => context.go('/login'),
                          child: const Text(
                            'Log In',
                            style: TextStyle(
                              color: Color.fromRGBO(41, 116, 188, 1),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
