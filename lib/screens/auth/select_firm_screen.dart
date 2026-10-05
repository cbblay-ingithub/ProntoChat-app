import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/firm.dart';
import '../../services/db_service.dart';
import '../../providers/firm/providers.dart';

/// Screen displayed when a user belongs to more than one firm, allowing workspace selection.
class SelectFirmScreen extends ConsumerStatefulWidget {
  const SelectFirmScreen({super.key});

  @override
  ConsumerState<SelectFirmScreen> createState() => _SelectFirmScreenState();
}

class _SelectFirmScreenState extends ConsumerState<SelectFirmScreen> {
  List<Firm> _firms = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadUserFirms();
  }

  Future<void> _loadUserFirms() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      if (mounted) context.go('/sign-in');
      return;
    }

    try {
      final firms = await DBService.instance.getUserFirms(uid).first;
      if (mounted) {
        setState(() {
          _firms = firms;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load workspaces: $e';
          _isLoading = false;
        });
      }
    }
  }

  void _selectFirm(Firm firm) {
    ref.read(firmNotifierProvider.notifier).loadFirm(firm.firmId);
    context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromRGBO(24, 23, 23, 1),
      appBar: AppBar(
        title: const Text('Select Workspace'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign Out',
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (context.mounted) {
                context.go('/sign-in');
              }
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 520),
            padding: const EdgeInsets.all(24.0),
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                    ? Text(_errorMessage!, style: const TextStyle(color: Colors.redAccent))
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'Choose a Company Workspace',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'You have access to multiple organizations:',
                            style: TextStyle(color: Colors.grey[400], fontSize: 14),
                          ),
                          const SizedBox(height: 24),
                          Expanded(
                            child: ListView.separated(
                              itemCount: _firms.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 12),
                              itemBuilder: (context, index) {
                                final firm = _firms[index];
                                return Card(
                                  color: const Color.fromRGBO(34, 33, 33, 1),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    side: BorderSide(color: Colors.grey[800]!),
                                  ),
                                  child: ListTile(
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 10,
                                    ),
                                    leading: CircleAvatar(
                                      backgroundColor: const Color.fromRGBO(41, 116, 188, 1),
                                      child: Text(
                                        firm.name.isNotEmpty ? firm.name[0].toUpperCase() : 'F',
                                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                    title: Text(
                                      firm.name,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    subtitle: Text(
                                      'Plan: ${firm.plan.toUpperCase()} • ${firm.status}',
                                      style: TextStyle(color: Colors.grey[400], fontSize: 12),
                                    ),
                                    trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                                    onTap: () => _selectFirm(firm),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
          ),
        ),
      ),
    );
  }
}
