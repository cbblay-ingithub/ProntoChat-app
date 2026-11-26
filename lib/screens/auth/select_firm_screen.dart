import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/firm.dart';
import '../../services/db_service.dart';
import '../../providers/firm/providers.dart';
import '../../theme/pc_tokens.dart';
import '../../widgets/common/pc_logo.dart';

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
    final tokens = context.pcTokens;

    return Scaffold(
      backgroundColor: tokens.canvas,
      appBar: AppBar(
        title: const Text('Select Workspace'),
        centerTitle: true,
        backgroundColor: tokens.surface,
        shape: Border(bottom: BorderSide(color: tokens.border)),
        actions: [
          IconButton(
            icon: Icon(Icons.logout, color: tokens.textSecondary),
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
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: _isLoading
                  ? Center(
                      child: CircularProgressIndicator(color: tokens.primary),
                    )
                  : _errorMessage != null
                      ? Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: tokens.urgentBg,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: tokens.urgentBorder),
                          ),
                          child: Text(
                            _errorMessage!,
                            style: TextStyle(color: tokens.urgentText),
                          ),
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Choose a Company Workspace',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: tokens.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'You have access to multiple organizations:',
                              style: TextStyle(
                                color: tokens.textSecondary,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 20),
                            Expanded(
                              child: ListView.separated(
                                itemCount: _firms.length,
                                separatorBuilder: (_, _) =>
                                    const SizedBox(height: 12),
                                itemBuilder: (context, index) {
                                  final firm = _firms[index];
                                  return Material(
                                    color: tokens.surface,
                                    borderRadius: BorderRadius.circular(14),
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(14),
                                      onTap: () => _selectFirm(firm),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 12,
                                        ),
                                        decoration: BoxDecoration(
                                          borderRadius:
                                              BorderRadius.circular(14),
                                          border:
                                              Border.all(color: tokens.border),
                                        ),
                                        child: Row(
                                          children: [
                                            PcLogo(
                                              logo: firm.logo,
                                              legacyUrl: firm.logoUrl,
                                              size: 42,
                                              borderRadius: 12,
                                              variant: MediaVariant.logoSm,
                                              firmName: firm.name,
                                              primaryColor: tokens.primary,
                                            ),
                                            const SizedBox(width: 14),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    firm.name,
                                                    style: TextStyle(
                                                      color: tokens.textPrimary,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      fontSize: 16,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 3),
                                                  Text(
                                                    'Plan: ${firm.plan.toUpperCase()} • ${firm.status}',
                                                    style: TextStyle(
                                                      color:
                                                          tokens.textSecondary,
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Icon(
                                              Icons.chevron_right_rounded,
                                              size: 20,
                                              color: tokens.textMuted,
                                            ),
                                          ],
                                        ),
                                      ),
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
      ),
    );
  }
}
