import 'package:flutter/material.dart';
import '../../models/firm.dart';
import '../../services/db_service.dart';
import '../convo_page.dart';

class EmployeeDirectoryTab extends StatefulWidget {
  final String uid;
  final String userName;
  final String? userImage;
  final Firm firm;

  const EmployeeDirectoryTab({
    super.key,
    required this.uid,
    required this.userName,
    this.userImage,
    required this.firm,
  });

  @override
  State<EmployeeDirectoryTab> createState() => _EmployeeDirectoryTabState();
}

class _EmployeeDirectoryTabState extends State<EmployeeDirectoryTab> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String? _loadingUid;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _startDirectChat(Map<String, dynamic> colleague) async {
    final otherUid = colleague['uid'] as String? ?? '';
    final otherName = colleague['name'] as String? ?? 'Colleague';
    final otherImage = colleague['avatarUrl'] as String? ?? colleague['image'] as String? ?? '';

    if (otherUid.isEmpty) return;

    setState(() => _loadingUid = otherUid);

    try {
      final conversationId = await DBService.instance.createConversation(
        currentUid: widget.uid,
        otherUid: otherUid,
        currentUserName: widget.userName,
        currentUserImage: widget.userImage ?? '',
        otherUserName: otherName,
        otherUserImage: otherImage,
      );

      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatPage(
            conversationId: conversationId,
            otherUserId: otherUid,
            otherUserName: otherName,
            otherUserImage: otherImage,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not start conversation: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _loadingUid = null);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;

    return Scaffold(
      backgroundColor: const Color.fromRGBO(28, 27, 27, 1),
      appBar: AppBar(
        backgroundColor: const Color.fromRGBO(28, 27, 27, 1),
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Staff Directory',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              widget.firm.name,
              style: TextStyle(color: Colors.grey[400], fontSize: 12),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // ── Search Bar ─────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search colleagues by name or role...',
                hintStyle: TextStyle(color: Colors.grey[600]),
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: Colors.grey, size: 18),
                        onPressed: () => _searchController.clear(),
                      )
                    : null,
                filled: true,
                fillColor: const Color.fromRGBO(34, 33, 33, 1),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: primaryColor, width: 1.5),
                ),
              ),
            ),
          ),

          // ── Members Stream ─────────────────────────────────────────────────
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: DBService.instance.streamFirmMembers(widget.firm.firmId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                var members = snapshot.data ?? [];

                // Exclude current user from the list
                members = members.where((m) => m['uid'] != widget.uid).toList();

                // Apply search filter if query is present
                if (_searchQuery.isNotEmpty) {
                  members = members.where((m) {
                    final name = (m['name'] as String? ?? '').toLowerCase();
                    final role = (m['role'] as String? ?? '').toLowerCase();
                    final title = (m['jobTitle'] as String? ?? '').toLowerCase();
                    return name.contains(_searchQuery) ||
                        role.contains(_searchQuery) ||
                        title.contains(_searchQuery);
                  }).toList();
                }

                if (members.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.person_search, size: 48, color: Colors.grey[600]),
                          const SizedBox(height: 12),
                          Text(
                            _searchQuery.isNotEmpty
                                ? 'No colleagues found matching "$_searchQuery".'
                                : 'No other colleagues registered in this firm yet.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey[400], fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: members.length,
                  itemBuilder: (context, index) {
                    final colleague = members[index];
                    final String name = colleague['name'] as String? ?? 'Colleague';
                    final String role = colleague['role'] as String? ?? 'employee';
                    final String jobTitle = colleague['jobTitle'] as String? ?? (role == 'admin' ? 'Firm Admin' : 'Employee');
                    final String avatarUrl = colleague['avatarUrl'] as String? ?? colleague['image'] as String? ?? '';
                    final String colUid = colleague['uid'] as String? ?? '';
                    final bool isStarting = _loadingUid == colUid;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color.fromRGBO(34, 33, 33, 1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 22,
                            backgroundColor: primaryColor.withValues(alpha: 0.2),
                            backgroundImage: avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
                            child: avatarUrl.isEmpty
                                ? Text(
                                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                                    style: TextStyle(
                                      color: primaryColor,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  )
                                : null,
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      name,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    if (role == 'admin' || role == 'super_admin') ...[
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                        decoration: BoxDecoration(
                                          color: Colors.amber.withValues(alpha: 0.2),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: const Text(
                                          'ADMIN',
                                          style: TextStyle(
                                            color: Colors.amber,
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  jobTitle,
                                  style: TextStyle(
                                    color: Colors.grey[400],
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryColor.withValues(alpha: 0.15),
                              foregroundColor: primaryColor,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                                side: BorderSide(color: primaryColor.withValues(alpha: 0.4)),
                              ),
                            ),
                            onPressed: isStarting ? null : () => _startDirectChat(colleague),
                            child: isStarting
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.chat_bubble_outline, size: 14),
                                      SizedBox(width: 5),
                                      Text('Message', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                    ],
                                  ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
