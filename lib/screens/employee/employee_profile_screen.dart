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
  final _titleController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    // Fetch authProvider before any async operations to avoid use_build_context_synchronously warning
    final authProvider = provider.Provider.of<AuthProvider>(context, listen: false);

    setState(() => _isLoading = true);

    try {
      final email = _emailController.text.trim().toLowerCase();

      // 1. Query Firms/{firmId}/PreApprovedStaff where email matches
      final preApprovedQuery = await FirebaseFirestore.instance
          .collection('Firms')
          .doc(widget.firmId)
          .collection('PreApprovedStaff')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      final bool isPreApproved = preApprovedQuery.docs.isNotEmpty;
      final String? preApprovedDocId = isPreApproved ? preApprovedQuery.docs.first.id : null;

      // 2. Sign in anonymously via AuthProvider (wrapped in ChangeNotifierProvider)
      final user = await authProvider.signInAnonymously();

      if (user == null) {
        throw Exception('Failed to sign in anonymously.');
      }

      final uid = user.uid;

      // 3. Perform Firestore batch writes atomically
      await DBService.instance.registerEmployeeProfile(
        uid: uid,
        firmId: widget.firmId,
        name: _nameController.text.trim(),
        email: email,
        jobTitle: _titleController.text.trim(),
        isApproved: isPreApproved,
        preApprovedDocId: preApprovedDocId,
      );

      // 4. Route based on approval status
      if (mounted) {
        if (isPreApproved) {
          SnackbarService().showSnackbar('Pre-approval matched! Welcome to your workspace.');
          context.go('/');
        } else {
          context.go('/pending-approval?firmId=${widget.firmId}&uid=$uid');
        }
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
                    if (logoUrl != null) ...[
                      Center(
                        child: Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                            image: DecorationImage(
                              image: NetworkImage(logoUrl),
                              fit: BoxFit.contain,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
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
                      'Please enter your details below to join your team.',
                      style: TextStyle(color: Colors.grey[500]),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Full Name',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person),
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
                    prefixIcon: Icon(Icons.email),
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
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'Job Title (Optional)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.badge),
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _isLoading ? null : _submitForm,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Request Access'),
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
