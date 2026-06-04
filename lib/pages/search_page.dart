import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/db_service.dart';
import 'convo_page.dart';

class UserSearchPage extends StatefulWidget {
  const UserSearchPage({super.key});

  @override
  State<UserSearchPage> createState() => _UserSearchPageState();
}

class _UserSearchPageState extends State<UserSearchPage> {
  final TextEditingController _searchController = TextEditingController();

  List<Map<String, dynamic>> _results = [];
  bool _isLoading  = false;
  bool _hasSearched = false;    // distinguishes "never searched" from "0 results"
  String? _creatingConvFor;     // uid of the tapped result (shows its spinner)

  @override
  void initState() {
    super.initState();
    // Trigger a search on every keystroke
    _searchController.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      setState(() {
        _results    = [];
        _hasSearched = false;
      });
      return;
    }
    _search(query);
  }

  Future<void> _search(String query) async {
    setState(() => _isLoading = true);

    final currentUid = context.read<AuthProvider>().currentUserId!;
    final results    = await DBService.instance.searchUsers(query);

    // Exclude the logged-in user from their own search results
    final filtered = results.where((u) => u['uid'] != currentUid).toList();

    if (mounted) {
      setState(() {
        _results     = filtered;
        _isLoading   = false;
        _hasSearched = true;
      });
    }
  }

  Future<void> _openOrCreateChat(
      BuildContext context, Map<String, dynamic> otherUser) async {
    final auth = context.read<AuthProvider>();

    setState(() => _creatingConvFor = otherUser['uid'] as String);

    try {
      final conversationId = await DBService.instance.createConversation(
        currentUid:       auth.currentUserId!,
        otherUid:         otherUser['uid'] as String,
        currentUserName:  auth.currentUserName,
        currentUserImage: auth.currentUserImage,
        otherUserName:    otherUser['name']  as String? ?? '',
        otherUserImage:   otherUser['image'] as String? ?? '',
      );

      if (!mounted) return;

      // Replace the search page with the chat page so Back returns to Home
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ChatPage(
            conversationId: conversationId,
            otherUserId:    otherUser['uid']   as String,
            otherUserName:  otherUser['name']  as String? ?? '',
            otherUserImage: otherUser['image'] as String? ?? '',
          ),
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open chat. Please try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _creatingConvFor = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromRGBO(28, 27, 27, 1),
      appBar: AppBar(
        backgroundColor: const Color.fromRGBO(28, 27, 27, 1),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: TextField(
          controller: _searchController,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Search by name…',
            hintStyle: TextStyle(color: Colors.grey[600]),
            border: InputBorder.none,
          ),
        ),
        actions: [
          if (_searchController.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear, color: Colors.grey),
              onPressed: () {
                _searchController.clear();
                setState(() {
                  _results     = [];
                  _hasSearched = false;
                });
              },
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    // Still typing / first open
    if (!_hasSearched) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.person_search, size: 56, color: Colors.grey[700]),
            const SizedBox(height: 12),
            Text(
              'Search for someone to chat with',
              style: TextStyle(color: Colors.grey[500], fontSize: 15),
            ),
          ],
        ),
      );
    }

    // Waiting for Firestore
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
            color: Color.fromRGBO(41, 116, 188, 1)),
      );
    }

    // Search returned nothing
    if (_results.isEmpty) {
      return Center(
        child: Text(
          'No users found for "${_searchController.text}"',
          style: TextStyle(color: Colors.grey[500]),
        ),
      );
    }

    // Results list
    return ListView.separated(
      itemCount: _results.length,
      separatorBuilder: (_, _) =>
          Divider(color: Colors.grey[850], height: 1, indent: 72),
      itemBuilder: (context, index) {
        final user  = _results[index];
        final uid   = user['uid']   as String? ?? '';
        final name  = user['name']  as String? ?? 'Unknown';
        final image = user['image'] as String? ?? '';
        final isCreating = _creatingConvFor == uid;

        return ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          leading: CircleAvatar(
            radius: 24,
            backgroundColor: const Color.fromRGBO(41, 116, 188, 0.3),
            backgroundImage: image.isNotEmpty ? NetworkImage(image) : null,
            child: image.isEmpty
                ? Text(
                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: const TextStyle(
                      color: Color.fromRGBO(41, 116, 188, 1),
                      fontWeight: FontWeight.bold,
                    ),
                  )
                : null,
          ),
          title: Text(name, style: const TextStyle(color: Colors.white)),
          subtitle: Text(
            user['email'] as String? ?? '',
            style: TextStyle(color: Colors.grey[600], fontSize: 13),
          ),
          trailing: isCreating
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color.fromRGBO(41, 116, 188, 1),
                  ),
                )
              : const Icon(Icons.chevron_right, color: Colors.grey),
          onTap: isCreating ? null : () => _openOrCreateChat(context, user),
        );
      },
    );
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }
}