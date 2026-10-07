import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../services/csv_upload_service.dart';
import '../services/snackbar_service.dart';
import '../services/db_service.dart';

class BulkOnboardingView extends StatefulWidget {
  final String firmId;
  final Color primaryColor;

  const BulkOnboardingView({
    super.key,
    required this.firmId,
    required this.primaryColor,
  });

  @override
  State<BulkOnboardingView> createState() => _BulkOnboardingViewState();
}

class _BulkOnboardingViewState extends State<BulkOnboardingView> {
  List<Map<String, dynamic>> _parsedStaff = [];
  List<String> _missingDepartments = [];
  bool _isLoading = false;
  bool _isUploading = false;
  String? _errorMessage;

  Future<void> _handlePickCsv() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _missingDepartments = [];
    });

    try {
      final staffList = await CsvUploadService.instance.pickAndParseCsv();
      if (!mounted) return;

      // Identify missing departments by checking existing departments in Firestore
      final deptsSnapshot = await FirebaseFirestore.instance
          .collection('Firms')
          .doc(widget.firmId)
          .collection('departments')
          .get();

      final existingDeptNames = deptsSnapshot.docs
          .map((d) => (d.data()['name'] as String? ?? '').toLowerCase().trim())
          .toSet();

      final missing = <String>{};
      for (final s in staffList) {
        final dept = (s['department'] as String?)?.trim() ?? '';
        if (dept.isNotEmpty && !existingDeptNames.contains(dept.toLowerCase())) {
          missing.add(dept);
        }
      }

      setState(() {
        _parsedStaff = staffList;
        _missingDepartments = missing.toList();
      });

      if (staffList.isNotEmpty) {
        SnackbarService().showSnackbar('Loaded ${staffList.length} staff records from CSV.');
      }
    } catch (e) {
      final msg = e.toString().replaceFirst('Exception: ', '');
      if (mounted) {
        setState(() {
          _errorMessage = msg;
        });
      }
      SnackbarService().showSnackbar(msg, isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleConfirmImport() async {
    if (_parsedStaff.isEmpty) return;

    setState(() {
      _isUploading = true;
      _errorMessage = null;
    });

    try {
      // 1. Create missing departments if any
      final deptMap = <String, String>{};
      final deptsSnapshot = await FirebaseFirestore.instance
          .collection('Firms')
          .doc(widget.firmId)
          .collection('departments')
          .get();

      for (final doc in deptsSnapshot.docs) {
        final name = (doc.data()['name'] as String? ?? '').trim();
        deptMap[name] = doc.id;
      }

      for (final missingDept in _missingDepartments) {
        final newId = await DBService.instance.createDepartment(
          firmId: widget.firmId,
          name: missingDept,
        );
        deptMap[missingDept] = newId;
      }

      // 2. Upload PreApprovedStaff with mapped department IDs
      await CsvUploadService.instance.uploadPreApprovedStaff(
        widget.firmId,
        _parsedStaff,
        departmentNameToIdMap: deptMap,
      );

      if (!mounted) return;
      SnackbarService().showSnackbar('Successfully pre-approved ${_parsedStaff.length} employees!');
      setState(() {
        _parsedStaff = [];
        _missingDepartments = [];
      });
    } catch (e) {
      final msg = 'Upload failed: ${e.toString().replaceFirst("Exception: ", "")}';
      if (mounted) {
        setState(() {
          _errorMessage = msg;
        });
      }
      SnackbarService().showSnackbar(msg, isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // CSV Selection & Format Instructions
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Bulk Import Staff via CSV',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    if (_parsedStaff.isNotEmpty)
                      Row(
                        children: [
                          TextButton(
                            onPressed: () => setState(() {
                              _parsedStaff = [];
                              _missingDepartments = [];
                            }),
                            child: const Text('Cancel'),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: _isUploading ? null : _handleConfirmImport,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: widget.primaryColor,
                              foregroundColor: Colors.white,
                            ),
                            child: _isUploading
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : Text('Confirm & Import (${_parsedStaff.length})'),
                          ),
                        ],
                      ),
                  ],
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.redAccent.withValues(alpha: 0.5)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: Colors.redAccent, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (_missingDepartments.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline, color: Colors.amber, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Missing departments to create on confirmation: ${_missingDepartments.join(", ")}',
                            style: const TextStyle(color: Colors.amber, fontSize: 13, fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (_parsedStaff.isEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Upload a CSV file with columns: name, identifier (email), department, role. Pre-approves employees and assigns departments automatically.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[400],
                        ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.black26,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[800]!),
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Required CSV Format Header & Sample:',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'name,identifier,department,role\nAlice Johnson,alice@company.com,Engineering,lead\nBob Smith,bob@company.com,Marketing,employee',
                          style: TextStyle(fontFamily: 'monospace', fontSize: 12, color: Colors.blueGrey),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: ElevatedButton.icon(
                      onPressed: _isLoading ? null : _handlePickCsv,
                      icon: _isLoading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.file_upload),
                      label: const Text('Upload Staff CSV'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: widget.primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                ] else ...[
                  const SizedBox(height: 12),
                  // DataTable preview
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[800]!),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        headingRowColor: WidgetStateProperty.all(Colors.black26),
                        columns: const [
                          DataColumn(label: Text('Name', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Identifier', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Department', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Role', style: TextStyle(fontWeight: FontWeight.bold))),
                        ],
                        rows: _parsedStaff.map((staff) {
                          return DataRow(
                            cells: [
                              DataCell(Text(staff['name'] ?? '')),
                              DataCell(Text(staff['email'] ?? '')),
                              DataCell(Text(staff['department'] ?? '—')),
                              DataCell(Text((staff['role'] ?? 'employee').toString().toUpperCase())),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton(
                        onPressed: () => setState(() {
                          _parsedStaff = [];
                          _missingDepartments = [];
                          _errorMessage = null;
                        }),
                        child: const Text('Pick Different File'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: _isUploading ? null : _handleConfirmImport,
                        icon: _isUploading
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.cloud_upload),
                        label: Text('Confirm & Import (${_parsedStaff.length})'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: widget.primaryColor,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Live list of currently pre-approved staff
        SizedBox(
          height: 400,
          child: Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Currently Invited & Pre-Approved Staff',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('Firms')
                          .doc(widget.firmId)
                          .collection('PreApprovedStaff')
                          .orderBy('createdAt', descending: true)
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        }
                        if (snapshot.hasError) {
                          return Center(
                            child: Text(
                              'Error loading pre-approved staff: ${snapshot.error}',
                              style: const TextStyle(color: Colors.red),
                            ),
                          );
                        }

                        final docs = snapshot.data?.docs ?? [];
                        if (docs.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.mail_outline, size: 48, color: Colors.grey[600]),
                                const SizedBox(height: 8),
                                Text(
                                  'No pre-approved staff members yet.',
                                  style: TextStyle(color: Colors.grey[500]),
                                ),
                              ],
                            ),
                          );
                        }

                        return ListView.separated(
                          itemCount: docs.length,
                          separatorBuilder: (context, index) => const Divider(),
                          itemBuilder: (context, index) {
                            final data = docs[index].data() as Map<String, dynamic>;
                            final name = data['name'] ?? '';
                            final email = data['email'] ?? '';
                            final jobTitle = data['jobTitle'] ?? '';
                            final status = data['status'] ?? 'invited';

                            final isJoined = status == 'joined';

                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: CircleAvatar(
                                backgroundColor: isJoined
                                    ? Colors.green.withOpacity(0.1)
                                    : widget.primaryColor.withOpacity(0.1),
                                child: Icon(
                                  isJoined ? Icons.check : Icons.mail,
                                  color: isJoined ? Colors.green : widget.primaryColor,
                                ),
                              ),
                              title: Text(
                                name,
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                              subtitle: Text(
                                '${email.toString()} ${jobTitle.isNotEmpty ? "• $jobTitle" : ""}',
                                style: TextStyle(color: Colors.grey[400], fontSize: 13),
                              ),
                              trailing: Chip(
                                label: Text(
                                  status.toString().toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: isJoined ? Colors.green[300] : Colors.orange[300],
                                  ),
                                ),
                                backgroundColor: isJoined
                                    ? Colors.green.withOpacity(0.15)
                                    : Colors.orange.withOpacity(0.15),
                                padding: EdgeInsets.zero,
                                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
