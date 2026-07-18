import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../services/csv_upload_service.dart';
import '../services/snackbar_service.dart';

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
  bool _isLoading = false;
  bool _isUploading = false;

  Future<void> _handlePickCsv() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final staffList = await CsvUploadService.instance.pickAndParseCsv();
      setState(() {
        _parsedStaff = staffList;
      });
      if (staffList.isNotEmpty) {
        SnackbarService().showSnackbar('Loaded ${staffList.length} staff records from CSV.');
      } else {
        SnackbarService().showSnackbar('CSV import was cancelled or file was empty.');
      }
    } catch (e) {
      SnackbarService().showSnackbar('Error parsing CSV: ${e.toString()}', isError: true);
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
    });

    try {
      await CsvUploadService.instance.uploadPreApprovedStaff(widget.firmId, _parsedStaff);
      SnackbarService().showSnackbar('Successfully pre-approved ${_parsedStaff.length} employees!');
      setState(() {
        _parsedStaff = [];
      });
    } catch (e) {
      SnackbarService().showSnackbar('Upload failed: ${e.toString()}', isError: true);
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
                            onPressed: () => setState(() => _parsedStaff = []),
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
                                : Text('Confirm & Import ${_parsedStaff.length} Employees'),
                          ),
                        ],
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                if (_parsedStaff.isEmpty) ...[
                  Text(
                    'Upload a CSV file containing your existing staff list. Bypasses manual onboarding approval queues.',
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
                          'Name,Email,JobTitle\nJohn Doe,john.doe@company.com,Senior Engineer\nJane Smith,jane.smith@company.com,Product Manager',
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
                  const SizedBox(height: 8),
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
                          DataColumn(label: Text('Email', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Job Title', style: TextStyle(fontWeight: FontWeight.bold))),
                        ],
                        rows: _parsedStaff.map((staff) {
                          return DataRow(
                            cells: [
                              DataCell(Text(staff['name'] ?? '')),
                              DataCell(Text(staff['email'] ?? '')),
                              DataCell(Text(staff['jobTitle'] ?? '')),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
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
